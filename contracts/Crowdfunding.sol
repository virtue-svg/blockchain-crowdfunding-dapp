// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title 链上众筹合约
/// @notice 提供项目创建、捐赠、结项、退款、里程碑放款和早期支持者奖励。
contract Crowdfunding {
    uint8 public constant MILESTONE_COUNT = 4;
    uint256 public constant EARLY_REWARD_WINDOW = 1 days;
    uint256 public constant EARLY_REWARD_POINTS = 100;
    uint256 public constant NFT_REDEEM_POINTS = 100;

    enum ProjectStatus { Active, Successful, Failed, Cancelled }

    struct Project {
        uint256 id;
        address payable creator;
        string name;
        string description;
        string category;
        string imageUrl;
        uint256 goal;
        uint256 deadline;
        uint256 totalRaised;
        ProjectStatus status;
        bool creatorWithdrawn;
        uint8 milestonesCompleted;
        uint256 releasedAmount;
        uint256 earlyRewardDeadline;
        uint256 refundablePool;
        uint256 remainingRefundWeight;
    }

    uint256 private nextProjectId;
    uint256 private totalRaisedAll;
    uint256 private activeProjectCount;
    uint256 private nextTokenId = 1;
    bool private locked;

    mapping(uint256 => Project) private projects;
    mapping(uint256 => bool) private projectExists;
    mapping(uint256 => address[]) private projectDonors;
    mapping(uint256 => address[]) private earlyDonors;
    mapping(uint256 => mapping(address => uint256)) public donations;
    mapping(uint256 => mapping(address => bool)) private hasDonated;
    mapping(uint256 => mapping(address => bool)) private earlyDonorMarked;
    mapping(uint256 => mapping(address => uint256)) public earlyRewardPoints;
    mapping(address => uint256) public rewardPointBalances;
    mapping(uint256 => mapping(uint8 => mapping(address => bool))) public milestoneVotes;
    mapping(uint256 => mapping(uint8 => uint256)) public milestoneVoteCount;
    mapping(address => bool) public rewardWhitelist;
    mapping(uint256 => address) private tokenOwners;
    mapping(address => uint256) private tokenBalances;
    mapping(uint256 => string) private tokenUris;

    event ProjectCreated(uint256 indexed projectId, address indexed creator, string name, string description, string category, string imageUrl, uint256 goal, uint256 deadline);
    event Donated(uint256 indexed projectId, address indexed donor, uint256 amount);
    event EarlyDonorAdded(uint256 indexed projectId, address indexed donor);
    event EarlyDonorRewarded(uint256 indexed projectId, address indexed donor, uint256 points, uint256 rewardedAt);
    event ProjectEnded(uint256 indexed projectId, bool successful);
    event ProjectCancelled(uint256 indexed projectId, address indexed creator);
    event MilestoneVoted(uint256 indexed projectId, uint8 indexed milestone, address indexed donor, uint256 votes, uint256 requiredVotes);
    event MilestoneReleased(uint256 indexed projectId, address indexed creator, uint8 milestone, uint256 amount, uint256 totalReleased);
    event FundsWithdrawn(uint256 indexed projectId, address indexed creator, uint256 amount);
    event Refunded(uint256 indexed projectId, address indexed donor, uint256 amount);
    event RewardBadgeRedeemed(address indexed donor, uint256 indexed tokenId, uint256 pointsSpent);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    modifier projectMustExist(uint256 projectId) {
        require(projectExists[projectId], "Project does not exist");
        _;
    }

    modifier nonReentrant() {
        require(!locked, "Reentrant call");
        locked = true;
        _;
        locked = false;
    }

    /// @notice 创建众筹项目并分配唯一 ID。
    function createProject(string memory name, string memory description, string memory category, string memory imageUrl, uint256 goal, uint256 deadline) public returns (uint256) {
        require(bytes(name).length > 0, "Project name is required");
        require(bytes(category).length > 0, "Project category is required");
        require(goal > 0, "Goal must be greater than zero");
        require(deadline > block.timestamp, "Deadline must be in the future");

        uint256 projectId = nextProjectId++;
        uint256 rewardDeadline = block.timestamp + EARLY_REWARD_WINDOW;
        if (rewardDeadline > deadline) rewardDeadline = deadline;
        projects[projectId] = Project(projectId, payable(msg.sender), name, description, category, imageUrl, goal, deadline, 0, ProjectStatus.Active, false, 0, 0, rewardDeadline, 0, 0);
        projectExists[projectId] = true;
        activeProjectCount++;
        emit ProjectCreated(projectId, msg.sender, name, description, category, imageUrl, goal, deadline);
        return projectId;
    }

    /// @notice 向进行中的项目捐赠 ETH。
    function donate(uint256 projectId) public payable projectMustExist(projectId) {
        Project storage project = projects[projectId];
        require(project.status == ProjectStatus.Active, "Project is not active");
        require(block.timestamp < project.deadline, "Project deadline has passed");
        require(msg.value > 0, "Donation must be greater than zero");
        if (!hasDonated[projectId][msg.sender]) {
            hasDonated[projectId][msg.sender] = true;
            projectDonors[projectId].push(msg.sender);
            if (earlyDonors[projectId].length < 10 && block.timestamp <= project.earlyRewardDeadline) {
                earlyDonors[projectId].push(msg.sender);
                earlyDonorMarked[projectId][msg.sender] = true;
                earlyRewardPoints[projectId][msg.sender] = EARLY_REWARD_POINTS;
                rewardPointBalances[msg.sender] += EARLY_REWARD_POINTS;
                emit EarlyDonorAdded(projectId, msg.sender);
                emit EarlyDonorRewarded(projectId, msg.sender, EARLY_REWARD_POINTS, block.timestamp);
            }
        }
        donations[projectId][msg.sender] += msg.value;
        project.totalRaised += msg.value;
        totalRaisedAll += msg.value;
        emit Donated(projectId, msg.sender, msg.value);
    }

    /// @notice 截止后由任意账户根据筹资结果结束项目。
    function endProject(uint256 projectId) public projectMustExist(projectId) {
        Project storage project = projects[projectId];
        require(project.status == ProjectStatus.Active, "Project already ended");
        require(block.timestamp >= project.deadline, "Project deadline has not passed");
        bool successful = project.totalRaised >= project.goal;
        project.status = successful ? ProjectStatus.Successful : ProjectStatus.Failed;
        if (!successful) {
            project.refundablePool = project.totalRaised - project.releasedAmount;
            project.remainingRefundWeight = project.totalRaised;
        }
        activeProjectCount--;
        emit ProjectEnded(projectId, successful);
    }

    function cancelProject(uint256 projectId) public projectMustExist(projectId) {
        Project storage project = projects[projectId];
        require(project.status == ProjectStatus.Active, "Project is not active");
        require(msg.sender == project.creator, "Only creator can cancel");
        require(project.totalRaised == 0, "Cannot cancel project with donations");
        project.status = ProjectStatus.Cancelled;
        activeProjectCount--;
        emit ProjectCancelled(projectId, msg.sender);
    }

    /// @notice 未启动里程碑的成功项目由发起人一次性提现。
    function withdrawFunds(uint256 projectId) public nonReentrant projectMustExist(projectId) {
        Project storage project = projects[projectId];
        require(project.status == ProjectStatus.Successful, "Project is not successful");
        require(msg.sender == project.creator, "Only creator can withdraw");
        require(!project.creatorWithdrawn, "Funds already withdrawn");
        require(project.milestonesCompleted == 0, "Milestone release already started");
        uint256 amount = project.totalRaised;
        project.releasedAmount = project.totalRaised;
        project.creatorWithdrawn = true;
        (bool ok,) = project.creator.call{value: amount}("");
        require(ok, "Transfer failed");
        emit FundsWithdrawn(projectId, msg.sender, amount);
    }

    /// @notice 项目捐赠者为下一阶段释放投赞成票。
    function voteForNextMilestone(uint256 projectId) public projectMustExist(projectId) {
        Project storage project = projects[projectId];
        require(project.status == ProjectStatus.Active || (project.status == ProjectStatus.Successful && project.milestonesCompleted > 0), "Project cannot use milestones");
        require(hasDonated[projectId][msg.sender], "Only donors can vote");
        require(!project.creatorWithdrawn, "Funds already withdrawn");
        uint8 milestone = project.milestonesCompleted + 1;
        require(milestone <= MILESTONE_COUNT, "All milestones released");
        require(_milestoneThresholdReached(project, milestone), "Milestone threshold not reached");
        require(!milestoneVotes[projectId][milestone][msg.sender], "Already voted");
        milestoneVotes[projectId][milestone][msg.sender] = true;
        uint256 votes = ++milestoneVoteCount[projectId][milestone];
        emit MilestoneVoted(projectId, milestone, msg.sender, votes, requiredMilestoneVotes(projectId));
    }

    function requiredMilestoneVotes(uint256 projectId) public view projectMustExist(projectId) returns (uint256) {
        return projectDonors[projectId].length / 2 + 1;
    }

    /// @notice 多数投票通过后由发起人释放下一阶段资金。
    function releaseNextMilestone(uint256 projectId) public nonReentrant projectMustExist(projectId) {
        Project storage project = projects[projectId];
        require(project.status == ProjectStatus.Active || (project.status == ProjectStatus.Successful && project.milestonesCompleted > 0), "Project cannot use milestones");
        require(msg.sender == project.creator, "Only creator can release milestone");
        require(!project.creatorWithdrawn, "Funds already withdrawn");
        require(project.milestonesCompleted < MILESTONE_COUNT, "All milestones released");
        uint8 nextMilestone = project.milestonesCompleted + 1;
        require(_milestoneThresholdReached(project, nextMilestone), "Milestone threshold not reached");
        require(milestoneVoteCount[projectId][nextMilestone] >= requiredMilestoneVotes(projectId), "Milestone vote not approved");
        uint256 amount = nextMilestone == MILESTONE_COUNT ? project.totalRaised - project.releasedAmount : project.goal / MILESTONE_COUNT;
        project.milestonesCompleted = nextMilestone;
        project.releasedAmount += amount;
        if (nextMilestone == MILESTONE_COUNT) project.creatorWithdrawn = true;
        (bool ok,) = project.creator.call{value: amount}("");
        require(ok, "Transfer failed");
        emit MilestoneReleased(projectId, msg.sender, nextMilestone, amount, project.releasedAmount);
    }

    /// @notice 使用账户积分兑换独立纪念凭证。
    function redeemRewardBadge() public returns (uint256) {
        require(rewardPointBalances[msg.sender] >= NFT_REDEEM_POINTS, "Not enough reward points");
        rewardPointBalances[msg.sender] -= NFT_REDEEM_POINTS;
        rewardWhitelist[msg.sender] = true;
        uint256 tokenId = nextTokenId++;
        tokenOwners[tokenId] = msg.sender;
        tokenBalances[msg.sender]++;
        tokenUris[tokenId] = string.concat("crowdfunding://reward/early-supporter/", _toString(tokenId));
        emit Transfer(address(0), msg.sender, tokenId);
        emit RewardBadgeRedeemed(msg.sender, tokenId, NFT_REDEEM_POINTS);
        return tokenId;
    }

    /// @notice 失败项目按原始捐赠比例退还尚未释放的资金。
    function refund(uint256 projectId) public nonReentrant projectMustExist(projectId) {
        Project storage project = projects[projectId];
        require(project.status == ProjectStatus.Failed, "Project is not failed");
        uint256 donationAmount = donations[projectId][msg.sender];
        require(donationAmount > 0, "No donation to refund");
        uint256 amount = project.remainingRefundWeight == donationAmount ? project.refundablePool : project.refundablePool * donationAmount / project.remainingRefundWeight;
        donations[projectId][msg.sender] = 0;
        project.refundablePool -= amount;
        project.remainingRefundWeight -= donationAmount;
        (bool ok,) = payable(msg.sender).call{value: amount}("");
        require(ok, "Refund failed");
        emit Refunded(projectId, msg.sender, amount);
    }

    function getProject(uint256 projectId) public view projectMustExist(projectId) returns (Project memory) { return projects[projectId]; }
    function getProjectCount() public view returns (uint256) { return nextProjectId; }
    function getTotalRaised() public view returns (uint256) { return totalRaisedAll; }
    function getActiveProjectCount() public view returns (uint256) { return activeProjectCount; }
    function getDonors(uint256 projectId) public view projectMustExist(projectId) returns (address[] memory) { return projectDonors[projectId]; }
    function getEarlyDonors(uint256 projectId) public view projectMustExist(projectId) returns (address[] memory) { return earlyDonors[projectId]; }
    function isEarlyDonor(uint256 projectId, address donor) public view projectMustExist(projectId) returns (bool) { return earlyDonorMarked[projectId][donor]; }
    function getEarlyRewardPoints(uint256 projectId, address donor) public view projectMustExist(projectId) returns (uint256) { return earlyRewardPoints[projectId][donor]; }
    function ownerOf(uint256 tokenId) public view returns (address) { address owner = tokenOwners[tokenId]; require(owner != address(0), "Token does not exist"); return owner; }
    function balanceOf(address owner) public view returns (uint256) { require(owner != address(0), "Zero address"); return tokenBalances[owner]; }
    function tokenURI(uint256 tokenId) public view returns (string memory) { require(tokenOwners[tokenId] != address(0), "Token does not exist"); return tokenUris[tokenId]; }
    function getRemainingTime(uint256 projectId) public view projectMustExist(projectId) returns (uint256) { return block.timestamp >= projects[projectId].deadline ? 0 : projects[projectId].deadline - block.timestamp; }

    function getRefundableAmount(uint256 projectId, address donor) public view projectMustExist(projectId) returns (uint256) {
        Project storage project = projects[projectId];
        if (project.status != ProjectStatus.Failed) return 0;
        uint256 donationAmount = donations[projectId][donor];
        if (donationAmount == 0 || project.remainingRefundWeight == 0) return 0;
        return project.remainingRefundWeight == donationAmount ? project.refundablePool : project.refundablePool * donationAmount / project.remainingRefundWeight;
    }

    function _milestoneThresholdReached(Project storage project, uint8 milestone) private view returns (bool) {
        if (milestone == MILESTONE_COUNT) return project.status == ProjectStatus.Successful;
        return project.totalRaised * MILESTONE_COUNT >= project.goal * milestone;
    }

    function _toString(uint256 value) private pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value; uint256 digits;
        while (temp != 0) { digits++; temp /= 10; }
        bytes memory buffer = new bytes(digits);
        while (value != 0) { digits--; buffer[digits] = bytes1(uint8(48 + value % 10)); value /= 10; }
        return string(buffer);
    }
}
