import fs from 'node:fs';
import {execFileSync} from 'node:child_process';
export function magick(args,input) {return execFileSync('magick',args,{input,maxBuffer:256*1024*1024});}
export function readImage(file) {
  const [width,height]=magick([file,'-format','%w %h','info:']).toString().trim().split(/\s+/).map(Number);
  return {width,height,data:magick([file,'-depth','8','rgba:-'])};
}
export function writeImage(file,{width,height,data}) {
  if(data.length!==width*height*4)throw Error('RGBA length differs from dimensions');
  magick(['-size',`${width}x${height}`,'-depth','8','rgba:-','-strip',`PNG32:${file}`],data);
}
export function resample(image,width,height) {
  const data=magick(['-size',`${image.width}x${image.height}`,'-depth','8','rgba:-','-filter','Lanczos','-resize',`${width}x${height}!`,'-clamp','-depth','8','rgba:-'],image.data);
  return {width,height,data};
}
export function isPng(file) {return fs.readFileSync(file).subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]));}
