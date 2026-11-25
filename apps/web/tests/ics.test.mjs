
import test from "node:test";
import assert from "node:assert/strict";
import {parseIcs,projectIcs} from "../public/ics.mjs";
const doc=body=>"BEGIN:VCALENDAR\nVERSION:2.0\n"+body+"\nEND:VCALENDAR";
const evt=(uid,start,end,extra="")=>"BEGIN:VEVENT\nUID:"+uid+"\nSUMMARY:Test "+uid+"\n"+start+"\n"+end+"\n"+extra+"\nEND:VEVENT";
test("all-day exclusive end",()=>{const c=parseIcs(doc(evt("a","DTSTART;VALUE=DATE:20261125","DTEND;VALUE=DATE:20261127")));const rows=projectIcs([{label:"Test",calendar:c}],"2026-11-25","2026-11-27","Europe/Rome");assert.equal(rows.length,1);assert.equal(rows[0].from,"2026-11-25");assert.equal(rows[0].to,"2026-11-26")});
test("weekly count, exceptions and overrides",()=>{const c=parseIcs(doc(evt("a","DTSTART;VALUE=DATE:20261123","DTEND;VALUE=DATE:20261124","RRULE:FREQ=WEEKLY;BYDAY=MO,WE;COUNT=4\nEXDATE;VALUE=DATE:20261125")+"\n"+evt("a","DTSTART;VALUE=DATE:20261202","DTEND;VALUE=DATE:20261203","RECURRENCE-ID;VALUE=DATE:20261130")));const rows=projectIcs([{label:"Test",calendar:c}],"2026-11-23","2026-12-03","Europe/Rome");assert.deepEqual(rows.map(x=>x.from),["2026-11-23","2026-12-02","2026-12-02"])});
test("timed recurring wall time skips gap",()=>{const c=parseIcs(doc(evt("a","DTSTART;TZID=Europe/Rome:20260328T023000","DTEND;TZID=Europe/Rome:20260328T033000","RRULE:FREQ=DAILY;COUNT=3")));const rows=projectIcs([{label:"Test",calendar:c}],"2026-03-28","2026-04-02","Europe/Rome");assert.deepEqual(rows.map(x=>x.from),["2026-03-28","2026-03-30","2026-03-31"]);assert.ok(rows.every(x=>x.time==="02:30"))});
test("unsupported rules fail closed",()=>assert.throws(()=>parseIcs(doc(evt("a","DTSTART;VALUE=DATE:20261125","DTEND;VALUE=DATE:20261126","RRULE:FREQ=MONTHLY;BYSETPOS=-1")))));
