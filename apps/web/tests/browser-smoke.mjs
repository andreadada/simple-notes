
import {chromium} from "playwright";
import assert from "node:assert/strict";
const browser=await chromium.launch({headless:true});
try{
 const page=await browser.newPage({viewport:{width:1280,height:900}});
 const errors=[];page.on("pageerror",e=>errors.push(e.message));
 const changes=[];let changeId=0;
 const capabilities=Object.fromEntries(["taskDueSchema","timeBlockSchema","timeBlocksSchema","recurrenceSchema","noteRestoreSchema","syncOperationFingerprintSchema","sharingReadSchema","sharingEditorSchema","calendarReadSchema","serverReminderSchema"].map(k=>[k,1]));
 await page.route("https://accounts.google.com/gsi/client",r=>r.fulfill({contentType:"application/javascript",body:'window.google={accounts:{id:{initialize(o){this.cb=o.callback},renderButton(el){const b=document.createElement("button");b.textContent="Test login";b.onclick=()=>this.cb({credential:"synthetic"});el.append(b)}}}};'}));
 await page.route("**/api/v1/**",async route=>{
  const req=route.request(),url=new URL(req.url()),p=url.pathname.slice("/api/v1".length);
  const json=(body,status=200)=>route.fulfill({status,contentType:"application/json",body:JSON.stringify(body)});
  if(p==="/auth/google")return json({userId:"test-account",displayName:"CI",accessToken:"test",refreshToken:"test-refresh"});
  if(p==="/capabilities")return json(capabilities);
  if(p==="/sync/changes"){const cursor=Number(url.searchParams.get("cursor"));return json({changes:changes.filter(c=>c.changeId>cursor),nextCursor:changeId,hasMore:false})}
  if(p==="/sync/apply"){const op=req.postDataJSON();const old=changes.filter(c=>c.entityId===op.entityId).at(-1);assert.equal(op.expectedVersion,old?.version??null);const v=(old?.version??-1)+1;const payload=op.action==="delete"?{}:op.action==="restore"?changes.filter(c=>c.entityId===op.entityId&&!c.deleted).at(-1).payload:op.payload;changes.push({changeId:++changeId,entityId:op.entityId,entityType:op.entityType,version:v,deleted:op.action==="delete",payload});return json({operationId:op.operationId,version:v,changeId})}
  if(p==="/templates/catalog")return json({version:0,catalog:{schema:1,templates:[]}});
  return json({},404);
 });
 await page.goto(process.env.WEB_URL||"http://127.0.0.1:8099/");
 await page.getByRole("button",{name:"Test login"}).click();
 await page.getByRole("button",{name:"Attività",exact:true}).click();
 await page.getByRole("button",{name:"+ Attività",exact:true}).click();
 await page.getByLabel("Titolo",{exact:true}).fill("Attività CI");
 await page.getByRole("button",{name:"Salva",exact:true}).click();
 await page.getByRole("textbox",{name:"Titolo attività"}).waitFor();
 assert.equal(await page.getByRole("textbox",{name:"Titolo attività"}).inputValue(),"Attività CI");
 await page.getByRole("button",{name:"Nuova vista",exact:true}).click();
 await page.getByLabel("Nome vista").fill("Vista CI");
 await page.getByLabel("Tipo di vista").selectOption("gallery");
 await page.getByRole("button",{name:"Salva",exact:true}).click();
 await page.getByRole("button",{name:"Vista CI",exact:true}).waitFor();
 await page.getByRole("button",{name:"Note",exact:true}).click();
 await page.getByRole("button",{name:"+ Nota",exact:true}).click();
 await page.getByLabel("Titolo",{exact:true}).fill("Nota CI");
 await page.getByLabel("Nota",{exact:true}).fill("Corpo");
 await page.getByRole("button",{name:"Salva",exact:true}).click();
 await page.getByRole("textbox",{name:"Titolo nota"}).waitFor();
 page.once("dialog",d=>d.accept());
 await page.locator("#content").getByRole("button",{name:"Cestino",exact:true}).click();
 await page.locator("#nav").getByRole("button",{name:"Cestino",exact:true}).click();
 await page.getByRole("button",{name:"Ripristina",exact:true}).click();
 await page.getByText("Cestino vuoto",{exact:true}).waitFor();
 await page.setViewportSize({width:390,height:844});
 await page.getByRole("button",{name:"Menu",exact:true}).click();
 await page.getByRole("button",{name:"Chiudi navigazione"}).waitFor({state:"visible"});
 await page.locator("#sidebar-scrim").click({position:{x:370,y:100}});
 assert.equal(await page.locator("#sidebar-scrim").isVisible(),false);
 assert.equal(await page.locator('link[rel="manifest"]').count(),0);
 assert.deepEqual(errors,[]);
 console.log("Browser smoke OK");
}finally{await browser.close()}
