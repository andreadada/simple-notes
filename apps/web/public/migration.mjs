import {normalizeTask,operation,resolveWall,none} from "./model.mjs";
const enc=new TextEncoder(),dec=new TextDecoder("utf-8",{fatal:true});
const fail=(s="Archivio non valido")=>{throw Error(s)};
const obj=x=>x&&typeof x==="object"&&!Array.isArray(x);
const string=(x,min,max)=>typeof x==="string"&&x.length>=min&&x.length<=max;
const date=x=>typeof x==="string"&&/^\d{4}-\d{2}-\d{2}$/.test(x)&&Number.isFinite(Date.parse(x+"T00:00:00Z"))&&new Date(x+"T00:00:00Z").toISOString().slice(0,10)===x;
const stamp=x=>typeof x==="string"&&Number.isFinite(Date.parse(x));
const unique=xs=>new Set(xs).size===xs.length;
const zone=z=>{try{new Intl.DateTimeFormat("en",{timeZone:z});return typeof z==="string"&&z.length>0}catch{return false}};
export function validatePortable(doc,max=500){
 if(!obj(doc)||doc.format!=="simple-notes-portable"||doc.schemaVersion!==1||!stamp(doc.exportedAt)||!obj(doc.data))fail();
 const {lists,tasks,notes}=doc.data;
 if(![lists,tasks,notes].every(Array.isArray)||lists.length+tasks.length+notes.length>max)fail("Massimo "+max+" record per importazione");
 for(const rows of [lists,tasks,notes])if(rows.some(x=>!obj(x)||!string(x.id,1,128)||!stamp(x.createdAt))||!unique(rows.map(x=>x.id)))fail("ID o data record non validi");
 const lids=new Set(lists.map(x=>x.id));
 for(const x of lists)if(!string(x.title,1,255)||!x.title.trim())fail("Titolo lista non valido");
 for(const x of notes)if(!string(x.title,0,255)||typeof x.body!=="string")fail("Nota non valida");
 for(const x of tasks){
  if(!string(x.title,1,1024)||!x.title.trim()||typeof x.description!=="string"||typeof x.completed!=="boolean"||x.listId!=null&&!lids.has(x.listId)||!Number.isInteger(x.priority)||x.priority<0||x.priority>3||!Array.isArray(x.tags)||x.tags.length>16||x.tags.some(t=>!string(t,1,40)||!t.trim())||!Array.isArray(x.subtasks)||x.subtasks.length>50||x.subtasks.some(s=>!obj(s)||!string(s.id,1,128)||!string(s.title,1,255)||!s.title.trim()||typeof s.completed!=="boolean")||!unique(x.subtasks.map(s=>s.id)))fail("Attività o riferimenti non validi");
  const p=normalizeTask(x),d=p.due,q=p.recurrence;
  if(!obj(d)||!["none","legacy","date","datetime"].includes(d.kind))fail("Scadenza non valida");
  if(d.kind==="date"&&!date(d.date)||d.kind==="legacy"&&!stamp(d.instant))fail("Scadenza non valida");
  if(d.kind==="datetime"){const v=date(d.date)&&zone(d.timeZone)&&resolveWall(d.date,d.time,d.timeZone,d.offsetSeconds);if(!v||v.offsetSeconds!==d.offsetSeconds||Date.parse(v.instant)!==Date.parse(d.instant))fail("Scadenza con fuso non valida")}
  if(!obj(q)||q.kind!=="none"&&(!["daily","weekly","monthly"].includes(q.kind)||!Number.isInteger(q.interval)||q.interval<1||q.interval>12||!["date","datetime"].includes(d.kind)))fail("Ricorrenza non valida");
  if(!Array.isArray(p.timeBlocks)||p.timeBlocks.length>12||p.timeBlocks.some(b=>!obj(b)||!string(b.id,1,128)||!stamp(b.start)||!stamp(b.end)||!zone(b.timeZone)||Date.parse(b.start)%60000!==0||Date.parse(b.end)%60000!==0||Date.parse(b.end)<=Date.parse(b.start)||Date.parse(b.end)-Date.parse(b.start)>86400000)||!unique(p.timeBlocks.map(b=>b.id)))fail("Blocchi non validi");
 }
 return {lists,tasks,notes};
}
export function copyOperations(doc,id=()=>crypto.randomUUID()){
 const data=validatePortable(doc),ids=new Map(),ops=[];
 for(const x of data.lists){const fresh=id();ids.set(x.id,fresh);ops.push(operation("list",fresh,null,{title:x.title,createdAt:x.createdAt},"upsert",id()))}
 for(const x of data.tasks){const {id:old,...p}=normalizeTask(x);ops.push(operation("task",id(),null,{...p,listId:x.listId==null?null:ids.get(x.listId),subtasks:p.subtasks.map(s=>({...s,id:id()})),timeBlocks:p.timeBlocks.map(s=>({...s,id:id()}))},"upsert",id()))}
 for(const x of data.notes)ops.push(operation("note",id(),null,{title:x.title,body:x.body,createdAt:x.createdAt},"upsert",id()));
 return ops;
}
const b64=a=>{let s="";for(let i=0;i<a.length;i+=8192)s+=String.fromCharCode(...a.subarray(i,i+8192));return btoa(s)};
const bytes=s=>Uint8Array.from(atob(s),c=>c.charCodeAt(0));
async function key(password,salt,iterations){const base=await crypto.subtle.importKey("raw",enc.encode(password),"PBKDF2",false,["deriveKey"]);return crypto.subtle.deriveKey({name:"PBKDF2",salt,iterations,hash:"SHA-256"},base,{name:"AES-GCM",length:256},false,["encrypt","decrypt"])}
export async function encryptBackup(snapshot,password){
 if(password.trim().length<12||password.length>256)fail("Password: minimo 12 caratteri");
 const plain=enc.encode(JSON.stringify(snapshot));if(plain.length>16*1024*1024)fail("Backup troppo grande");
 const salt=crypto.getRandomValues(new Uint8Array(16)),nonce=crypto.getRandomValues(new Uint8Array(12)),iterations=600000,format="simple-notes-web-backup",aad=enc.encode(format+"/v1");
 const out=new Uint8Array(await crypto.subtle.encrypt({name:"AES-GCM",iv:nonce,additionalData:aad,tagLength:128},await key(password,salt,iterations),plain));
 return JSON.stringify({format,schema:1,cipher:"AES-256-GCM",kdf:"PBKDF2-HMAC-SHA256",iterations,salt:b64(salt),nonce:b64(nonce),ciphertext:b64(out.slice(0,-16)),tag:b64(out.slice(-16))});
}
export async function inspectBackup(text,password,owner){
 try{
  if(enc.encode(text).length>25*1024*1024||!owner||!password||password.length>256)fail();
  const x=JSON.parse(text),native=x.format==="simple-notes-full-backup",format=native?"simple-notes-full-backup":"simple-notes-web-backup";
  if(x.format!==format||x.schema!==1||x.cipher!=="AES-256-GCM"||x.kdf!=="PBKDF2-HMAC-SHA256"||x.iterations!==(native?180000:600000))fail();
  const salt=bytes(x.salt),nonce=bytes(x.nonce),tag=bytes(x.tag),cipher=bytes(x.ciphertext);
  if(salt.length!==16||nonce.length!==12||tag.length!==16||!cipher.length||cipher.length>16*1024*1024)fail();
  const joined=new Uint8Array(cipher.length+16);joined.set(cipher);joined.set(tag,cipher.length);
  const plain=await crypto.subtle.decrypt({name:"AES-GCM",iv:nonce,additionalData:enc.encode(format+"/v1"),tagLength:128},await key(password,salt,x.iterations),joined);
  const value=JSON.parse(dec.decode(plain));if(value.ownerId!==owner||value.format!==format||value.schema!==1)fail();
  if(native){
   if(value.sqliteSchema!==8||!obj(value.tables)||!obj(value.preferences)||!["task_entries","task_list_entries","note_entries","pending_mutations","sync_settings"].every(k=>Array.isArray(value.tables[k]))||value.tables.sync_settings.filter(x=>x.key==="boundOwnerId"&&x.value===owner).length!==1)fail();
   return {native:true,value};
  }
  validatePortable(value.portable,10000);
  return {native:false,value};
 }catch{fail("Password errata, backup non valido o account differente. Nessun dato modificato.")}
}

