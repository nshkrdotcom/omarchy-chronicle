const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const context = vm.createContext({});
vm.runInContext(fs.readFileSync('qml/Timeline.js', 'utf8'), context);
const M = context;
const event = (id, time, severity = 'info') => ({id, time_us: time, severity, category: 'service', unit: 'worker', message: 'example'});

test('filter combines literal text, category, severity and time', () => {
    const rows = [event('a', 10), event('b', 20, 'error')];
    assert.equal(M.filter(rows, {search:'WORK', severity:'error', from:0, to:30}).length, 1);
    assert.equal(M.filter(rows, {search:'%'}).length, 0);
    assert.equal(M.filter(rows, {category:'audio'}).length, 0);
    assert.equal(M.filter(rows, {from:11,to:20})[0].id, 'b');
});
test('selection is exact identity, never silently another row', () => {
    assert.equal(M.selected([event('a', 10)], 'gone'), null);
    assert.equal(M.selected([event('a', 10)], 'a').id, 'a');
});
test('time projection clamps edges and rejects invalid span', () => {
    assert.equal(M.position(15, 10, 20, 100), 50);
    assert.equal(M.position(30, 10, 20, 100), 100);
    assert.equal(M.position(15, 10, 10, 100), null);
});
test('buckets count actual observations and errors independently', () => {
    const buckets = M.buckets([event('a',10,'warning'),event('b',20,'error'),event('c',20,'error')],0,100,10);
    assert.equal(buckets[2].count,2);
    assert.equal(buckets[2].errors,2);
    assert.equal(buckets[0].count,0);
    assert.equal(buckets[1].warnings,1);
});
test('nearest event selection never crosses outside the view', () => {
    assert.equal(M.nearest([event('a',10),event('b',90)],85,20,100).id,'b');
    assert.equal(M.nearest([event('a',10)],85,20,100),null);
});
test('resource lines break for missing samples and clock reversals', () => {
    const samples = [
        {time_us:1,values:{x:0}}, {time_us:2,values:{x:2}},
        {time_us:3,values:{x:null}}, {time_us:4,values:{x:4}},
        {time_us:20_000_000,values:{x:5}}, {time_us:5,values:{x:6}}
    ];
    assert.equal(M.segments(samples,'x').length,4);
    assert.equal(M.segments(samples,'x')[0][0].value,0);
});
test('missing sources and stale snapshots are not healthy', () => {
    assert.equal(M.health({time_us:10,sources:[]},10),'NO SOURCES');
    assert.equal(M.health({time_us:10,sources:[{status:'ok'}]},20_000_000),'STALE');
    assert.equal(M.health({time_us:10,paused:true,sources:[{status:'ok'}]},10),'PAUSED');
    assert.equal(M.health({time_us:10,sources:[{status:'timeout'}]},10),'DEGRADED');
});
test('range follows live clock, frozen range is independent', () => {
    assert.equal(M.windowStart(1_000_000_000,5),700_000_000);
});
test('source filter distinguishes journal scope', () => {
    assert.equal(M.filter([{...event('a',10),source:'user-journal'}],{source:'system-journal'}).length,0);
});
test('comparison is operator-readable with signed units and missing qualification', () => {
    const text=M.comparisonText({a:{label:'Before'},b:{label:'After'},duration_us:60000000,delta:{cpu_some_avg10:2,memory_available_kib:-1024},units:{cpu_some_avg10:'percentage points',memory_available_kib:'KiB'},missing:['io_some_avg10']});
    assert.match(text,/Before → After/);
    assert.match(text,/\+2.*percentage points/);
    assert.match(text,/-1024.*KiB/);
    assert.match(text,/Unavailable/);
});
test('sample inspection includes explicit missing observations', () => {
    const samples=[{time_us:10,values:{cpu_some_avg10:0}},{time_us:20,values:{cpu_some_avg10:null}}];
    assert.equal(M.sampleIndex(samples,18),1);
    assert.equal(M.sampleIndex([],18),-1);
});
test('saved evidence inspection retains exact provenance including zero monotonic time', () => {
    const text=M.evidenceText({id:'exact',time_us:1000000,source:'user-journal',unit:'worker',boot:'boot-one',monotonic_us:0,message:'Saved copy'});
    assert.match(text,/Saved copy/);
    assert.match(text,/Boot: boot-one/);
    assert.match(text,/Monotonic µs: 0/);
    assert.match(text,/ID: exact/);
});
test('historical jump requires an unambiguous real ISO instant', () => {
    assert.equal(M.parseInstant('2026-09-07T08:00:00-10:00'), Date.UTC(2026,8,7,18)*1000);
    assert.equal(M.parseInstant('2026-09-07T18:00Z'), Date.UTC(2026,8,7,18)*1000);
    for (const invalid of ['2026-09-07 08:00','2026-02-30T18:00Z','2026-09-07T24:00Z','2026-09-07T18:00:60Z','bad','1969-01-01T00:00Z']) {
        assert.equal(M.parseInstant(invalid), null, invalid);
    }
});
