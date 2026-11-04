// Uniform-scale/translation registration in frame pixels; no nonuniform warping.
export function outline({width:w,height:h,data},threshold=127) {
  const points=[];
  for(let y=0;y<h;y++)for(let x=0;x<w;x++)if(data[(y*w+x)*4+3]>threshold&&
    (x===0||y===0||x===w-1||y===h-1||data[(y*w+x-1)*4+3]<=threshold||data[(y*w+x+1)*4+3]<=threshold||data[((y-1)*w+x)*4+3]<=threshold||data[((y+1)*w+x)*4+3]<=threshold))points.push([x,y]);
  if(!points.length)throw Error('No opaque silhouette');return points;
}
function bounds(points){return points.reduce((b,[x,y])=>[Math.min(b[0],x),Math.min(b[1],y),Math.max(b[2],x),Math.max(b[3],y)],[Infinity,Infinity,-Infinity,-Infinity]);}
// Exact Euclidean squared distance transform (lower envelope of parabolas).
function edt1(f){const n=f.length,d=new Float64Array(n),v=new Int32Array(n),z=new Float64Array(n+1);let k=0;v[0]=0;z[0]=-Infinity;z[1]=Infinity;
  for(let q=1;q<n;q++){let s;do{s=((f[q]+q*q)-(f[v[k]]+v[k]*v[k]))/(2*q-2*v[k]);if(s<=z[k])k--;else break;}while(k>=0);k++;v[k]=q;z[k]=s;z[k+1]=Infinity;}
  k=0;for(let q=0;q<n;q++){while(z[k+1]<q)k++;d[q]=(q-v[k])**2+f[v[k]];}return d;
}
export function distanceField(image,points=outline(image)) {
  const {width:w,height:h}=image,data=new Float64Array(w*h).fill(1e12);
  for(const [x,y] of points)data[y*w+x]=0;
  for(let y=0;y<h;y++)data.set(edt1(data.subarray(y*w,(y+1)*w)),y*w);
  for(let x=0;x<w;x++){const col=Float64Array.from({length:h},(_,y)=>data[y*w+x]),d=edt1(col);for(let y=0;y<h;y++)data[y*w+x]=Math.sqrt(d[y]);}
  return {width:w,height:h,data};
}
function sample({width:w,height:h,data},x,y){const xx=Math.max(0,Math.min(w-1,x)),yy=Math.max(0,Math.min(h-1,y)),x0=Math.floor(xx),y0=Math.floor(yy),x1=Math.min(w-1,x0+1),y1=Math.min(h-1,y0+1),fx=xx-x0,fy=yy-y0;
  return (1-fy)*((1-fx)*data[y0*w+x0]+fx*data[y0*w+x1])+fy*((1-fx)*data[y1*w+x0]+fx*data[y1*w+x1])+Math.hypot(x-xx,y-yy);
}
export function fitBody(source,target,{seed,scaleRange=.12,visible=()=>true}={}) {
  const sp=outline(source),tp=outline(target).filter(([x,y])=>visible(x,y)),sb=bounds(sp),tb=bounds(tp),sd=distanceField(source,sp),td=distanceField(target,tp);
  const initial=seed??{scale:(tb[3]-tb[1])/(sb[3]-sb[1]),offset:[0,0]};
  if(!seed)initial.offset=[(tb[0]+tb[2])/2-initial.scale*(sb[0]+sb[2])/2,tb[1]-initial.scale*sb[1]];
  const score=({scale:s,offset:[dx,dy]})=>{
    let forward=0,reverse=0,count=0;
    for(const [x,y] of sp)if(visible(x*s+dx,y*s+dy)){forward+=sample(td,x*s+dx,y*s+dy);count++;}
    for(const [x,y] of tp)reverse+=sample(sd,(x-dx)/s,(y-dy)/s)*s;
    return (forward/Math.max(1,count)+reverse/tp.length)/2;
  };
  let best={scale:initial.scale,offset:[...initial.offset]},cost=score(best);
  for(const step of [4,2,1,.5,.25,.125,.0625])for(let iteration=0;iteration<100;iteration++){
    let next=best,nextCost=cost;
    for(const ds of [-1,0,1])for(const dx of [-1,0,1])for(const dy of [-1,0,1]){
      if(!ds&&!dx&&!dy)continue;
      const candidate={scale:best.scale+ds*step/(sb[3]-sb[1]),offset:[best.offset[0]+dx*step,best.offset[1]+dy*step]};
      if(candidate.scale<=0||Math.abs(candidate.scale/initial.scale-1)>scaleRange)continue;
      const c=score(candidate);if(c<nextCost-1e-9){next=candidate;nextCost=c;}
    }
    if(next===best)break;best=next;cost=nextCost;
  }
  return {...best,residual_px:cost,metric:'symmetric mean outline chamfer, Euclidean frame pixels',source_outline:sp.length,target_outline:tp.length,seed:initial};
}
export function crop(image,[x,y,width,height]) {
  if(x<0||y<0||x+width>image.width||y+height>image.height)throw Error('Crop outside source');
  const data=Buffer.alloc(width*height*4);for(let row=0;row<height;row++)image.data.copy(data,row*width*4,((row+y)*image.width+x)*4,((row+y)*image.width+x+width)*4);return {width,height,data};
}
// Isolate the largest connected component inside a crop; neighbouring items whose
// bounding boxes overlap must not contaminate the body's fit.
export function isolateLargest(image){const {width:w,height:h}=image,seen=new Uint8Array(w*h);let largest=[];
 for(let p=0;p<w*h;p++){if(seen[p]||image.data[p*4+3]<=127)continue;const q=[p];seen[p]=1;for(let k=0;k<q.length;k++){const i=q[k],x=i%w,y=Math.floor(i/w);for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++){const xx=x+dx,yy=y+dy,j=yy*w+xx;if(xx>=0&&yy>=0&&xx<w&&yy<h&&!seen[j]&&image.data[j*4+3]>127){seen[j]=1;q.push(j);}}}if(q.length>largest.length)largest=q;}
 const data=Buffer.alloc(w*h*4),belongs=new Uint8Array(w*h);for(const p of largest)belongs[p]=1;
 // Restore adjacent fractional-alpha edge samples without retaining a neighbouring
 // item's opaque pixels merely because its bounding box overlaps the body crop.
 for(const p of largest){const x=p%w,y=Math.floor(p/w);for(let dy=-2;dy<=2;dy++)for(let dx=-2;dx<=2;dx++){const xx=x+dx,yy=y+dy,q=yy*w+xx;if(xx>=0&&yy>=0&&xx<w&&yy<h&&image.data[q*4+3]<=127)belongs[q]=1;}}
 for(let p=0;p<w*h;p++)if(belongs[p])image.data.copy(data,p*4,p*4,p*4+4);return {...image,data};
}
export function eyeCentres(image){const {width:w,height:h,data}=image,b=bounds(outline(image)),bw=b[2]-b[0],bh=b[3]-b[1],seen=new Uint8Array(w*h),blobs=[];
 const dark=(x,y)=>x>=b[0]+bw*.2&&x<=b[0]+bw*.8&&y>=b[1]+bh*.2&&y<=b[1]+bh*.43&&data[(y*w+x)*4+3]>127&&data[(y*w+x)*4]<180&&data[(y*w+x)*4+1]<110&&data[(y*w+x)*4+2]<100;
 for(let y=Math.ceil(b[1]+bh*.2);y<=b[1]+bh*.43;y++)for(let x=Math.ceil(b[0]+bw*.2);x<=b[0]+bw*.8;x++){const p=y*w+x;if(seen[p]||!dark(x,y))continue;const q=[p];seen[p]=1;let sx=0,sy=0,x0=x,x1=x,y0=y,y1=y;
 for(let k=0;k<q.length;k++){const i=q[k],xx=i%w,yy=Math.floor(i/w);sx+=xx;sy+=yy;x0=Math.min(x0,xx);x1=Math.max(x1,xx);y0=Math.min(y0,yy);y1=Math.max(y1,yy);for(const [nx,ny] of [[xx-1,yy],[xx+1,yy],[xx,yy-1],[xx,yy+1]])if(dark(nx,ny)&&!seen[ny*w+nx]){seen[ny*w+nx]=1;q.push(ny*w+nx);}}
 if(q.length>10&&y1-y0>(x1-x0)*.85)blobs.push({area:q.length,point:[sx/q.length,sy/q.length]});}
 const eyes=blobs.sort((a,b)=>b.area-a.area).slice(0,2).map(b=>b.point).sort((a,b)=>a[0]-b[0]);if(eyes.length!==2)throw Error('Expected two compact eye blobs in face window');return eyes;
}
export function landmarkSeed(source,target){const se=eyeCentres(source),te=eyeCentres(target),sb=bounds(outline(source)),tb=bounds(outline(target));
 const sp=[...se,[(sb[0]+sb[2])/2,sb[3]]],tp=[...te,[(tb[0]+tb[2])/2,tb[3]]],sc=[0,1].map(k=>sp.reduce((s,p)=>s+p[k],0)/3),tc=[0,1].map(k=>tp.reduce((s,p)=>s+p[k],0)/3);
 let numerator=0,denominator=0;for(let i=0;i<3;i++)for(let k=0;k<2;k++){numerator+=(sp[i][k]-sc[k])*(tp[i][k]-tc[k]);denominator+=(sp[i][k]-sc[k])**2;}
 const scale=numerator/denominator,rotationDegrees=(Math.atan2(te[1][1]-te[0][1],te[1][0]-te[0][0])-Math.atan2(se[1][1]-se[0][1],se[1][0]-se[0][0]))*180/Math.PI;
 return {scale,offset:tc.map((v,k)=>v-scale*sc[k]),rotationDegrees,sourceEyes:se,targetEyes:te};
}
export function gates(fit,{expectedScale=1,maxScaleCorrection=.04,maxShift=Infinity,maxResidual=1.5,rotationDegrees=0}={}){const failures=[];if(Math.abs(fit.scale/expectedScale-1)>maxScaleCorrection)failures.push('scale-correction');if(Math.hypot(...fit.offset)>maxShift)failures.push('translation-correction');if(fit.residual_px>maxResidual)failures.push('outline-residual');if(Math.abs(rotationDegrees)>=1)failures.push('rotation');return {pass:failures.length===0,failures};}
