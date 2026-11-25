
export const standardColumns=[{id:"done",name:"Stato",width:85},{id:"title",name:"Titolo",width:300},{id:"list",name:"Lista",width:150},{id:"due",name:"Scadenza",width:170},{id:"priority",name:"Priorità",width:130},{id:"tags",name:"Tag",width:200},{id:"description",name:"Descrizione",width:260}];
export function columnsFor(fields=[],saved=[]){
 const defs=[...standardColumns,...fields.map(f=>({...f,width:170}))],by=new Map(defs.map(c=>[c.id,c])),result=[];
 for(const p of saved){const d=by.get(p.id);if(d){result.push({...d,width:Math.min(600,Math.max(64,p.width||d.width)),hidden:p.id==="title"?false:!!p.hidden});by.delete(p.id)}}
 for(const d of by.values())result.push({...d,hidden:d.id==="description"});
 return result;
}
export function fieldValue(f,value){
 if(f.type==="checkbox")return !!value;
 if(value==="")return null;
 if(f.type==="number"){const n=Number(value);if(!Number.isFinite(n))throw Error("Numero non valido");return n}
 if(f.type==="date"&&(!/^\d{4}-\d{2}-\d{2}$/.test(value)||!Number.isFinite(Date.parse(value))))throw Error("Data non valida");
 if(f.type==="select"&&!f.options.includes(value))throw Error("Opzione non valida");
 if(typeof value!=="string"||value.length>1024)throw Error("Valore non valido");return value;
}

export function validAdvanced(c){return c&&["all","any"].includes(c.logic)&&Array.isArray(c.rules)&&c.rules.length<=10&&c.rules.every(r=>r&&typeof r.field==="string"&&r.field.length<=80&&["contains","equals","empty","gt","lt"].includes(r.op)&&typeof r.value==="string"&&r.value.length<=1024)&&c.order&&typeof c.order.field==="string"&&c.order.field.length<=80&&["asc","desc"].includes(c.order.direction)}
export function gridValue(p,id){if(id==="done")return !!p.completed;if(id==="list")return p.listId??"";if(id==="due")return p.due?.date??(p.dueAt??"").slice(0,10);if(id==="tags")return (p.tags??[]).join(", ");return id.startsWith("field-")?p.customFields?.[id]:p[id]}
export function advancedMatch(p,c){if(!validAdvanced(c)||!c.rules.length)return true;const test=r=>{const x=gridValue(p,r.field),v=String(x??"").toLowerCase(),y=r.value.toLowerCase();if(r.op==="empty")return x==null||x==="";if(r.op==="contains")return v.includes(y);if(r.op==="equals")return v===y;if(typeof x==="number"&&r.value.trim()!==""&&Number.isFinite(Number(r.value)))return r.op==="gt"?x>Number(r.value):x<Number(r.value);if(typeof x==="string"&&/^\d{4}-\d{2}-\d{2}$/.test(x)&&/^\d{4}-\d{2}-\d{2}$/.test(r.value))return r.op==="gt"?x>r.value:x<r.value;return false};return c.logic==="all"?c.rules.every(test):c.rules.some(test)}
export function advancedCompare(a,b,c){if(!validAdvanced(c)||!c.order.field)return 0;const x=gridValue(a,c.order.field),y=gridValue(b,c.order.field);if(x==null||x==="")return y==null||y===""?0:1;if(y==null||y==="")return -1;const n=typeof x==="number"&&typeof y==="number"?x-y:String(x).localeCompare(String(y),"it",{numeric:true});return c.order.direction==="desc"?-n:n}
