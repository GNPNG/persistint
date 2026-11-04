// Run from the repository root; outputs are synthetic review fixtures in .cache/.
import fs from 'node:fs';
import {execFileSync} from 'node:child_process';
fs.mkdirSync('.cache/1rjz3-canon-smoke',{recursive:true});
import {readImage,writeImage} from '../../../tools/doll/lib/image.mjs';
import {bbox} from '../../../tools/doll/legacy.mjs';
const base=readImage('project/assets/canon/body_base.png'),b=bbox(base),width=2700,height=1100,data=Buffer.alloc(width*height*4,255);
for(let y=0;y<base.height;y++)for(let x=0;x<base.width;x++){const p=(y*base.width+x)*4,a=base.data[p+3]/255;if(!a)continue;const xx=97+x-b[0],yy=300+y-b[1],q=(yy*width+xx)*4;for(let c=0;c<3;c++)data[q+c]=Math.round(base.data[p+c]*a+255*(1-a));}
const truth={width:721,height:760,data:Buffer.alloc(721*760*4)};
for(const [name,x0,y0,w,h] of [['pigtails',595,89,379,419],['crown',1095,81,402,511],['braids',1530,99,534,512],['short',2199,90,423,374]]){
 const hole=name==='crown'?[86,80,229,330]:[60,70,w-120,h-110];
 for(let y=20;y<h-20;y++)for(let x=20;x<w-20;x++){
  const inside=x>=hole[0]&&x<hole[0]+hole[2]&&y>=hole[1]&&y<hole[1]+hole[3];if(inside)continue;
  const color=[100,60,40,255];data.set(color,((y+y0)*width+x+x0)*4);
  // Independently specified crown placement: 229-wide opening centre200,
  // opening bottom409 -> frame centre367 and chin399, hence offset(167,-10).
  if(name==='crown'){const xx=x+167,yy=y-10;if(xx>=0&&xx<721&&yy>=0&&yy<760)truth.data.set(color,(yy*721+xx)*4);}
 }
}
writeImage('.cache/1rjz3-canon-smoke/sheet.png',{width,height,data});writeImage('.cache/1rjz3-canon-smoke/truth.png',truth);console.log(JSON.stringify({bodyBounds:b,crownHole:[86,80,229,330],independentOffset:[167,-10]}));

execFileSync(process.execPath,['tools/doll/check_canon_registration.mjs','.cache/1rjz3-canon-smoke/sheet.png','482x778+57+250','.cache/1rjz3-canon-smoke/output','.cache/1rjz3-canon-smoke/truth.png'],{stdio:'inherit'});
