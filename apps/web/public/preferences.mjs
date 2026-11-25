
export const domains=["theme","views","customViews","viewOptions","dashboards","habits","countdowns","gridColumns","customFields","automationEnabled"];
export const defaults={theme:"light",views:{},customViews:{},viewOptions:{},dashboards:{},habits:[],countdowns:[],gridColumns:{},customFields:[],automationEnabled:false};
const plain=x=>x!==null&&typeof x==="object"&&!Array.isArray(x);
const str=x=>typeof x==="string";
const types=["grid","gallery","kanban","calendar","dashboard","matrix"];
export function validPreference(k,x){
 if(k==="automationEnabled")return typeof x==="boolean";
 if(k==="customFields")return Array.isArray(x)&&x.length<=40&&x.every(f=>plain(f)&&/^field-[a-f0-9-]{36}$/.test(f.id)&&str(f.name)&&f.name.length>0&&f.name.length<=60&&["text","number","checkbox","date","select"].includes(f.type)&&Array.isArray(f.options)&&f.options.length<=30&&f.options.every(v=>str(v)&&v.length<=80));
 if(k==="gridColumns")return plain(x)&&Object.values(x).every(a=>Array.isArray(a)&&a.length<=60&&a.every(c=>plain(c)&&str(c.id)&&Number.isInteger(c.width)&&c.width>=64&&c.width<=600&&typeof c.hidden==="boolean"));
 if(k==="theme")return ["light","dark","system"].includes(x);
 if(k==="views")return plain(x)&&Object.values(x).every(str);
 if(k==="customViews")return plain(x)&&Object.values(x).every(a=>Array.isArray(a)&&a.every(t=>plain(t)&&str(t.id)&&str(t.name)&&types.includes(t.type)&&t.custom===true));
 if(k==="viewOptions")return plain(x)&&Object.values(x).every(t=>plain(t)&&["all","open","done","today"].includes(t.filter)&&["title","due","priority"].includes(t.sort)&&["none","list","priority"].includes(t.group));
 if(k==="dashboards")return plain(x)&&Object.values(x).every(a=>Array.isArray(a)&&a.every(t=>plain(t)&&str(t.id)&&Number.isInteger(t.width)&&t.width>=3&&t.width<=12));
 if(k==="habits")return Array.isArray(x)&&x.every(h=>plain(h)&&str(h.id)&&str(h.name)&&Array.isArray(h.days)&&h.days.every(str));
 if(k==="countdowns")return Array.isArray(x)&&x.every(h=>plain(h)&&str(h.id)&&str(h.title)&&/^\d{4}-\d{2}-\d{2}$/.test(h.date));
 return false;
}
function canonical(x){if(Array.isArray(x))return x.map(canonical);if(plain(x))return Object.fromEntries(Object.keys(x).sort().map(k=>[k,canonical(x[k])]));return x}
export const same=(a,b)=>JSON.stringify(canonical(a))===JSON.stringify(canonical(b));
export function planPreference(local,base,remote){
 const value=remote?.value,version=remote?.version??0;
 if(!base){if(remote&&local===undefined)return "pull";if(remote&&same(local,value))return "agree";if(remote)return "conflict";return local===undefined?"skip":"push"}
 const edited=!same(local,base.value),changed=version!==base.version;
 if(!edited&&!changed)return "skip";
 if(changed&&same(local,value))return "agree";
 if(edited&&changed)return "conflict";
 return edited?"push":"pull";
}