const sqlStamp=x=>{if(!Number.isSafeInteger(x)||Math.abs(x)>8640000000000)fail("Timestamp SQLite non valido");return new Date(x*1000).toISOString()};
function rawDue(x){
 if(x.due_kind==="none")return none();
 if(x.due_kind==="date")return {kind:"date",date:x.due_date};
 if(x.due_kind==="legacy")return {kind:"legacy",instant:sqlStamp(x.due_at)};
 if(x.due_kind==="datetime")return {kind:"datetime",date:x.due_date,time:x.due_time,timeZone:x.due_timezone,offsetSeconds:x.due_offset_seconds,instant:sqlStamp(x.due_at)};
 fail("Scadenza SQLite non valida");
}
export function nativePortable(snapshot){
 const t=snapshot.tables;
 const active=xs=>xs.filter(x=>x.deleted_at===null);
 const lists=active(t.task_list_entries).map(x=>({id:x.id,title:x.title,createdAt:sqlStamp(x.created_at)}));
 const notes=active(t.note_entries).map(x=>({id:x.id,title:x.title,body:x.body,createdAt:sqlStamp(x.created_at)}));
 const tasks=active(t.task_entries).map(x=>{
   const due=rawDue(x),slots=JSON.parse(x.blocks_json);
   if(!Array.isArray(slots))fail("Blocchi SQLite non validi");
   const timeBlocks=slots.length?slots:x.block_start_at===null?[]:[{id:"legacy",start:sqlStamp(x.block_start_at),end:sqlStamp(x.block_end_at),timeZone:x.block_timezone}];
   if(![0,1,true,false].includes(x.completed))fail("Stato SQLite non valido");
   return {id:x.id,title:x.title,description:x.description,createdAt:sqlStamp(x.created_at),completed:!!x.completed,listId:x.list_id,priority:x.priority,tags:JSON.parse(x.tags_json),subtasks:JSON.parse(x.subtasks_json),due,dueAt:due.instant??null,timeBlocks,recurrence:JSON.parse(x.recurrence_json)};
 });
 const doc={format:"simple-notes-portable",schemaVersion:1,exportedAt:snapshot.createdAtUtc,data:{lists,tasks,notes}};validatePortable(doc,10000);return doc;
}
export function nativePreferences(snapshot){
 const p=snapshot.preferences,result={};
 const read=k=>{if(p[k]==null)return null;const v=JSON.parse(p[k]);if(v.schema!==1)fail("Preferenza nativa non supportata: "+k);return v};
 if(["light","dark","system"].includes(p.theme))result.theme=p.theme;
 const habits=read("habits");if(habits){if(!Array.isArray(habits.habits)||habits.habits.length>200)fail();result.habits=habits.habits.map(h=>{if(!string(h.id,1,128)||!string(h.title,1,255)||!date(h.createdDay)||typeof h.archived!=="boolean"||!Array.isArray(h.checkIns)||!h.checkIns.every(date)||!unique(h.checkIns)||!Number.isInteger(h.weeklyTarget??7)||(h.weeklyTarget??7)<1||(h.weeklyTarget??7)>7)fail();return {id:h.id,name:h.title,createdDay:h.createdDay,archived:h.archived,weeklyTarget:h.weeklyTarget??7,days:h.checkIns}})}
 const countdowns=read("countdowns");if(countdowns){if(!Array.isArray(countdowns.events)||countdowns.events.length>250)fail();result.countdowns=countdowns.events.map(c=>{if(!string(c.id,1,128)||!string(c.title,1,255)||typeof c.archived!=="boolean"||!obj(c.due))fail();const day=c.due.date??c.due.instant?.slice(0,10);if(!date(day))fail();return {id:c.id,title:c.title,date:day,due:c.due,archived:c.archived}})}
 const pom=read("pomodoro");if(pom){if(!Array.isArray(pom.records)||pom.records.some(x=>!string(x.id,1,128)||!stamp(x.completedAtUtc)||!Number.isInteger(x.seconds)||x.seconds<1||x.seconds>86400))fail();result.focusRecords=pom.records;result.focusCompleted=pom.focusCompleted}
 return result;
}

