#!/usr/bin/env node
// Character pipeline task 1: measured chibi rig. Node built-ins + ImageMagick 7.
// Run: node tools/doll/rig.mjs [--root PATH]. L/R mean image left/right.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
export function magick(args, input) { return execFileSync('magick', args, {input, maxBuffer:64*1024*1024}); }
export function readImage(file) {
  const [width,height] = magick([file,'-format','%w %h','info:']).toString().split(' ').map(Number);
  return {width,height,data:magick([file,'-depth','8','rgba:-'])};
}
// Stable identity: uint32 big-endian width, height, then row-major RGBA8 pixels.
export function imageSha1({width,height,data}) {
  const dimensions=Buffer.alloc(8);
  dimensions.writeUInt32BE(width,0);dimensions.writeUInt32BE(height,4);
  return createHash('sha1').update(dimensions).update(data).digest('hex');
}
function writeImage(file,w,h,data) {
  fs.mkdirSync(path.dirname(file),{recursive:true});
  magick(['-size',`${w}x${h}`,'-depth','8','rgba:-','-strip',`PNG32:${file}`],data);
}
const labels = Object.fromEntries(['head','face','eye_band','ears','neck','torso','upper_arm_l','upper_arm_r','forearm_l','forearm_r','hand_l','hand_r','hips','thigh_l','thigh_r','shin_l','shin_r','foot_l','foot_r'].map((s,i)=>[s,i+1]));
const median = a => [...a].sort((a,b)=>a-b)[Math.floor(a.length/2)];
const midpoint = s => (s[0]+s[1])/2;
export function measure({width:w,height:h,data:b}) {
  const rows=Array.from({length:h},(_,y)=>{
    const spans=[];let start=-1;
    for(let x=0;x<=w;x++) {const on=x<w&&b[(y*w+x)*4+3]>0;if(on&&start<0)start=x;if(!on&&start>=0){spans.push([start,x-1]);start=-1;}}
    return spans;
  });
  const occupied=rows.map((s,y)=>s.length?y:-1).filter(y=>y>=0), top=occupied[0],sole=occupied.at(-1),height=sole-top;
  if(!occupied.length)throw Error('Body mask is empty');
  const extent=y=>rows[y].length?rows[y].at(-1)[1]-rows[y][0][0]+1:0;
  const range=(a,z)=>Array.from({length:Math.max(0,Math.floor(z)-Math.ceil(a)+1)},(_,i)=>Math.ceil(a)+i);
  const neck=range(top+height*.44,top+height*.56).reduce((a,y)=>extent(y)<extent(a)?y:a);
  const headRow=range(top,top+(neck-top)*.52).reduce((a,y)=>extent(y)>extent(a)?y:a);
  const cx=Math.floor(midpoint([rows[headRow][0][0],rows[headRow].at(-1)[1]])),headWidth=extent(headRow);
  // The chin is the lower jaw's transition to the neck, where it tapers to
  // twice the minimum neck width. This is measured, not neck minus a constant.
  const chin=range(headRow,neck).find(y=>extent(y)<=extent(neck)*2);
  const shoulder=range(neck+1,neck+(sole-neck)*.15).find(y=>extent(y)>=extent(neck)*2);
  const faceWindow=[Math.round(cx-headWidth*.38),Math.round(top+(neck-top)*.35),Math.round(cx+headWidth*.38),Math.round(chin-(neck-top)*.08)];
  const seen=new Uint8Array(w*h),blobs=[];
  const dark=(x,y)=>x>=faceWindow[0]&&x<faceWindow[2]&&y>=faceWindow[1]&&y<faceWindow[3]&&b[(y*w+x)*4+3]>0&&b[(y*w+x)*4]<135&&b[(y*w+x)*4+1]<100&&b[(y*w+x)*4+2]<90;
  for(let y=faceWindow[1];y<faceWindow[3];y++)for(let x=faceWindow[0];x<faceWindow[2];x++){
    const i=y*w+x;if(seen[i]||!dark(x,y))continue;const q=[i];seen[i]=1;let sx=0,sy=0,x0=x,x1=x,y0=y,y1=y;
    for(let k=0;k<q.length;k++){const j=q[k],xx=j%w,yy=Math.floor(j/w);sx+=xx;sy+=yy;x0=Math.min(x0,xx);x1=Math.max(x1,xx);y0=Math.min(y0,yy);y1=Math.max(y1,yy);
      for(const [nx,ny] of [[xx-1,yy],[xx+1,yy],[xx,yy-1],[xx,yy+1]]){const n=ny*w+nx;if(dark(nx,ny)&&!seen[n]){seen[n]=1;q.push(n);}}}
    if(q.length>15)blobs.push({area:q.length,centre:[sx/q.length,sy/q.length],box:[x0,y0,x1,y1],pixels:q});
  }
  const eyes=blobs.filter(p=>(p.box[3]-p.box[1])>(p.box[2]-p.box[0])*.9).sort((a,b)=>b.area-a.area).slice(0,2).sort((a,b)=>a.centre[0]-b.centre[0]);
  if(eyes.length!==2)throw Error('Expected two measurable eye blobs');
  const brows=blobs.filter(p=>p.centre[1]<Math.min(...eyes.map(e=>e.box[1]))&&p.box[2]-p.box[0]>p.box[3]-p.box[1]);
  if(brows.length!==2)throw Error('Expected two measurable eyebrow blobs');
  const brow=Math.min(...brows.map(p=>p.box[1]))-3,eyeBottom=Math.max(...eyes.map(p=>p.box[3]))+3;
  const branch=range(shoulder,sole).find(y=>rows[y].filter(s=>s[1]-s[0]>8).length===3);
  const armpits=rows[branch].filter(s=>s[1]-s[0]>8)[1];
  const handRows=range(branch,sole).filter(y=>rows[y].length===3);
  const handExtreme=handRows.reduce((a,y)=>extent(y)>extent(a)?y:a);
  const wrist=Math.round(handExtreme-(handExtreme-shoulder)*.14),elbow=Math.round((shoulder+wrist)/2);
  const torsoSpan=y=>rows[y].find(s=>s[0]<cx&&s[1]>cx);
  const waistRange=range(neck+(sole-neck)*.39,neck+(sole-neck)*.55);
  const darkCount=y=>{let n=0;for(let x=armpits[0]+5;x<=armpits[1]-5;x++){let i=(y*w+x)*4;if(b[i]<170&&b[i+1]<130&&b[i+2]<115)n++;}return n;};
  const waist=waistRange.reduce((a,y)=>darkCount(y)>darkCount(a)?y:a);
  const crotch=range(waist+1,sole).find(y=>rows[y].length===2&&rows[y][0][1]<cx&&rows[y][1][0]>cx-10);
  const trunkWidth=y=>{const s=torsoSpan(y);return s?s[1]-s[0]+1:0;};
  const hip=range(waist,crotch-1).reduce((a,y)=>trunkWidth(y)>trunkWidth(a)?y:a);
  const legRows=range(crotch+(sole-crotch)*.6,sole-(sole-crotch)*.12).filter(y=>rows[y].length===2);
  const legWidth=y=>rows[y].reduce((a,s)=>a+s[1]-s[0]+1,0);
  const ankle=legRows.reduce((a,y)=>legWidth(y)<legWidth(a)?y:a),knee=Math.round((crotch+ankle)/2);
  const wristSpans=rows[wrist],soles=[0,1].map(side=>{const ys=range(ankle,sole).filter(y=>rows[y].some(s=>side===0?midpoint(s)<cx:midpoint(s)>cx));const y=ys.at(-1);return [midpoint(rows[y].find(s=>side===0?midpoint(s)<cx:midpoint(s)>cx)),y];});
  const landmarks={head_top:[cx,top],centre_x:cx,eye_l:eyes[0].centre.map(Math.round),eye_r:eyes[1].centre.map(Math.round),brow_y:brow,chin_y:chin,neck_y:neck,shoulder_y:shoulder,waist_y:waist,hip_y:hip,crotch_y:crotch,wrist_l:[Math.round(midpoint(wristSpans[0])),wrist],wrist_r:[Math.round(midpoint(wristSpans.at(-1))),wrist],knee_y:knee,ankle_y:ankle,sole_l:soles[0],sole_r:soles[1],elbow_y:elbow,armpit_y:branch,armpit_x:armpits,eye_band:[brow,eyeBottom]};
  // Visible face is an inset ellipse between the ears, below the hairline.
  // Eye protection follows the measured eye silhouettes, not a full-width row.
  const eyeHeight=Math.max(...eyes.map(e=>e.box[3]-e.box[1]+1));
  const faceTop=Math.round(brow-eyeHeight*.4),faceCy=(faceTop+chin)/2,faceRy=(chin-faceTop)/2;
  const faceRx=Math.min(headWidth*.38,(eyes[1].centre[0]-eyes[0].centre[0])*.82);
  const inFace=(x,y)=>((x-cx)/faceRx)**2+((y-faceCy)/faceRy)**2<=1;
  const eyeDilation=Math.max(3,Math.round(eyeHeight*.25)),eyeMask=new Uint8Array(w*h);
  for(const eye of eyes)for(const p of eye.pixels){const x=p%w,y=Math.floor(p/w);
    for(let dy=-eyeDilation;dy<=eyeDilation;dy++)for(let dx=-eyeDilation;dx<=eyeDilation;dx++){
      const xx=x+dx,yy=y+dy;if(dx*dx+dy*dy<=eyeDilation*eyeDilation&&xx>=0&&yy>=0&&xx<w&&yy<h&&inFace(xx,yy))eyeMask[yy*w+xx]=1;
    }
  }
  landmarks.face_outline={shape:'ellipse',centre:[cx,faceCy],radii:[faceRx,faceRy],hairline_y:faceTop};
  landmarks.eye_dilation_px=eyeDilation;
  const region=Buffer.alloc(w*h*4),overlay=Buffer.from(b),counts=Object.fromEntries(Object.keys(labels).map(k=>[k,0]));
  const palette=Object.values(labels).map(n=>[70+(n*83)%180,70+(n*137)%180,70+(n*53)%180]);
  const earRows=range(brow,chin).filter(y=>extent(y)>headWidth*1.03),earTop=earRows[0]-3,earBottom=earRows.at(-1)+3;
  const headCy=(top+chin)/2,headRy=(chin-top)/2;
  for(let y=0;y<h;y++)for(let x=0;x<w;x++){
    const i=(y*w+x)*4;if(!b[i+3])continue;let name;const side=x<cx?'l':'r';
    const skullRadius=headWidth/2*Math.sqrt(Math.max(0,1-((y-headCy)/headRy)**2));
    if(y<=chin){
      if(y>=earTop&&y<=earBottom&&Math.abs(x-cx)>skullRadius)name='ears';
      else if(eyeMask[y*w+x])name='eye_band';else if(inFace(x,y))name='face';else name='head';
    }else if(y<shoulder)name='neck';
    else if(y<crotch){
      const f=Math.min(1,(y-shoulder)/(branch-shoulder));
      const left=armpits[0]+(1-f)*(extent(neck)*.34),right=armpits[1]-(1-f)*(extent(neck)*.34);
      const trunk=torsoSpan(y);
      const inArm=y<branch?(x<left||x>right):trunk&&(x<trunk[0]||x>trunk[1]);
      if(inArm&&y<=handRows.at(-1))name=(y>=wrist?'hand_':y>=elbow?'forearm_':'upper_arm_')+side;
      else name=y>=waist?'hips':'torso';
    }else name=(y>=ankle?'foot_':y>=knee?'shin_':'thigh_')+side;
    const id=labels[name];counts[name]++;region[i]=region[i+1]=region[i+2]=id;region[i+3]=255;
    for(let c=0;c<3;c++)overlay[i+c]=Math.round(b[i+c]*.45+palette[id-1][c]*.55);
  }
  for (const side of ['l','r']) {
    const id=labels['hand_'+side];let sx=0,sy=0,n=0;
    for(let y=0;y<h;y++)for(let x=0;x<w;x++)if(region[(y*w+x)*4]===id){sx+=x;sy+=y;n++;}
    landmarks['hand_'+side]=[Math.round(sx/n),Math.round(sy/n)];
  }
  landmarks.shoulder_l=[Math.round(armpits[0]+extent(neck)*.34),shoulder];
  landmarks.shoulder_r=[Math.round(armpits[1]-extent(neck)*.34),shoulder];
  // Skin seed from the clear centre of the forehead; no clothing or blush.
  const skin=[[],[],[]];for(let y=top+80;y<brow-20;y++)for(let x=cx-30;x<cx+30;x++){let i=(y*w+x)*4;if(b[i+3])for(let c=0;c<3;c++)skin[c].push(b[i+c]);}
  return {landmarks,region,overlay,counts,skin:skin.map(median)};
}
export function build(root=ROOT){
  const candidates=['project/assets/doll/body_base.png','project/assets/canon/body_base.png'];
  const body=candidates.find(f=>fs.existsSync(path.join(root,f)));if(!body)throw Error('body_base.png missing');
  const image=readImage(path.join(root,body));if(image.width!==721||image.height!==760)throw Error('Expected canonical 721x760 frame');
  const m=measure(image),regions='project/assets/doll/rig/chibi_regions.png',template='prompts/image/doll/template_chibi_front.png';
  const review=path.join(root,'docs/reviews/1rjz.1');fs.mkdirSync(review,{recursive:true});
  writeImage(path.join(root,regions),721,760,m.region);writeImage(path.join(review,'regions_overlay.png'),721,760,m.overlay);
  fs.mkdirSync(path.dirname(path.join(root,template)),{recursive:true});
  magick([path.join(root,body),'-virtual-pixel','transparent','-filter','Lanczos','-define','distort:viewport=1024x1536+0+0','-distort','AffineProjection','1.6,0,0,1.6,-75.2,160','-background','#00FF00','-alpha','remove','-alpha','on','-strip',`PNG32:${path.join(root,template)}`]);
  fs.copyFileSync(path.join(root,template),path.join(review,'template_chibi_front.png'));
  const slots={top:{covers:['torso'],never:['face','eye_band','hand_l','hand_r'],overhang_px:16,layers:['top']},bottom:{covers:['hips'],never:['face','torso'],overhang_px:24,layers:['bottom']},dress:{covers:['torso','hips'],never:['face','eye_band','hand_l','hand_r'],overhang_px:null,layers:['dress']},shoes:{covers:['foot_l','foot_r'],per_side:true,never:['head','face','eye_band','ears','neck','torso','upper_arm_l','upper_arm_r','forearm_l','forearm_r','hand_l','hand_r','hips','thigh_l','thigh_r'],overhang_px:12,layers:['shoes']},hair:{covers:[],never:['eye_band'],max_share:{face:.03},front_never:['neck','torso'],split:'chin_y',layers:['hair_back','hair']},hat:{covers:[],anchor:'head_top',never:['eye_band'],layers:['hat']},accessory:{covers:[],never:['eye_band'],layers:['accessory']}};
  const rig={id:'chibi',frame:[721,760],body:'body_base',body_file:body,body_sha1:createHash('sha1').update(fs.readFileSync(path.join(root,body))).digest('hex'),coordinate_convention:'pixel centres; L/R are image left/right',layers:['hair_back','body','shoes','bottom','top','dress','hair','hat','accessory'],landmarks:m.landmarks,regions:{file:regions,encoding:'R=G=B=label id; alpha=255 on body, zero outside',labels,counts:m.counts},slots,skin:{base:[m.skin],tones:{}},template:{file:template,size:[1024,1536],frame_scale:1.6,frame_origin:[-75.2,160],sha1:imageSha1(readImage(path.join(root,template))),sha1_encoding:'uint32be width + uint32be height + row-major RGBA8'}};
  const file=path.join(root,'project/data/doll/rig_chibi.json');fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,JSON.stringify(rig,null,2)+'\n');console.log(JSON.stringify(m.landmarks));return rig;
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url))build(process.argv.includes('--root')?path.resolve(process.argv[process.argv.indexOf('--root')+1]):ROOT);
