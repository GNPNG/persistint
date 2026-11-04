// Source-resolution chroma unmix. No flood-fill exclusion for enclosed green.
const clamp=x=>Math.max(0,Math.min(255,Math.round(x)));
export function borderKey({width:w,height:h,data}) {
  const channels=[[],[],[]];
  for(let y=0;y<h;y++)for(let x=0;x<w;x++)if(x===0||y===0||x===w-1||y===h-1)for(let c=0;c<3;c++)channels[c].push(data[(y*w+x)*4+c]);
  return channels.map(a=>a.sort((a,b)=>a-b)[Math.floor(a.length/2)]);
}
export function greenMatte(image,{key=borderKey(image),outline=[100,60,40],solidExcess=24}={}) {
  const data=Buffer.from(image.data),ke=key[1]-Math.max(key[0],key[2]),fe=outline[1]-Math.max(outline[0],outline[2]);
  if(ke<80)throw Error('Backing is not a green chroma key');
  for(let i=0;i<data.length;i+=4){
    // Generated green backings contain small compression/colour noise. Reject
    // near-key pixels before unmixing, which would amplify noise into cyan specks.
    if(Math.hypot(data[i]-key[0],data[i+1]-key[1],data[i+2]-key[2])<=12){data.fill(0,i,i+4);continue;}
    const e=data[i+1]-Math.max(data[i],data[i+2]);
    // Preserve palette interiors (including turquoise and sky blue).
    const estimated=Math.max(0,Math.min(1,(ke-e)/(ke-fe)));
    const outlineBlend=Math.hypot(...outline.map((f,c)=>data[i+c]-(estimated*f+(1-estimated)*key[c])))<=3;
    if(e<=solidExcess&&!outlineBlend)continue;
    const a=Math.max(0,Math.min(1,(ke-e)/(ke-fe)));
    if(a<.1){data.fill(0,i,i+4);continue;}
    for(let c=0;c<3;c++)data[i+c]=a?clamp((data[i+c]-(1-a)*key[c])/a):0;
    data[i+1]=Math.min(data[i+1],Math.max(data[i],data[i+2]));
    data[i+3]=clamp(data[i+3]*a);
  }
  return {...image,data};
}
// White removal is limited to exterior-connected white and its boundary band.
// Foreground estimates come from nearby dark outline pixels, not white interiors.
export function whiteMatte(image,{band=4,whiteThreshold=235}={}) {
  const {width:w,height:h}=image,n=w*h,data=Buffer.from(image.data),outside=new Uint8Array(n),queue=new Int32Array(n);let head=0,tail=0;
  const light=p=>Math.min(...image.data.subarray(p*4,p*4+3))>=whiteThreshold;
  const add=p=>{if(!outside[p]&&light(p)){outside[p]=1;queue[tail++]=p;}};
  for(let x=0;x<w;x++){add(x);add((h-1)*w+x);}for(let y=0;y<h;y++){add(y*w);add(y*w+w-1);}
  while(head<tail){const p=queue[head++],x=p%w,y=Math.floor(p/w);if(x)add(p-1);if(x+1<w)add(p+1);if(y)add(p-w);if(y+1<h)add(p+w);}
  // Grow inward from the exterior only until the opaque dark outline is reached.
  // Never cross that outline into enclosed white content.
  const boundary=new Uint8Array(outside),distance=new Uint8Array(n);head=0;
  while(head<tail){const p=queue[head++];if(distance[p]>=band)continue;
    if(!outside[p]&&Math.min(...image.data.subarray(p*4,p*4+3))<150)continue;
    const x=p%w,y=Math.floor(p/w);
    for(const q of [x?p-1:-1,x+1<w?p+1:-1,y?p-w:-1,y+1<h?p+w:-1])if(q>=0&&!boundary[q]){boundary[q]=1;distance[q]=distance[p]+1;queue[tail++]=q;}
  }
  for(let p=0;p<n;p++){
    if(!boundary[p])continue;
    const x=p%w,y=Math.floor(p/w);let best=null,bestScore=Infinity;
    for(let dy=-band;dy<=band;dy++)for(let dx=-band;dx<=band;dx++){
      if(x+dx<0||x+dx>=w||y+dy<0||y+dy>=h)continue;const q=(y+dy)*w+x+dx;
      const rgb=image.data.subarray(q*4,q*4+3),d=dx*dx+dy*dy;
      const score=(rgb[0]+rgb[1]+rgb[2])*1000+d;
      if(Math.max(...rgb)<175&&score<bestScore){best=[...rgb];bestScore=score;}
    }
    if(!best){if(outside[p])data[p*4+3]=0;continue;}
    const c=[...image.data.subarray(p*4,p*4+3)],v=best.map(f=>255-f);
    const a=Math.max(0,Math.min(1,c.reduce((s,c,k)=>s+(255-c)*v[k],0)/v.reduce((s,x)=>s+x*x,0)));
    for(let k=0;k<3;k++)data[p*4+k]=a?clamp((c[k]-(1-a)*255)/a):0;
    data[p*4+3]=clamp(a*image.data[p*4+3]);
  }
  return {...image,data};
}