export function archiveCatalogs(snapshot,native){
 const read=(key,field)=>{const raw=native?snapshot.preferences?.[key]:snapshot.catalogs?.[key];if(raw==null)return null;const data=typeof raw==="string"?JSON.parse(raw):raw;if(!obj(data)||data.schema!==1||!Array.isArray(data[field])||data[field].length>100||data[field].some(x=>!obj(x)||!string(x.id,1,128))||!unique(data[field].map(x=>x.id)))fail("Catalogo non valido: "+key);return data};
 return {templates:read("templates","templates"),taskActions:read("taskActions","rules"),reminders:native?read("automations","rules"):read("reminders","rules")};
}
export function mergeCatalog(current,incoming,field,max){
 const existing=current[field],newItems=incoming[field],ids=new Map(existing.map(x=>[x.id,x])),conflicts=[];
 for(const x of newItems){const previous=ids.get(x.id);if(previous){if(JSON.stringify(previous)!==JSON.stringify(x))conflicts.push(x.id)}else ids.set(x.id,x)}
 if(ids.size>max)fail("Catalogo oltre il limite: seleziona manualmente");
 return {catalog:{schema:1,[field]:[...ids.values()]},added:ids.size-existing.length,conflicts};
}

const uuid=x=>typeof x==="string"&&/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(x);
export function recoveryPlan(doc,rows,id=()=>crypto.randomUUID()){
 const data=validatePortable(doc,10000),known=new Map(rows.map(r=>[r.entityType+":"+r.entityId,r])),availableLists=new Set(rows.filter(r=>r.entityType==="list"&&!r.deleted).map(r=>r.entityId)),operations=[],skipped={present:0,tombstone:0,invalid:0,missingList:0};
 for(const [type,items] of [["list",data.lists],["task",data.tasks],["note",data.notes]])for(const x of items){
  if(!uuid(x.id)){skipped.invalid++;continue}
  const current=known.get(type+":"+x.id);if(current){skipped[current.deleted?"tombstone":"present"]++;continue}
  if(type==="task"&&x.listId&&!availableLists.has(x.listId)){skipped.missingList++;continue}
  let payload=type==="task"?normalizeTask(x):type==="list"?{title:x.title,createdAt:x.createdAt}:{title:x.title,body:x.body,createdAt:x.createdAt};
  if(type==="task"&&payload.subtasks.some(s=>!uuid(s.id))){skipped.invalid++;continue}
  if(type==="task"&&payload.timeBlocks.some(s=>s.id!=="legacy"&&!uuid(s.id))){skipped.invalid++;continue}
  delete payload.id;
  operations.push(operation(type,x.id,null,payload,"upsert",id()));if(type==="list")availableLists.add(x.id);
 }
 return {operations,skipped};
}
