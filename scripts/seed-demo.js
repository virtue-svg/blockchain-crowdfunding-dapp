const fs=require("fs"),path=require("path");
async function main(){
 const [creator,donor1,donor2]=await ethers.getSigners();
 const addresses=JSON.parse(fs.readFileSync(path.join(__dirname,"..","ignition","deployments","chain-31337","deployed_addresses.json"),"utf8"));
 const address=addresses["CrowdfundingModule#Crowdfunding"],c=await ethers.getContractAt("Crowdfunding",address);
 const block=await ethers.provider.getBlock("latest"),deadline=block.timestamp+300;
 console.log(`Using Crowdfunding at ${address}`);console.log(`Creator: ${creator.address}`);
 await (await c.connect(creator).createProject("校园公益图书角","为校园公共空间建设共享图书角","校园","https://images.unsplash.com/photo-1481627834876-b7833e8f5570?auto=format&fit=crop&w=1000&q=70",ethers.parseEther("1"),deadline)).wait();
 await (await c.connect(donor1).donate(0,{value:ethers.parseEther("0.4")})).wait();
 await (await c.connect(donor2).donate(0,{value:ethers.parseEther("0.6")})).wait();
 await (await c.connect(creator).createProject("社区活动基金","支持社区公益活动与志愿服务","公益","https://images.unsplash.com/photo-1559027615-cd4628902d4a?auto=format&fit=crop&w=1000&q=70",ethers.parseEther("5"),deadline)).wait();
 await (await c.connect(donor1).donate(1,{value:ethers.parseEther("0.5")})).wait();
 console.log(`Demo deadline: ${new Date(deadline*1000).toLocaleString()}`);
 console.log("Demo data created: #0 raised 1/1 ETH; #1 raised 0.5/5 ETH");
}
main().catch(e=>{console.error(e);process.exitCode=1});
