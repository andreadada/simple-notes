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
  if(p.due.kind!=="date")throw Error("Ricorrenza con ora: avanzamento non ancora disponibile sul web.");
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
