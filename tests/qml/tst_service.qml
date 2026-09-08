import QtQuick
import QtTest
import "../../qml" as Chronicle

TestCase {
    name:"ChronicleService"
    Chronicle.Service { id:service }
    function init(){service.pending=({});service.snapshot=({});service.incident=null;service.preview=null;service.comparison=null;service.lastError="";service.lastAction=""}
    function test_no_manifest_means_no_process(){verify(!service.daemonRunning)}
    function test_invalid_json_is_not_accepted(){service.handleLine("bad");verify(service.lastError.length>0)}
    function test_uncorrelated_results_are_ignored(){service.handleLine(JSON.stringify({type:"result",request_id:"missing",ok:true,result:{id:"unexpected"}}));compare(service.incident,null)}
    function test_correlated_incident_result(){service.pending=({one:{cmd:"incident",args:{},sent:Date.now()}});service.handleLine(JSON.stringify({type:"result",request_id:"one",ok:true,result:{id:"expected"}}));compare(service.incident.id,"expected");compare(Object.keys(service.pending).length,0)}
    function test_restart_invalidates_pending_and_preview(){service.snapshot=({session:"old"});service.preview=({token:"old"});service.pending=({one:{cmd:"incident"}});service.handleLine(JSON.stringify({type:"snapshot",protocol:1,session:"new"}));compare(service.preview,null);compare(Object.keys(service.pending).length,0)}
    function test_offline_request_is_explicit(){compare(service.request("bookmark",{}),"");verify(service.lastError.indexOf("unavailable")>=0)}
}
