// Explicit legacy repair: remove a thin, isolated face-opening outline below brow.
// Run after placement so source opening detection and the scale/search stay intact.
export function stripFaceOutline(image,rig,{maxThickness=8}={}){
 const {width:w,height:h,data}=image,n=w*h,lm=rig.landmarks;
 const sx=Math.round(lm.centre_x),sy=Math.round((lm.eye_l[1]+lm.eye_r[1])/2),seed=sy*w+sx;
 const report={removed_pixels:0,brow_y:lm.brow_y,max_thickness:maxThickness,status:'unchanged'};
 if(sx<0||sx>=w||sy<0||sy>=h||data[seed*4+3]>127)return {image,report:{...report,status:'no transparent face seed'}};
 const neighbours=p=>{const x=p%w,y=Math.floor(p/w);return [x?p-1:-1,x+1<w?p+1:-1,y?p-w:-1,y+1<h?p+w:-1];};
 const hole=new Uint8Array(n),queue=[seed];hole[seed]=1;let edge=false;
 for(let k=0;k<queue.length;k++){const p=queue[k],x=p%w,y=Math.floor(p/w);edge ||= x===0||y===0||x===w-1||y===h-1;
  for(const q of neighbours(p))if(q>=0&&!hole[q]&&data[q*4+3]<=127){hole[q]=1;queue.push(q);}
 }
 if(edge)return {image,report:{...report,status:'face opening is not closed'}};
 const distance=inside=>{const d=new Uint16Array(n);d.fill(65535);const q=[];
  for(let p=0;p<n;p++)if(inside(p)){d[p]=0;q.push(p);}
  for(let k=0;k<q.length;k++){const p=q[k];if(d[p]>=maxThickness+1)continue;for(const j of neighbours(p))if(j>=0&&d[j]>d[p]+1){d[j]=d[p]+1;q.push(j);}}
  return d;
 };
 const fromFace=distance(p=>hole[p]),fromOther=distance(p=>!hole[p]&&data[p*4+3]<=127),out=Buffer.from(data);
 let minY=h,maxY=-1;
 for(let p=0;p<n;p++){
  const y=Math.floor(p/w),i=p*4;if(y<lm.brow_y||!data[i+3])continue;
  // Two transparent sides identify an isolated rim, not the edge of a filled lock.
  // Warm dark outline only: colored ties and pale highlights are preserved.
  const warm=data[i]>=data[i+1]&&data[i+1]>=data[i+2]&&data[i]<190;
  let nearFill=false;
  if(warm&&fromFace[p]+fromOther[p]<=maxThickness+1){
   const x=p%w;
   for(let yy=Math.max(0,y-maxThickness);yy<=Math.min(h-1,y+maxThickness)&&!nearFill;yy++)for(let xx=Math.max(0,x-maxThickness);xx<=Math.min(w-1,x+maxThickness);xx++){
    const q=yy*w+xx;if(data[q*4+3]>127&&Math.min(fromFace[q],fromOther[q])>maxThickness){nearFill=true;break;}
   }
  }
  if(warm&&!nearFill&&fromFace[p]+fromOther[p]<=maxThickness+1){out.fill(0,i,i+4);report.removed_pixels++;minY=Math.min(minY,y);maxY=Math.max(maxY,y);}
 }
 return {image:{...image,data:out},report:{...report,status:'applied',removed_y:report.removed_pixels?[minY,maxY]:null}};
}
