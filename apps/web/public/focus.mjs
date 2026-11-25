
export function timerState(x){return x&&typeof x==="object"?x:{mode:"focus",remaining:1500,deadline:null,id:null}}
export function remaining(t,now=Date.now()){return t.deadline===null?t.remaining:Math.max(0,Math.ceil((t.deadline-now)/1000))}
export function settleTimer(t,records,now=Date.now()){
 if(t.deadline===null||remaining(t,now)>0)return {timer:t,records,changed:false};
 const next=t.mode==="focus"&&t.id&&!records.some(x=>x.id===t.id)?[...records,{id:t.id,completedAtUtc:new Date(t.deadline).toISOString(),seconds:1500}]:records;
 return {timer:{...t,deadline:null,remaining:0,id:null},records:next,changed:true};
}
export function habitWeek(h,today){const d=new Date(today+"T00:00:00Z"),m=new Date(+d-((d.getUTCDay()+6)%7)*86400000).toISOString().slice(0,10);return h.days.filter(x=>x>=m&&x<=today).length}
export function habitStreak(h,today){const s=new Set(h.days);let d=Date.parse(today+"T00:00:00Z"),n=0;if(!s.has(new Date(d).toISOString().slice(0,10)))d-=86400000;while(s.has(new Date(d).toISOString().slice(0,10))){n++;d-=86400000}return n}
