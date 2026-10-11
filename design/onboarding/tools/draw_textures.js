// Generates every ck_onb_* texture. Run via run_script: new Function('createCanvas', src + ';return drawAll(createCanvas);')
function drawAll(createCanvas){
const C={bg:'#16110C',panel:'#120D08',ctrl:'#0F0B07',title:'#F2C43C',sel:'#FFD24A',gold:'#C9A25A',selText:'#FFF3D0',text:'#EFE4C8',text2:'#D8CCB0',help:'#B9AB8C',gray:'#9D917A',dis:'#6F6452',bronze:'#7A5D36',f1:'#5A4630',f2:'#4A3A26',f3:'#3A2C1D',frame:'#7A6448',info:'#9FD8E2',warn:'#F0A090',danger:'#FF7A5C',ok:'#7AA04A',cyan:'#5FC0D0'};
const PI=Math.PI,TAU=PI*2,out={},meta={};
const rgba=(h,a)=>{const n=parseInt(h.slice(1),16);return 'rgba('+(n>>16)+','+((n>>8)&255)+','+(n&255)+','+a+')';};
const mk=(w,h)=>{const c=createCanvas(w,h);const x=c.getContext('2d');x.lineCap='round';x.lineJoin='round';return [c,x];};
const rr=(x,X,Y,w,h,r)=>{x.beginPath();x.moveTo(X+r,Y);x.arcTo(X+w,Y,X+w,Y+h,r);x.arcTo(X+w,Y+h,X,Y+h,r);x.arcTo(X,Y+h,X,Y,r);x.arcTo(X,Y,X+w,Y,r);x.closePath();};
const circ=(x,X,Y,r)=>{x.beginPath();x.arc(X,Y,r,0,TAU);};
const ring=(x,X,Y,r,fill,stroke,lw)=>{circ(x,X,Y,r);if(fill){x.fillStyle=fill;x.fill();}if(stroke){x.lineWidth=lw||2;x.strokeStyle=stroke;x.stroke();}};
const glow=(x,col,b)=>{x.shadowColor=col;x.shadowBlur=b;};
const halo=(x,X,Y,r,a,col)=>{const g=x.createRadialGradient(X,Y,0,X,Y,r);g.addColorStop(0,rgba(col||C.title,a));g.addColorStop(1,rgba(col||C.title,0));x.fillStyle=g;x.fillRect(X-r,Y-r,2*r,2*r);};
const shadowEl=(x,X,Y,rx,ry,a)=>{x.save();x.translate(X,Y);x.scale(1,ry/rx);const g=x.createRadialGradient(0,0,0,0,0,rx);g.addColorStop(0,'rgba(0,0,0,'+a+')');g.addColorStop(1,'rgba(0,0,0,0)');x.fillStyle=g;circ(x,0,0,rx);x.fill();x.restore();};
const rad=(x,X,Y,r,c0,c1)=>{const g=x.createRadialGradient(X-r*.35,Y-r*.35,r*.05,X,Y,r);g.addColorStop(0,c0);g.addColorStop(1,c1);return g;};
const diamond=(x,X,Y,s,col)=>{x.beginPath();x.moveTo(X,Y-s);x.lineTo(X+s,Y);x.lineTo(X,Y+s);x.lineTo(X-s,Y);x.closePath();x.fillStyle=col;x.fill();};
const chevron=(x,X,Y,ang,s,col,lw)=>{x.save();x.translate(X,Y);x.rotate(ang);x.beginPath();x.moveTo(-s,s*.5);x.lineTo(0,-s*.5);x.lineTo(s,s*.5);x.lineWidth=lw;x.strokeStyle=col;x.stroke();x.restore();};
const star4=(x,X,Y,s,col)=>{x.beginPath();for(let i=0;i<8;i++){const a=i*PI/4-PI/2,r=i%2?s*.28:s;x.lineTo(X+Math.cos(a)*r,Y+Math.sin(a)*r);}x.closePath();x.fillStyle=col;x.fill();};

// ---------- gamepad ----------
function padPath(x,cx,cy,W){const P=(a,b)=>[cx+a*W,cy+b*W];const b=(p,q,r)=>x.bezierCurveTo(...P(...p),...P(...q),...P(...r));
 x.beginPath();x.moveTo(...P(-0.28,-0.27));
 b([-0.1,-0.30],[0.1,-0.30],[0.28,-0.27]);b([0.40,-0.25],[0.47,-0.18],[0.48,-0.05]);b([0.50,0.12],[0.48,0.30],[0.40,0.34]);
 b([0.33,0.37],[0.27,0.32],[0.23,0.22]);b([0.19,0.13],[0.12,0.10],[0,0.10]);b([-0.12,0.10],[-0.19,0.13],[-0.23,0.22]);
 b([-0.27,0.32],[-0.33,0.37],[-0.40,0.34]);b([-0.48,0.30],[-0.50,0.12],[-0.48,-0.05]);b([-0.47,-0.18],[-0.40,-0.25],[-0.28,-0.27]);x.closePath();}
function padBody(x,cx,cy,W,back){
 padPath(x,cx,cy,W);const g=x.createLinearGradient(0,cy-0.3*W,0,cy+0.37*W);
 g.addColorStop(0,back?'#261d14':'#30251a');g.addColorStop(0.55,back?'#18120c':'#1c150e');g.addColorStop(1,'#0e0a06');x.fillStyle=g;x.fill();
 x.save();padPath(x,cx,cy,W);x.clip();
 x.lineWidth=W/22;x.strokeStyle=rgba(C.gold,0.10);padPath(x,cx,cy,W);x.stroke();
 x.lineWidth=1.5;x.strokeStyle=C.f3;padPath(x,cx,cy+0.012*W,0.9*W);x.stroke();
 const s=x.createLinearGradient(0,cy-0.3*W,0,cy-0.08*W);s.addColorStop(0,rgba(C.selText,0.09));s.addColorStop(1,rgba(C.selText,0));x.fillStyle=s;x.fillRect(cx-W,cy-0.32*W,2*W,0.24*W);
 x.restore();padPath(x,cx,cy,W);x.lineWidth=Math.max(2,W/150);x.strokeStyle=C.frame;x.stroke();}
function stick(x,X,Y,r){ring(x,X,Y,r*1.3,'#0b0805',C.f1,1.5);ring(x,X,Y,r,rad(x,X,Y,r,'#47382a','#17110b'),C.frame,2);ring(x,X,Y,r*.6,null,rgba(C.gold,.3),1.5);}
function dpad(x,X,Y,s){const t=s*0.36;const p=[[-t,-s],[t,-s],[t,-t],[s,-t],[s,t],[t,t],[t,s],[-t,s],[-t,t],[-s,t],[-s,-t],[-t,-t]];
 x.beginPath();p.forEach((q,i)=>i?x.lineTo(X+q[0],Y+q[1]):x.moveTo(X+q[0],Y+q[1]));x.closePath();x.fillStyle='#1a130c';x.fill();x.lineWidth=2;x.strokeStyle=C.frame;x.stroke();}
function face(x,X,Y,d,r,lit){ring(x,X,Y,d+r*1.6,'rgba(11,8,5,0.8)',C.f2,1.5);
 [[0,-d],[d,0],[0,d],[-d,0]].forEach((o,i)=>{const px=X+o[0],py=Y+o[1];
  if(i===lit){x.save();glow(x,C.sel,16);ring(x,px,py,r,rad(x,px,py,r,C.selText,C.sel),null);x.restore();ring(x,px,py,r,null,C.selText,1.5);}
  else ring(x,px,py,r,rad(x,px,py,r,'#3e3020','#15100a'),C.gold,1.5);});}
function frontPad(x,cx,cy,W,lit){const P=(a,b)=>[cx+a*W,cy+b*W];
 [-1,1].forEach(sd=>{const [bx,by]=P(sd*0.30,-0.30);rr(x,bx-0.11*W,by-0.02*W,0.22*W,0.06*W,0.03*W);x.fillStyle='#1d160e';x.fill();x.lineWidth=1.5;x.strokeStyle=C.f1;x.stroke();});
 padBody(x,cx,cy,W,false);
 let q=P(-0.27,-0.14);stick(x,q[0],q[1],0.05*W);
 q=P(-0.14,0.01);ring(x,q[0],q[1],0.068*W,'#0b0805',C.f1,1.5);dpad(x,q[0],q[1],0.05*W);
 q=P(0.14,0.01);stick(x,q[0],q[1],0.046*W);
 q=P(0.27,-0.14);face(x,q[0],q[1],0.052*W,0.022*W,lit);
 [-1,1].forEach(sd=>{const [bx,by]=P(sd*0.065,-0.15);rr(x,bx-0.022*W,by-0.009*W,0.044*W,0.018*W,0.009*W);x.fillStyle='#0f0b07';x.fill();x.lineWidth=1.2;x.strokeStyle=C.f1;x.stroke();});
 q=P(0,-0.215);ring(x,q[0],q[1],0.024*W,'#0f0b07',C.gold,1.5);ring(x,q[0],q[1],0.010*W,rgba(C.gold,.55),null);}
function backPad(x,cx,cy,W){const P=(a,b)=>[cx+a*W,cy+b*W];
 [-1,1].forEach(sd=>{const [tx,ty]=P(sd*0.30,-0.335);rr(x,tx-0.085*W,ty-0.04*W,0.17*W,0.13*W,0.045*W);const g=x.createLinearGradient(0,ty-0.04*W,0,ty+0.09*W);g.addColorStop(0,'#2c2117');g.addColorStop(1,'#120d08');x.fillStyle=g;x.fill();x.lineWidth=1.5;x.strokeStyle=C.f1;x.stroke();
  x.beginPath();x.moveTo(tx-0.05*W,ty-0.012*W);x.lineTo(tx+0.05*W,ty-0.012*W);x.strokeStyle=rgba(C.gold,.25);x.stroke();});
 [-1,1].forEach(sd=>{const [bx,by]=P(sd*0.30,-0.29);rr(x,bx-0.12*W,by-0.02*W,0.24*W,0.055*W,0.027*W);x.fillStyle='#211910';x.fill();x.lineWidth=1.5;x.strokeStyle=C.f1;x.stroke();});
 padBody(x,cx,cy,W,true);
 rr(x,cx-0.12*W,cy-0.17*W,0.24*W,0.17*W,0.03*W);x.lineWidth=1.5;x.strokeStyle=C.f2;x.stroke();
 rr(x,cx-0.03*W,cy-0.2*W,0.06*W,0.014*W,0.007*W);x.fillStyle=C.f2;x.fill();}

// ---------- WELCOME 512x256 ----------
{const [c,x]=mk(512,256);
 halo(x,256,96,200,0.15);
 shadowEl(x,256,238,170,12,0.6);
 [[20,118],[492,118]].forEach(([X],i)=>{const g=x.createLinearGradient(X,0,i?400:112,0);g.addColorStop(0,rgba(C.gold,0));g.addColorStop(1,rgba(C.gold,.6));x.fillStyle=g;x.fillRect(Math.min(X,i?400:112),117,Math.abs((i?400:112)-X),1.5);});
 diamond(x,30,118,4,C.gold);diamond(x,482,118,4,C.gold);
 frontPad(x,256,120,330,2);
 star4(x,94,40,9,rgba(C.sel,.8));star4(x,428,206,7,rgba(C.sel,.6));star4(x,446,48,5,rgba(C.gold,.6));
 out.ck_onb_welcome=c;}

// ---------- PADDLES 512x256 (+ glows) ----------
const PW=320,PCX=256,PCY=129;
const paddles=[{id:'l4',a:-0.40,b:0.14,ang:-0.14},{id:'l5',a:-0.30,b:0.185,ang:-0.22},{id:'r5',a:0.30,b:0.185,ang:0.22},{id:'r4',a:0.40,b:0.14,ang:0.14}];
paddles.forEach(p=>{p.X=PCX+p.a*PW;p.Y=PCY+p.b*PW;});
const paddleShape=(x,p)=>{x.save();x.translate(p.X,p.Y);x.rotate(p.ang);rr(x,-0.0225*PW,-0.085*PW,0.045*PW,0.17*PW,0.0225*PW);x.restore();};
const paddleGlow=(x,p)=>{x.save();glow(x,C.sel,20);paddleShape(x,p);x.fillStyle=rgba(C.sel,0.95);x.fill();x.fill();x.restore();
 x.save();glow(x,C.selText,6);paddleShape(x,p);x.lineWidth=2;x.strokeStyle=C.selText;x.stroke();x.restore();};
{const [c,x]=mk(512,256);
 shadowEl(x,256,246,170,9,0.55);
 backPad(x,PCX,PCY,PW);
 paddles.forEach(p=>{halo(x,p.X,p.Y,40,0.16,C.sel);
  x.save();glow(x,rgba(C.sel,.45),10);paddleShape(x,p);const g=x.createLinearGradient(p.X-9,0,p.X+9,0);g.addColorStop(0,'#6e5532');g.addColorStop(1,'#3a2c1d');x.fillStyle=g;x.fill();x.restore();
  paddleShape(x,p);x.lineWidth=2;x.strokeStyle=C.gold;x.stroke();
  x.save();x.translate(p.X,p.Y);x.rotate(p.ang);x.beginPath();x.moveTo(0,-0.055*PW);x.lineTo(0,0.055*PW);x.strokeStyle=rgba(C.selText,.35);x.lineWidth=1.5;x.stroke();x.restore();});
 out.ck_onb_paddles=c;}
{const [c,x]=mk(512,256);paddles.forEach(p=>paddleGlow(x,p));out.ck_onb_paddles_glow=c;}
paddles.forEach(p=>{const [c,x]=mk(512,256);paddleGlow(x,p);out['ck_onb_paddles_'+p.id+'_glow']=c;});
meta.paddles=paddles.map(p=>({id:p.id,x:Math.round(p.X),y:Math.round(p.Y)}));

// ---------- TOUCHPAD 256 (+ 4 zone glows) ----------
const T0=36,TS=184,TR=30,TC=128;
const padSq=x=>rr(x,T0,T0,TS,TS,TR);
const zones={up:[[T0,T0],[T0+TS,T0],0,[128,72]],right:[[T0+TS,T0],[T0+TS,T0+TS],PI/2,[184,128]],down:[[T0+TS,T0+TS],[T0,T0+TS],PI,[128,184]],left:[[T0,T0+TS],[T0,T0],-PI/2,[72,128]]};
{const [c,x]=mk(256,256);
 shadowEl(x,128,234,110,8,0.5);
 rr(x,T0-9,T0-9,TS+18,TS+18,TR+9);x.fillStyle='#0f0b07';x.fill();x.lineWidth=1.5;x.strokeStyle=C.f1;x.stroke();
 padSq(x);const g=x.createLinearGradient(0,T0,0,T0+TS);g.addColorStop(0,'#2a2016');g.addColorStop(1,'#130e09');x.fillStyle=g;x.fill();
 x.save();padSq(x);x.clip();x.lineWidth=10;x.strokeStyle=rgba(C.gold,.08);padSq(x);x.stroke();
 x.setLineDash([5,5]);x.lineWidth=1.5;x.strokeStyle=C.f1;x.beginPath();x.moveTo(T0,T0);x.lineTo(T0+TS,T0+TS);x.moveTo(T0+TS,T0);x.lineTo(T0,T0+TS);x.stroke();x.setLineDash([]);x.restore();
 padSq(x);x.lineWidth=2.5;x.strokeStyle=C.frame;x.stroke();
 ring(x,TC,TC,12,'#120d08',C.f1,1.5);
 Object.values(zones).forEach(z=>chevron(x,z[3][0],z[3][1],z[2],11,rgba(C.gold,.8),3));
 out.ck_onb_touchpad=c;}
Object.entries(zones).forEach(([k,z])=>{const [c,x]=mk(256,256);
 x.save();padSq(x);x.clip();x.beginPath();x.moveTo(TC,TC);x.lineTo(...z[0]);x.lineTo(...z[1]);x.closePath();x.clip();
 const m=[(z[0][0]+z[1][0])/2,(z[0][1]+z[1][1])/2];const g=x.createLinearGradient(TC,TC,m[0],m[1]);g.addColorStop(0,rgba(C.sel,0.06));g.addColorStop(1,rgba(C.sel,0.5));x.fillStyle=g;x.fillRect(0,0,256,256);
 glow(x,C.sel,14);padSq(x);x.lineWidth=7;x.strokeStyle=C.sel;x.stroke();x.restore();
 x.save();glow(x,C.sel,10);chevron(x,z[3][0],z[3][1],z[2],11,C.selText,3.5);x.restore();
 out['ck_onb_touchpad_'+k+'_glow']=c;});

// ---------- TOGGLE 256x128 (+ glow) ----------
const ltPath=(x,X,Y,w,h)=>{x.beginPath();x.moveTo(X,Y+h);x.lineTo(X,Y+h*0.45);x.bezierCurveTo(X,Y+h*0.08,X+w*0.25,Y,X+w*0.55,Y);x.lineTo(X+w*0.72,Y);x.quadraticCurveTo(X+w,Y,X+w,Y+h*0.3);x.lineTo(X+w,Y+h);x.closePath();};
const DOFF=[[0,-17],[17,0],[0,17],[-17,0]];
const slot=(x,X,Y,on)=>{rr(x,X-8,Y-8,16,16,3);if(on){x.save();glow(x,C.sel,10);x.fillStyle='#3a2e12';x.fill();x.restore();rr(x,X-8,Y-8,16,16,3);x.lineWidth=2;x.strokeStyle=C.sel;x.stroke();}else{x.fillStyle=C.ctrl;x.fill();x.lineWidth=1.5;x.strokeStyle=C.f2;x.stroke();}};
{const [c,x]=mk(256,128);
 rr(x,14,100,72,8,4);x.fillStyle='#1d160e';x.fill();x.lineWidth=1.5;x.strokeStyle=C.f1;x.stroke();
 x.setLineDash([3,4]);ltPath(x,22,30,56,60);x.lineWidth=1.5;x.strokeStyle=C.f1;x.stroke();x.setLineDash([]);
 x.save();glow(x,rgba(C.sel,.6),12);ltPath(x,22,40,56,60);const g=x.createLinearGradient(0,40,0,100);g.addColorStop(0,'#55421c');g.addColorStop(1,'#241c0b');x.fillStyle=g;x.fill();x.restore();
 ltPath(x,22,40,56,60);x.lineWidth=2.5;x.strokeStyle=C.sel;x.stroke();
 [58,68].forEach(y=>{x.beginPath();x.moveTo(32,y);x.lineTo(68,y);x.strokeStyle=rgba(C.selText,.25);x.lineWidth=1.5;x.stroke();});
 chevron(x,50,18,PI,7,C.sel,3);
 x.beginPath();x.moveTo(98,70);x.lineTo(132,70);x.moveTo(125,63);x.lineTo(133,70);x.lineTo(125,77);x.strokeStyle=C.gold;x.lineWidth=2.5;x.stroke();
 halo(x,172,66,44,.16,C.sel);
 DOFF.forEach(o=>slot(x,172+o[0],66+o[1],true));DOFF.forEach(o=>slot(x,226+o[0],66+o[1],false));
 x.save();glow(x,C.sel,8);rr(x,156,102,32,4,2);x.fillStyle=C.sel;x.fill();x.restore();
 out.ck_onb_toggle=c;}
{const [c,x]=mk(256,128);
 x.save();glow(x,C.sel,16);ltPath(x,22,40,56,60);x.lineWidth=3;x.strokeStyle=C.sel;x.stroke();x.fillStyle=rgba(C.sel,.25);x.fill();x.restore();
 DOFF.forEach(o=>{x.save();glow(x,C.sel,12);rr(x,172+o[0]-8,66+o[1]-8,16,16,3);x.fillStyle=rgba(C.sel,.55);x.fill();x.lineWidth=2;x.strokeStyle=C.selText;x.stroke();x.restore();});
 x.save();glow(x,C.sel,10);rr(x,156,102,32,4,2);x.fillStyle=C.selText;x.fill();x.restore();
 out.ck_onb_toggle_glow=c;}

// ---------- DAISYWHEEL 256 ----------
{const [c,x]=mk(256,256);const cx=128,cy=128,R=84,sel=1;
 halo(x,cx,cy,128,.10);
 ring(x,cx,cy,R,null,C.f3,2);
 const pa=i=>-PI/2+i*PI/4;const sp=[cx+Math.cos(pa(sel))*R,cy+Math.sin(pa(sel))*R];
 x.beginPath();x.moveTo(cx,cy);x.lineTo(sp[0],sp[1]);x.strokeStyle=rgba(C.sel,.5);x.lineWidth=2;x.stroke();
 for(let i=0;i<8;i++){const px=cx+Math.cos(pa(i))*R,py=cy+Math.sin(pa(i))*R,on=i===sel;
  if(on){x.save();glow(x,C.sel,14);ring(x,px,py,30,'#33280f',null);x.restore();ring(x,px,py,30,null,C.sel,2.5);}
  else ring(x,px,py,30,rad(x,px,py,30,'#261d13','#110c07'),C.f1,2);
  [[0,-11],[11,0],[0,11],[-11,0]].forEach((o,j)=>{if(on&&j===1){x.save();glow(x,C.sel,8);ring(x,px+o[0],py+o[1],6,C.sel,null);x.restore();}else ring(x,px+o[0],py+o[1],4.5,on?C.selText:rgba(C.text2,.6),null);});}
 stick(x,cx,cy,22);ring(x,cx+Math.cos(pa(sel))*9,cy+Math.sin(pa(sel))*9,5,C.sel,null);
 out.ck_onb_daisywheel=c;}

// ---------- SPLIT KEYBOARD 256 ----------
{const [c,x]=mk(256,256);
 const KW=17,G=4,PWd=5*KW+4*G+12,PH=4*KW+3*G+12;
 const half=(cx,cy,ang,cur)=>{x.save();x.translate(cx,cy);x.rotate(ang);
  x.save();glow(x,'rgba(0,0,0,.6)',10);rr(x,-PWd/2,-PH/2,PWd,PH,10);const g=x.createLinearGradient(0,-PH/2,0,PH/2);g.addColorStop(0,'#2a2016');g.addColorStop(1,'#120d08');x.fillStyle=g;x.fill();x.restore();
  rr(x,-PWd/2,-PH/2,PWd,PH,10);x.lineWidth=2;x.strokeStyle=C.frame;x.stroke();
  const ox=-PWd/2+6,oy=-PH/2+6;
  const key=(kx,ky,kw,on)=>{rr(x,kx,ky,kw,KW,4);if(on){x.save();glow(x,C.sel,10);x.fillStyle='#3a2e12';x.fill();x.restore();rr(x,kx,ky,kw,KW,4);x.lineWidth=2;x.strokeStyle=C.sel;x.stroke();}else{x.fillStyle='#1a140d';x.fill();x.lineWidth=1.2;x.strokeStyle=C.f1;x.stroke();x.beginPath();x.moveTo(kx+4,ky+3);x.lineTo(kx+kw-4,ky+3);x.strokeStyle=rgba(C.gold,.14);x.lineWidth=1;x.stroke();}};
  for(let r=0;r<3;r++)for(let k=0;k<5;k++)key(ox+k*(KW+G),oy+r*(KW+G),KW,cur[0]===k&&cur[1]===r);
  key(ox,oy+3*(KW+G),KW,false);key(ox+KW+G,oy+3*(KW+G),3*KW+2*G,false);key(ox+4*(KW+G),oy+3*(KW+G),KW,false);
  x.restore();};
 halo(x,128,110,130,.08);
 half(64,100,-0.07,[1,1]);half(192,100,0.07,[3,0]);
 [[64,1,1],[192,3,0]].forEach(([sx])=>{x.setLineDash([3,4]);x.beginPath();x.moveTo(sx,152);x.lineTo(sx,170);x.strokeStyle=rgba(C.gold,.55);x.lineWidth=1.5;x.stroke();x.setLineDash([]);});
 stick(x,64,196,19);ring(x,64-5,196-5,4.5,C.sel,null);
 stick(x,192,196,19);ring(x,192+5,196-6,4.5,C.sel,null);
 out.ck_onb_splitkb=c;}

// ---------- WHEELS ----------
function wheelBase(x,n,selIdx){const cx=128,cy=128;
 shadowEl(x,cx,cy+6,120,120,0.35);
 ring(x,cx,cy,112,(()=>{const g=x.createRadialGradient(cx,cy,30,cx,cy,112);g.addColorStop(0,'rgba(24,18,12,0.97)');g.addColorStop(1,'rgba(15,11,7,0.97)');return g;})(),null);
 ring(x,cx,cy,112,null,C.gold,2.5);ring(x,cx,cy,106,null,rgba(C.bronze,.8),1.5);
 const pos=[];for(let i=0;i<n;i++){const a=-PI/2+i*TAU/n;pos.push([cx+Math.cos(a)*74,cy+Math.sin(a)*74]);}
 pos.forEach(([px,py])=>ring(x,px,py,24,rad(x,px,py,24,'#241b12','#0f0b07'),C.f1,2));
 const [sx,sy]=pos[selIdx];x.save();x.setLineDash([5,4]);glow(x,C.sel,6);ring(x,sx,sy,29,null,C.sel,2);x.restore();
 ring(x,cx,cy,36,'#0f0b07',C.gold,3);ring(x,cx,cy,30,null,C.f1,1.5);
 const a=Math.atan2(sy-cy,sx-cx);ring(x,cx+Math.cos(a)*14,cy+Math.sin(a)*14,6,C.sel,null);ring(x,cx,cy,4,rgba(C.gold,.6),null);
 return pos;}
const plus=(x,X,Y)=>{x.beginPath();x.moveTo(X-7,Y);x.lineTo(X+7,Y);x.moveTo(X,Y-7);x.lineTo(X,Y+7);x.strokeStyle=rgba(C.gold,.7);x.lineWidth=2;x.stroke();};
function potion(x,X,Y,s,c0,c1){const r=s*.30,by=Y+s*.12;
 rr(x,X-s*.09,Y-s*.36,s*.18,s*.28,2);x.fillStyle='rgba(216,204,176,0.15)';x.fill();x.lineWidth=1.5;x.strokeStyle=C.text2;x.stroke();
 x.save();circ(x,X,by,r);x.clip();x.fillStyle='rgba(216,204,176,0.10)';x.fillRect(X-r,by-r,2*r,2*r);const g=x.createLinearGradient(0,by-r*.3,0,by+r);g.addColorStop(0,c0);g.addColorStop(1,c1);x.fillStyle=g;x.fillRect(X-r,by-r*.25,2*r,2*r);x.restore();
 ring(x,X,by,r,null,C.text2,1.5);
 x.beginPath();x.arc(X-r*.1,by-r*.05,r*.6,PI*1.05,PI*1.45);x.strokeStyle='rgba(255,243,208,.75)';x.lineWidth=1.5;x.stroke();
 rr(x,X-s*.12,Y-s*.46,s*.24,s*.12,2);x.fillStyle=C.bronze;x.fill();}
function bread(x,X,Y,s){x.save();x.translate(X,Y+s*.06);x.scale(1,.58);circ(x,0,0,s*.40);x.restore();const g=x.createLinearGradient(0,Y-s*.18,0,Y+s*.28);g.addColorStop(0,'#D8B070');g.addColorStop(1,C.bronze);x.fillStyle=g;x.fill();x.lineWidth=1.5;x.strokeStyle=C.f1;x.stroke();
 [-1,0,1].forEach(k=>{x.beginPath();x.moveTo(X+k*s*.18-s*.06,Y+s*.10);x.lineTo(X+k*s*.18+s*.06,Y-s*.04);x.strokeStyle='rgba(58,44,29,.9)';x.lineWidth=2;x.stroke();});}
function drumstick(x,X,Y,s){x.beginPath();x.moveTo(X+s*.02,Y+s*.02);x.lineTo(X+s*.30,Y+s*.30);x.strokeStyle=C.text2;x.lineWidth=s*.1;x.stroke();
 ring(x,X+s*.34,Y+s*.27,s*.07,C.text2,null);ring(x,X+s*.27,Y+s*.34,s*.07,C.text2,null);
 x.save();x.translate(X-s*.08,Y-s*.08);x.rotate(PI/4);x.scale(1,.72);circ(x,0,0,s*.30);x.restore();const g=x.createLinearGradient(X-s*.3,Y-s*.3,X+s*.1,Y+s*.1);g.addColorStop(0,'#B0704A');g.addColorStop(1,'#6A3A22');x.fillStyle=g;x.fill();x.lineWidth=1.5;x.strokeStyle='#3A2C1D';x.stroke();}
function bedroll(x,X,Y,s){rr(x,X-s*.40,Y-s*.16,s*.66,s*.32,s*.16);const g=x.createLinearGradient(0,Y-s*.16,0,Y+s*.16);g.addColorStop(0,'#7E9A5A');g.addColorStop(1,'#3E5226');x.fillStyle=g;x.fill();x.lineWidth=1.5;x.strokeStyle=C.f3;x.stroke();
 x.save();x.translate(X+s*.26,Y);x.scale(.6,1);circ(x,0,0,s*.16);x.restore();x.fillStyle='#9AB476';x.fill();x.strokeStyle=C.f3;x.stroke();
 x.beginPath();x.arc(X+s*.26,Y,s*.07,0,PI*1.5);x.strokeStyle='#3E5226';x.lineWidth=1.5;x.stroke();
 [-.2,.04].forEach(k=>{x.beginPath();x.moveTo(X+k*s,Y-s*.17);x.lineTo(X+k*s,Y+s*.17);x.strokeStyle=C.bronze;x.lineWidth=2.5;x.stroke();});}
function banner(x,X,Y,s){x.beginPath();x.moveTo(X-s*.22,Y-s*.42);x.lineTo(X-s*.22,Y+s*.44);x.strokeStyle=C.gold;x.lineWidth=2;x.stroke();ring(x,X-s*.22,Y-s*.44,s*.05,C.sel,null);
 x.beginPath();x.moveTo(X-s*.22,Y-s*.34);x.lineTo(X+s*.32,Y-s*.34);x.lineTo(X+s*.32,Y+s*.20);x.lineTo(X+s*.05,Y+s*.06);x.lineTo(X-s*.22,Y+s*.20);x.closePath();
 const g=x.createLinearGradient(0,Y-s*.34,0,Y+s*.2);g.addColorStop(0,'#9A3A2C');g.addColorStop(1,'#5A1F18');x.fillStyle=g;x.fill();x.lineWidth=1.5;x.strokeStyle=C.gold;x.stroke();diamond(x,X+s*.05,Y-s*.12,s*.08,C.sel);}
function scroll(x,X,Y,s){rr(x,X-s*.26,Y-s*.22,s*.52,s*.44,2);const g=x.createLinearGradient(0,Y-s*.2,0,Y+s*.2);g.addColorStop(0,C.text2);g.addColorStop(1,C.help);x.fillStyle=g;x.fill();
 [-.08,0.02,.12].forEach(k=>{x.beginPath();x.moveTo(X-s*.16,Y+k*s);x.lineTo(X+s*.16,Y+k*s);x.strokeStyle='rgba(58,44,29,.55)';x.lineWidth=1.5;x.stroke();});
 [-.30,.30].forEach(k=>{rr(x,X-s*.33,Y+k*s-s*.06,s*.66,s*.12,s*.06);x.fillStyle=C.gray;x.fill();x.lineWidth=1.2;x.strokeStyle=C.bronze;x.stroke();});
 ring(x,X+s*.16,Y+s*.16,s*.08,C.title,'#7A5D36',1);}
function keyIcon(x,X,Y,s){ring(x,X-s*.17,Y-s*.17,s*.14,null,C.title,3);x.beginPath();x.moveTo(X-s*.07,Y-s*.07);x.lineTo(X+s*.30,Y+s*.30);x.moveTo(X+s*.14,Y+s*.14);x.lineTo(X+s*.22,Y+s*.06);x.moveTo(X+s*.24,Y+s*.24);x.lineTo(X+s*.32,Y+s*.16);x.strokeStyle=C.title;x.lineWidth=3;x.stroke();}
function bag(x,X,Y,s){x.beginPath();x.moveTo(X-s*.1,Y-s*.2);x.bezierCurveTo(X-s*.44,Y-s*.04,X-s*.38,Y+s*.38,X,Y+s*.36);x.bezierCurveTo(X+s*.38,Y+s*.38,X+s*.44,Y-s*.04,X+s*.1,Y-s*.2);x.closePath();
 const g=x.createLinearGradient(0,Y-s*.2,0,Y+s*.36);g.addColorStop(0,'#9A7444');g.addColorStop(1,'#4A3A26');x.fillStyle=g;x.fill();x.lineWidth=1.5;x.strokeStyle=C.gold;x.stroke();
 x.beginPath();x.moveTo(X-s*.12,Y-s*.34);x.lineTo(X,Y-s*.22);x.lineTo(X+s*.12,Y-s*.34);x.strokeStyle=C.bronze;x.lineWidth=2;x.stroke();
 x.beginPath();x.moveTo(X-s*.14,Y-s*.21);x.lineTo(X+s*.14,Y-s*.21);x.strokeStyle=C.title;x.lineWidth=2.5;x.stroke();}
{const [c,x]=mk(256,256);const pos=wheelBase(x,8,0);const s=30;const RED=['#FF8A6C','#8A2A1C'],BLU=[C.cyan,'#1E5A66'];
 const items=[(X,Y)=>potion(x,X,Y,s,...RED),(X,Y)=>bread(x,X,Y,s),(X,Y)=>potion(x,X,Y,s,...BLU),(X,Y)=>drumstick(x,X,Y,s),(X,Y)=>potion(x,X,Y,s,...RED),(X,Y)=>bread(x,X,Y,s),(X,Y)=>potion(x,X,Y,s,...BLU),(X,Y)=>plus(x,X,Y)];
 pos.forEach((p,i)=>items[i](p[0],p[1]));out.ck_onb_wheel_consumables=c;}
{const [c,x]=mk(256,256);const pos=wheelBase(x,6,0);const s=32;
 const items=[(X,Y)=>bedroll(x,X,Y,s),(X,Y)=>banner(x,X,Y,s),(X,Y)=>scroll(x,X,Y,s),(X,Y)=>keyIcon(x,X,Y,s),(X,Y)=>bag(x,X,Y,s),(X,Y)=>plus(x,X,Y)];
 pos.forEach((p,i)=>items[i](p[0],p[1]));out.ck_onb_wheel_usable=c;}

// ---------- PARTY WHEEL 256 ----------
{const [c,x]=mk(256,256);const cx=128,cy=132,R=28,D=80;const hp=[0.92,0.48,0.75,0.18,0.62];const tgt=3;
 halo(x,cx,cy,128,.08);
 const pos=hp.map((_,i)=>{const a=-PI/2+i*TAU/5;return [cx+Math.cos(a)*D,cy+Math.sin(a)*D];});
 x.beginPath();pos.forEach((p,i)=>i?x.lineTo(...p):x.moveTo(...p));x.closePath();x.strokeStyle=rgba(C.bronze,.6);x.lineWidth=1.5;x.stroke();
 const [tx,ty]=pos[tgt];const ta=Math.atan2(ty-cy,tx-cx);
 x.beginPath();x.moveTo(cx+Math.cos(ta)*24,cy+Math.sin(ta)*24);x.lineTo(tx-Math.cos(ta)*(R+12),ty-Math.sin(ta)*(R+12));x.strokeStyle=rgba(C.sel,.5);x.lineWidth=2;x.setLineDash([3,4]);x.stroke();x.setLineDash([]);
 pos.forEach(([px,py],i)=>{const p=hp[i];const col=p>=0.6?C.ok:p>=0.35?C.title:C.danger;
  ring(x,px,py,R,rad(x,px,py,R,'#33271b','#110c07'),null);
  x.save();circ(x,px,py,R);x.clip();x.fillStyle=rgba(C.text2,.42);circ(x,px,py-R*.2,R*.32);x.fill();x.save();x.translate(px,py+R*.66);x.scale(1,.72);circ(x,0,0,R*.62);x.restore();x.fill();x.restore();
  ring(x,px,py,R,null,C.f1,1.5);
  ring(x,px,py,R+5,null,C.f3,5);
  x.save();glow(x,col,6);x.beginPath();x.arc(px,py,R+5,-PI/2,-PI/2+TAU*p);x.strokeStyle=col;x.lineWidth=5;x.stroke();x.restore();
  if(i===tgt){x.save();x.setLineDash([5,4]);glow(x,C.sel,6);ring(x,px,py,R+12,null,C.sel,2);x.restore();}});
 ring(x,cx,cy,22,'#0f0b07',C.gold,2.5);
 x.save();glow(x,C.ok,8);rr(x,cx-11,cy-3.5,22,7,2);x.fillStyle=C.ok;x.fill();rr(x,cx-3.5,cy-11,7,22,2);x.fill();x.restore();
 x.save();x.translate(cx+Math.cos(ta)*27,cy+Math.sin(ta)*27);x.rotate(ta+PI/2);x.beginPath();x.moveTo(0,-6);x.lineTo(6,3);x.lineTo(-6,3);x.closePath();x.fillStyle=C.sel;x.fill();x.restore();
 out.ck_onb_wheel_party=c;
 meta.party=pos.map(p=>({x:Math.round(p[0]),y:Math.round(p[1])}));}

// ---------- DONE 256 ----------
{const [c,x]=mk(256,256);const cx=128,cy=128;
 halo(x,cx,cy,128,.22);
 ring(x,cx,cy,96,null,C.f1,1.5);
 for(let i=0;i<24;i++){const a=i*TAU/24;i%2?ring(x,cx+Math.cos(a)*96,cy+Math.sin(a)*96,1.8,rgba(C.gold,.6),null):diamond(x,cx+Math.cos(a)*96,cy+Math.sin(a)*96,3.5,C.gold);}
 ring(x,cx,cy,80,rad(x,cx,cy,80,'#352919','#110c07'),C.gold,3);
 ring(x,cx,cy,68,null,rgba(C.gold,.35),1.5);
 x.save();glow(x,C.sel,18);x.beginPath();x.moveTo(90,130);x.lineTo(116,156);x.lineTo(166,102);x.strokeStyle=C.sel;x.lineWidth=15;x.stroke();x.restore();
 x.beginPath();x.moveTo(90,130);x.lineTo(116,156);x.lineTo(166,102);x.strokeStyle=C.selText;x.lineWidth=5;x.stroke();
 star4(x,206,52,10,rgba(C.sel,.85));star4(x,48,204,7,rgba(C.sel,.6));star4(x,222,184,5,rgba(C.gold,.6));
 out.ck_onb_done=c;}

return {out,meta};
}
