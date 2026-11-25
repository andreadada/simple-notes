
// Rebuild a restricted DOM. Never insert untrusted HTML directly.
const tags=new Set(["P","DIV","BR","H1","H2","H3","STRONG","B","EM","I","U","S","STRIKE","UL","OL","LI","BLOCKQUOTE","PRE","CODE","TABLE","TBODY","THEAD","TFOOT","TR","TH","TD","A","HR"]);
const reject=new Set(["SCRIPT","STYLE","IFRAME","OBJECT","EMBED","SVG","MATH","TEMPLATE","IMG","VIDEO","AUDIO","LINK","META","FORM","INPUT"]);
export function cleanDocument(raw){
 const parsed=new DOMParser().parseFromString(String(raw??""),"text/html"),out=document.createElement("div");
 const copy=(node,parent)=>{if(node.nodeType===3){parent.append(document.createTextNode(node.nodeValue));return}if(node.nodeType!==1||reject.has(node.tagName))return;let target=parent;
 if(tags.has(node.tagName)){target=document.createElement(node.tagName.toLowerCase());if(node.tagName==="A"){try{const u=new URL(node.getAttribute("href")??"");if(["https:","http:","mailto:"].includes(u.protocol)){target.setAttribute("href",u.href);target.setAttribute("rel","noopener noreferrer")}}catch{}}if(["TD","TH"].includes(node.tagName))for(const key of ["colspan","rowspan"]){const n=Number(node.getAttribute(key));if(Number.isInteger(n)&&n>1&&n<=20)target.setAttribute(key,String(n))}parent.append(target)}
 for(const child of node.childNodes)copy(child,target)};
 for(const n of parsed.body.childNodes)copy(n,out);return out;
}
export function plainDocument(text){const d=document.createElement("div");if(!text)return d;for(const line of String(text).split("\n")){const p=document.createElement("p");if(line)p.textContent=line;else p.append(document.createElement("br"));d.append(p)}return d}
export function docHtml(editor){return cleanDocument(editor.innerHTML).innerHTML}
export function docText(editor){return editor.innerText??editor.textContent??""}
export function documentTable(rows=3,cols=3){const t=document.createElement("table"),body=document.createElement("tbody");for(let i=0;i<rows;i++){const row=document.createElement("tr");for(let j=0;j<cols;j++){const td=document.createElement("td");td.append(document.createElement("br"));row.append(td)}body.append(row)}t.append(body);return t.outerHTML}
