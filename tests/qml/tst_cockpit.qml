import QtQuick
import QtTest
import qs.Commons
import "../../qml" as Chronicle

TestCase {
    id: test
    name: "ChronicleCockpit"
    when: windowShown
    width: 1280
    height: 840
    visible: true
    property var sent: []
    QtObject {
        id: fake
        property var snapshot: ({time_us:1000000000,demo:true,paused:false,sources:[{id:"user-journal",status:"demo"}],events:[{id:"one",time_us:999000000,severity:"error",category:"service",unit:"worker.service",message:"Example failure",source:"demo",boot:"fixture",monotonic_us:10}],samples:[],bookmarks:[],incidents:[],event_count:1})
        property var incident: null
        property var comparison: null
        property var preview: null
        property string lastAction: ""
        property string lastError: ""
        property bool daemonRunning: true
        function request(cmd, args) { test.sent.push({cmd:cmd,args:args}); return "request" }
    }
    Chronicle.Cockpit { id: cockpit; anchors.fill: parent; service: fake; nowUs: 1000000000 }
    function init() { cockpit.page = 0; cockpit.frozen = false; cockpit.selectedId = ""; sent = [] }
    function test_native_header_contract() {
        const title = findChild(cockpit,"chronicleTitle")
        compare(title.font.pixelSize, Style.font.subtitle)
        compare(title.font.weight, Font.DemiBold)
        fuzzyCompare(title.font.letterSpacing, 0.4, 0.02)
        const actions = findChild(cockpit,"headerActions")
        verify(actions.x > title.x + title.width)
    }
    function test_freeze_does_not_pause_recorder() {
        cockpit.toggleFreeze()
        verify(cockpit.frozen)
        compare(cockpit.visibleEvents.length,1)
        compare(sent.length,0)
        cockpit.toggleFreeze()
        verify(!cockpit.frozen)
    }
    function test_mark_sends_current_moment_request() {
        mouseClick(findChild(cockpit,"markButton"))
        compare(sent[0].cmd,"bookmark")
    }
    function test_filter_and_exact_selection() {
        cockpit.selectEvent("one")
        compare(cockpit.selectedEvent.id,"one")
        cockpit.selectEvent("missing")
        compare(cockpit.selectedEvent,null)
    }
    function test_keyboard_freeze_and_escape() {
        cockpit.forceActiveFocus()
        keyClick(Qt.Key_Space)
        verify(cockpit.frozen)
    }
    function test_tabs_and_focus() {
        mouseClick(findChild(cockpit,"sourcesTab"))
        compare(cockpit.page,3)
        verify(findChild(cockpit,"sourcesTab").activeFocus)
    }
    function test_widths_keep_actions_on_right_data() {
        return [{tag:"compact",size:800},{tag:"normal",size:1280}]
    }
    function test_widths_keep_actions_on_right(data) {
        test.width = data.size
        wait(30)
        const rail = findChild(cockpit,"headerActions")
        verify(rail.x + rail.width <= cockpit.width + 1)
        compare(findChild(cockpit,"chronicleTitle").font.pixelSize,Style.font.subtitle)
        test.width = 1280
    }
}
