const http=require("http"),fs=require("fs"),path=require("path");
const root=path.resolve(__dirname,".."),port=Number(process.env.PORT||3000);
const mappings=[
  ["/contracts/",path.join(root,"artifacts","contracts")],
  ["/deployments/",path.join(root,"ignition","deployments")],
  ["/js/ethers.min.js",path.join(root,"node_modules","ethers","dist","ethers.min.js")],
  ["/",path.join(root,"src")],
];
const mime={".html":"text/html; charset=utf-8",".js":"text/javascript; charset=utf-8",".css":"text/css; charset=utf-8",".json":"application/json; charset=utf-8"};
http.createServer((req,res)=>{let url=decodeURIComponent(req.url.split("?")[0]);if(url==="/")url="/index.html";let file;for(const [prefix,target] of mappings){if(url===prefix&&fs.statSync(target).isFile()){file=target;break}if(url.startsWith(prefix)&&fs.existsSync(target)&&fs.statSync(target).isDirectory()){file=path.join(target,url.slice(prefix.length));break}}if(!file||!fs.existsSync(file)||!fs.statSync(file).isFile()){res.writeHead(404);return res.end("Not found")}res.writeHead(200,{"Content-Type":mime[path.extname(file)]||"application/octet-stream","Cache-Control":"no-store"});fs.createReadStream(file).pipe(res)}).listen(port,"127.0.0.1",()=>console.log(`Crowdfunding DApp: http://127.0.0.1:${port}`));
