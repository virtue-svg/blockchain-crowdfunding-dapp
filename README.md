# 基于区块链的众筹系统

姓名：孙睿  
学号：10235304408

## 技术栈

- Solidity 0.8.28
- Hardhat、Hardhat Ignition
- Ethers.js、MetaMask
- 原生 HTML、CSS、JavaScript

## 核心功能

- 创建项目并分配唯一 ID
- ETH 捐赠、捐赠者列表和项目状态展示
- 到期后由任意账户结项
- 成功项目由发起人提现
- 失败项目由捐赠者退款
- 25%、50%、75% 目标完成度里程碑与捐赠者多数投票
- 前 10 位早期捐赠者积分、独立奖励中心和纪念凭证
- 项目详情、我的项目、链上事件与 JSON 导出

## 启动

```powershell
npm install
```

三个终端依次运行：

```powershell
.\scripts\start-node.ps1
.\scripts\deploy-local.ps1
.\scripts\start-web.ps1
```

打开 `http://127.0.0.1:3000`，MetaMask 网络使用 RPC `http://127.0.0.1:8545`、Chain ID `31337`。

## 演示数据与时间推进

```powershell
.\scripts\seed-demo.ps1
.\scripts\advance-time.ps1 -Seconds 360
```

推进时间只会使项目到期；仍需在网页点击“结束项目”。

## 测试

```powershell
npm test
npm run coverage
```

## 里程碑规则

里程碑模式必须在项目成功结项前启动。前三阶段分别要求目标完成度达到 25%、50%、75%，每阶段经捐赠者严格多数投票后固定释放 `goal / 4`。第四阶段要求项目成功并释放全部余款。若项目失败，只按原始捐赠比例退还尚未释放的资金。
