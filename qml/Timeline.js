// Pure functions shared by Qt and Node tests; no desktop state or side effects.
var categories = ["service", "desktop", "network", "audio", "power", "resource", "recorder"];
function filter(rows, options) {
    options = options || {};
    var query = String(options.search || "").toLowerCase();
    return (rows || []).filter(function(e) {
        return (!options.category || options.category === "all" || e.category === options.category)
            && (!options.source || options.source === "all" || e.source === options.source)
            && (!options.severity || options.severity === "all" || e.severity === options.severity)
            && (options.from === undefined || e.time_us >= options.from)
            && (options.to === undefined || e.time_us <= options.to)
            && (!query || (e.unit + " " + e.message).toLowerCase().indexOf(query) >= 0);
    });
}
function selected(rows, id) { return (rows || []).find(function(e) { return e.id === id; }) || null; }
function position(time, from, to, width) {
    return to > from && isFinite(time) ? Math.max(0, Math.min(width, (time - from) / (to - from) * width)) : null;
}
function buckets(rows, from, to, count) {
    count = Math.max(1, Math.min(200, Math.floor(count || 1)));
    var result = Array.from({length:count}, function() { return {count:0, errors:0, warnings:0}; });
    if (!(to > from)) return result;
    filter(rows, {from:from,to:to}).forEach(function(e) {
        var bin = result[Math.min(count - 1, Math.floor(position(e.time_us,from,to,count)))];
        bin.count++; if (e.severity === "error") bin.errors++;
        if (e.severity === "warning") bin.warnings++;
    });
    return result;
}
function nearest(rows, time, from, to) {
    return filter(rows,{from:from,to:to}).reduce(function(best,e) {
        return !best || Math.abs(e.time_us-time) < Math.abs(best.time_us-time) ? e : best;
    },null);
}
function segments(samples, key) {
    var result = [], segment = [], last = null;
    (samples || []).forEach(function(sample) {
        var value = (sample.values || {})[key];
        if (typeof value !== "number" || !isFinite(value) || (last !== null && (sample.time_us-last > 10000000 || sample.time_us <= last))) {
            if (segment.length) result.push(segment);
            segment = [];
        }
        if (typeof value === "number" && isFinite(value)) segment.push({time_us:sample.time_us,value:value});
        last = sample.time_us;
    });
    if (segment.length) result.push(segment);
    return result;
}
function health(snapshot, now) {
    if (snapshot.paused) return "PAUSED";
    if (!snapshot.time_us || now-snapshot.time_us > 15000000) return "STALE";
    if (!snapshot.sources || !snapshot.sources.length) return "NO SOURCES";
    if (snapshot.demo) return "DEMO";
    return snapshot.sources.some(function(s) { return ["ok","empty","disabled"].indexOf(s.status) < 0; }) ? "DEGRADED" : "RECORDING";
}
function windowStart(now, minutes) { return now - minutes * 60000000; }
function timestamp(us) { return us ? new Date(us/1000).toLocaleString() : "Unavailable"; }
function comparisonText(result) {
    if(!result) return "No comparison selected. Unavailable measurements are never treated as zero.";
    var names={cpu_some_avg10:"CPU PSI",memory_some_avg10:"Memory PSI",io_some_avg10:"I/O PSI",memory_available_kib:"Available memory"};
    var lines=[result.a.label+" → "+result.b.label, "Wall-time interval: "+(result.duration_us/60000000).toFixed(2)+" minutes", ""];
    Object.keys(result.delta || {}).forEach(function(key){var value=result.delta[key];lines.push((names[key]||key)+": "+(value>0?"+":"")+Number(value.toFixed(2))+" "+result.units[key]);});
    if((result.missing||[]).length) lines.push("Unavailable: "+result.missing.map(function(k){return names[k]||k}).join(", "));
    lines.push("", "Two observations, not a causal explanation. Clock changes can distort the wall-time interval.");
    if(result.a.observed_us)lines.push("A measured: "+timestamp(result.a.observed_us));
    if(result.b.observed_us)lines.push("B measured: "+timestamp(result.b.observed_us));
    return lines.join("\n");
}
function sampleIndex(samples,time) {
    var best=-1;
    (samples||[]).forEach(function(sample,index){if(best<0 || Math.abs(sample.time_us-time)<Math.abs(samples[best].time_us-time))best=index;});
    return best;
}
