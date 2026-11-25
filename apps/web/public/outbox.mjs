
export function readIntents(storage,prefix){const q=[];for(let i=0;i<storage.length;i++){const k=storage.key(i);if(k?.startsWith(prefix)){const v=JSON.parse(storage.getItem(k));if(!v||typeof v.operationId!=="string"||k!==prefix+v.operationId)throw Error("Coda locale non valida");q.push(v)}}return q.sort((a,b)=>(a.queuedAt??0)-(b.queuedAt??0)||a.operationId.localeCompare(b.operationId))}
export function targets(op){return (op.batch??[op]).map(x=>x.entityType+":"+x.entityId)}
export function canQueue(queue,op){const keys=new Set(queue.flatMap(targets));return queue.length<100&&!targets(op).some(x=>keys.has(x))}
export function wireIntent(op){const {queuedAt,rejected,...wire}=op;return wire}
