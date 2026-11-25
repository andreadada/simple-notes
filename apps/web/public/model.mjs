export const none = () => ({kind:"none"});
export function normalizeTask(p) {
  const due = p.due ?? (p.dueAt ? {kind:"legacy",instant:p.dueAt} : none());
  const blocks = p.timeBlocks ?? (p.timeBlock?.kind==="range" ? [{id:"legacy",start:p.timeBlock.start,end:p.timeBlock.end,timeZone:p.timeBlock.timeZone}] : []);
  const {timeBlock,...rest}=p;
  return {...rest,due,dueAt:due.instant??"",timeBlocks:blocks,recurrence:p.recurrence??none(),listId:p.listId??null,priority:p.priority??0,tags:p.tags??[],subtasks:p.subtasks??[],description:p.description??"",completed:!!p.completed};
}
export function dayOf(p) { return p.due?.date ?? (p.due?.instant??p.dueAt??"").slice(0,10); }
export function nextCivil(date,rule) {
  const [y,m,d]=date.split("-").map(Number);
  const n=rule.interval;
  const t=new Date(Date.UTC(y,m-1,d));
  if(rule.kind==="monthly"){
    t.setUTCDate(1);t.setUTCMonth(t.getUTCMonth()+n);
    const last=new Date(Date.UTC(t.getUTCFullYear(),t.getUTCMonth()+1,0)).getUTCDate();
    t.setUTCDate(Math.min(d,last));
  }else if(rule.kind==="daily"||rule.kind==="weekly")t.setUTCDate(d+n*(rule.kind==="weekly"?7:1));
  else throw Error("Ricorrenza non valida");
  return t.toISOString().slice(0,10);
}
export function completeTask(p) {
  p=normalizeTask(p);
  if(p.completed||p.recurrence.kind==="none")return {...p,completed:!p.completed};
  if(p.due.kind==="datetime"){const due=advanceTimed(p.due,p.recurrence);return {...p,completed:false,due,dueAt:due.instant}}
  if(p.due.kind!=="date")throw Error("Ricorrenza senza scadenza valida");
  return {...p,completed:false,due:{kind:"date",date:nextCivil(p.due.date,p.recurrence)},dueAt:""};
}
export function mergeChange(map,c) {
  const key=c.entityType+":"+c.entityId;
  const old=map.get(key);
  if(!old||c.changeId>old.changeId)map.set(key,{...c,previous:c.deleted?(old?.previous??old?.payload):undefined});
}
export function operation(type,id,version,payload,action="upsert",operationId=crypto.randomUUID()) {
  return {operationId,entityId:id,entityType:type,action,expectedVersion:version,payload:action==="upsert"?(type==="task"?normalizeTask(payload):payload):null};
}
export function civilToday(){const d=new Date();return [d.getFullYear(),String(d.getMonth()+1).padStart(2,"0"),String(d.getDate()).padStart(2,"0")].join("-");}

export function wallParts(instant,zone) {
  const f=new Intl.DateTimeFormat("en-CA",{timeZone:zone,year:"numeric",month:"2-digit",day:"2-digit",hour:"2-digit",minute:"2-digit",second:"2-digit",hourCycle:"h23"});
  const p=Object.fromEntries(f.formatToParts(new Date(instant)).map(x=>[x.type,x.value]));
  return {date:p.year+"-"+p.month+"-"+p.day,time:p.hour+":"+p.minute,second:p.second};
}
export function resolveWall(date,time,zone,preferredOffset) {
  if(!/^\d{4}-\d{2}-\d{2}$/.test(date)||!/^\d{2}:\d{2}$/.test(time))throw Error("Data o ora non valida");
  const wall=Date.parse(date+"T"+time+":00Z");
  if(!Number.isFinite(wall))throw Error("Data o ora non valida");
  const offsets=new Set();
  for(let h=-36;h<=36;h+=6){
    const at=wall+h*3600000,p=wallParts(at,zone);
    offsets.add((Date.parse(p.date+"T"+p.time+":"+p.second+"Z")-at)/1000);
  }
  const options=[...offsets].map(offsetSeconds=>({offsetSeconds,instant:new Date(wall-offsetSeconds*1000).toISOString()})).filter(x=>{const p=wallParts(x.instant,zone);return p.date===date&&p.time===time&&p.second==="00"}).sort((a,b)=>Date.parse(a.instant)-Date.parse(b.instant));
  if(!options.length)return null;
  const selected=options.find(x=>x.offsetSeconds===preferredOffset)??options[0];
  return {kind:"datetime",date,time,timeZone:zone,...selected};
}
export function advanceTimed(due,rule) {
  let date=due.date;
  for(let i=0;i<400;i++){
    date=nextCivil(date,rule);
    const next=resolveWall(date,due.time,due.timeZone,due.offsetSeconds);
    if(next)return next;
  }
  throw Error("Nessuna occorrenza valida");
}
export function blockDay(block) {
  try{return wallParts(block.start,block.timeZone).date}catch{return block.start?.slice(0,10)??""}
}

