import QtQuick
import QtTest
import "../../qml" as Chronicle

TestCase {
    id:test
    name:"ChronicleFixturePreview"
    when:windowShown
    visible:true
    width:1280;height:840
    QtObject {
        id:fake
        property var snapshot:({})
        property var incident:null
        property var preview:null
        property var comparison:null
        property bool daemonRunning:true
        property string lastError:""
        property string lastAction:"Synthetic fixture · no host collection · not installed"
        function request(cmd,args){return "fixture"}
    }
    Chronicle.Cockpit { id:cockpit;anchors.fill:parent;anchors.margins:8;service:fake;nowUs:1000000000 }
    function initTestCase(){
        var events=[], samples=[]
        var units=["example.service","omarchy-shell.service","NetworkManager.service","pipewire.service","systemd-suspend.service"]
        var messages=["Worker exited unexpectedly","Desktop configuration reloaded","Connection became unavailable","Audio graph resynchronized","System resumed"]
        var categories=["service","desktop","network","audio","power"]
        for(var i=0;i<45;i++)events.unshift({id:"event-"+i,time_us:1000000000-(45-i)*5000000,severity:i%5===0?"error":i%5===2?"warning":"info",category:categories[i%5],unit:units[i%5],message:messages[i%5],source:"demo",boot:"fixture-boot",monotonic_us:i*5000000})
        for(var j=0;j<60;j++)samples.push({time_us:1000000000-(60-j)*5000000,values:{cpu_some_avg10:j===35?null:3+2*Math.sin(j/4)}})
        fake.snapshot={time_us:1000000000,demo:true,paused:false,sources:[{id:"user-journal",status:"demo",checked_us:1000000000,last_success_us:1000000000}],events:events,samples:samples,event_count:45,bookmarks:[],incidents:[]}
        cockpit.selectedId="event-40"
    }
    function test_capture(){
        wait(150)
        var path="/tmp/chronicle-fixture-"+Date.now()+".png"
        grabImage(cockpit).save(path)
        console.log("Fixture screenshot: "+path)
    }
}
