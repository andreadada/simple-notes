
import test from "node:test";import assert from "node:assert/strict";import {settleTimer,habitWeek,habitStreak} from "../public/focus.mjs";
test("focus completion credited once",()=>{const t={mode:"focus",remaining:1500,deadline:1000,id:"x"};const a=settleTimer(t,[],2000);assert.equal(a.records.length,1);assert.equal(settleTimer(t,a.records,2000).records.length,1);assert.equal(settleTimer(a.timer,a.records,2000).changed,false)});
test("civil weekly count and streak",()=>{const h={days:["2026-11-22","2026-11-23","2026-11-24"]};assert.equal(habitWeek(h,"2026-11-25"),2);assert.equal(habitStreak(h,"2026-11-25"),3)});