export function applyTaskActions(p,rules,trigger,listIds) {
  let result=normalizeTask(p);
  for(const rule of rules??[]){
    if(!rule.enabled||rule.trigger!==trigger||!result.title.toLowerCase().includes(rule.titleContains.toLowerCase()))continue;
    if(rule.action==="priority"&&["0","1","2","3"].includes(rule.value))result={...result,priority:Number(rule.value)};
    if(rule.action==="tag"&&rule.value.length<=40&&result.tags.length<16&&!result.tags.some(t=>t.toLowerCase()===rule.value.toLowerCase()))result={...result,tags:[...result.tags,rule.value]};
    if(rule.action==="list"&&listIds.includes(rule.value))result={...result,listId:rule.value};
  }
  return result;
}
export function urgent(p,now=new Date()){
  const due=normalizeTask(p).due;
  if(due.kind==="none")return false;
  if(due.kind==="date"){
    const tomorrow=new Date(now.getFullYear(),now.getMonth(),now.getDate()+1);
    const day=[tomorrow.getFullYear(),String(tomorrow.getMonth()+1).padStart(2,"0"),String(tomorrow.getDate()).padStart(2,"0")].join("-");
    return due.date<=day;
  }
  return Date.parse(due.instant)<=now.getTime()+48*3600000;
}
export function portableRecords(rows,now=new Date().toISOString(),allowBlankNotes=false){
  const data={lists:[],tasks:[],notes:[]};
  for(const r of rows.filter(x=>!x.deleted)){
    const p=r.payload,id=r.entityId;
    if(r.entityType==="list")data.lists.push({id,title:p.title,createdAt:p.createdAt});
    if(r.entityType==="note")data.notes.push({id,title:p.title,body:p.body,createdAt:p.createdAt,...(typeof p.documentHtml==="string"?{documentHtml:p.documentHtml}:{})});
    if(r.entityType==="task"){const t=normalizeTask(p);data.tasks.push({...t,id,dueAt:t.due.instant??null,timeBlock:t.timeBlocks.length?{kind:"range",start:t.timeBlocks[0].start,end:t.timeBlocks[0].end,timeZone:t.timeBlocks[0].timeZone}:none()})}
  }
  if(!allowBlankNotes&&data.notes.some(n=>!n.title.trim()))throw Error("Il vecchio formato portabile richiede titoli non vuoti: rinomina le note senza titolo o usa lo snapshot JSON.");
  return {format:"simple-notes-portable",schemaVersion:1,exportedAt:now,data};
}

export function moveBlock(block,date,time){
 const original=wallParts(block.start,block.timeZone);
 const previousOffset=(Date.parse(original.date+"T"+original.time+":00Z")-Date.parse(block.start))/1000;
 const target=resolveWall(date,time,block.timeZone,previousOffset);
 if(!target)throw Error("Ora inesistente per il cambio di ora legale");
 const duration=Date.parse(block.end)-Date.parse(block.start);
 if(duration<=0||duration>86400000)throw Error("Durata blocco non valida");
 return {...block,start:target.instant,end:new Date(Date.parse(target.instant)+duration).toISOString()};
}
export function resizeBlock(block,minutes){
 const duration=Date.parse(block.end)-Date.parse(block.start)+minutes*60000;
 if(duration<60000||duration>86400000)throw Error("Durata blocco da 1 minuto a 24 ore");
 return {...block,end:new Date(Date.parse(block.start)+duration).toISOString()};
}
