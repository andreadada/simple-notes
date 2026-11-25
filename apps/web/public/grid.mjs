
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
