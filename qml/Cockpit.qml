import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import "Timeline.js" as Model

FocusScope {
    id: root
    property var service: null
    property real nowUs: Date.now()*1000
    property int page: 0
    property bool frozen: false
    property var frozenSnapshot: ({})
    property string selectedId: ""
    property int windowMinutes: 5
    property string severity: "all"
    property string category: "all"
    property string bookmarkA: ""
    property string bookmarkB: ""
    property string incidentId: ""
    property string confirmationId: ""
    property bool detailedExport: false
    readonly property var live: service ? service.snapshot : ({})
    readonly property var view: frozen ? frozenSnapshot : live
    readonly property real endUs: frozen ? Number(view.time_us || nowUs) : nowUs
    readonly property real startUs: Model.windowStart(endUs,windowMinutes)
    readonly property var visibleEvents: Model.filter(view.events || [],{from:startUs,to:endUs,severity:severity,category:category,search:search.text})
    readonly property var selectedEvent: Model.selected(view.events || [],selectedId)
    readonly property var currentIncident: service ? service.incident : null
    readonly property string status: service && !service.daemonRunning ? "OFFLINE" : Model.health(live,nowUs)
    signal dismissed()
    function request(cmd,args) { if(service) return service.request(cmd,args || {}); return "" }
    function toggleFreeze() {
        if(!frozen) frozenSnapshot=JSON.parse(JSON.stringify(live))
        frozen=!frozen
    }
    function selectEvent(id) { selectedId=id }
    function openIncident(id) { incidentId=id; notes.text=""; request("incident",{id:id}) }
    function updateQuery() {
        if(!frozen) request("query",{search:search.text,severity:severity,category:category})
    }
    onFrozenChanged: if(!frozen) updateQuery()
    onSeverityChanged: updateQuery()
    onCategoryChanged: updateQuery()
    Connections {
        target: root.service
        ignoreUnknownSignals: true
        function onIncidentChanged() {
            if(root.currentIncident && !notes.activeFocus) notes.text=root.currentIncident.notes || ""
            if(root.currentIncident) root.incidentId=root.currentIncident.id
        }
        function onPreviewChanged() { if(root.service.preview) exportDialog.open() }
    }
    Keys.onPressed: function(event) {
        if(event.key===Qt.Key_Escape) { root.dismissed();event.accepted=true }
        else if(event.key===Qt.Key_Space && !event.modifiers) {root.toggleFreeze();event.accepted=true}
        else if(event.key===Qt.Key_Slash && !event.modifiers) {search.forceActiveFocus();event.accepted=true}
        else if(event.key===Qt.Key_M && (event.modifiers & Qt.ControlModifier)) {root.request("bookmark",{label:"Moment"});event.accepted=true}
        else if((event.key===Qt.Key_Up || event.key===Qt.Key_Down) && root.page===0) {
            var index=root.visibleEvents.findIndex(function(e){return e.id===root.selectedId})
            index=Math.max(0,Math.min(root.visibleEvents.length-1,index+(event.key===Qt.Key_Down?1:-1)))
            if(root.visibleEvents[index]){root.selectEvent(root.visibleEvents[index].id);eventList.positionViewAtIndex(index,ListView.Contain)}
            event.accepted=true
        }
    }
    Rectangle { anchors.fill: parent; color: Color.popups.background }
    ColumnLayout {
        anchors.fill: parent
        spacing: Style.space(8)
        RowLayout {
            Layout.fillWidth: true
            spacing: Style.spacing.huge
            ColumnLayout {
                Layout.maximumWidth: Style.space(330)
                spacing: Style.spacing.xxs
                ChronicleLabel { objectName:"chronicleTitle"; text:"CHRONICLE"; font.pixelSize:Style.font.subtitle; font.weight:Font.DemiBold; font.letterSpacing:0.4 }
                ChronicleLabel { text:root.status+(root.frozen?" · FROZEN VIEW":" · LIVE VIEW"); color:root.status==="RECORDING"?Color.accent:Color.urgent; font.pixelSize:Style.font.caption }
            }
            Item { Layout.fillWidth: true }
            RowLayout {
                objectName: "headerActions"
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                spacing: Style.spacing.sm
                ChronicleButton { text:"/ Search"; onClicked:search.forceActiveFocus() }
                ChronicleButton { objectName:"freezeButton"; text:root.frozen?"Live":"Freeze"; chosen:root.frozen; hint:"Space · Freeze this view; recording continues"; onClicked:root.toggleFreeze() }
                ChronicleButton { objectName:"markButton"; text:"Mark"; hint:"Ctrl+M · Save this moment with current scalar measurements"; enabled:root.service && root.service.daemonRunning && !root.live.paused; onClicked:root.request("bookmark",{label:"Moment"}) }
                ChronicleButton { text:"Close"; hint:"Esc · Close panel; recording continues"; onClicked:root.dismissed() }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            ChronicleButton { text:"Timeline"; chosen:root.page===0; onClicked:root.page=0 }
            ChronicleButton { text:"Bookmarks"; chosen:root.page===1; onClicked:root.page=1 }
            ChronicleButton { text:"Incidents"; chosen:root.page===2; onClicked:root.page=2 }
            ChronicleButton { objectName:"sourcesTab"; text:"Sources"; chosen:root.page===3; onClicked:root.page=3 }
            Item { Layout.fillWidth:true }
            ChronicleLabel { text:Number(root.live.event_count||0)+" retained"; font.pixelSize:Style.font.caption }
        }
        Rectangle { Layout.fillWidth:true; implicitHeight:Style.spacing.hairline; color:Color.popups.border }
        RowLayout {
            Layout.fillWidth:true
            Input { id:search; objectName:"searchInput"; Layout.fillWidth:true; placeholderText:root.frozen?"Filter frozen evidence…":"Search retained history…"; onTextEdited:queryDelay.restart(); Keys.onEscapePressed:root.forceActiveFocus() }
            Repeater {
                model:[5,15,60,10080]
                ChronicleButton { required property int modelData; text:modelData===10080?"7d":modelData+"m"; chosen:root.windowMinutes===modelData; onClicked:root.windowMinutes=modelData }
            }
        }
        StackLayout {
            Layout.fillWidth:true
            Layout.fillHeight:true
            currentIndex:root.page
            ColumnLayout {
                spacing:Style.space(6)
                RowLayout {
                    ChronicleButton { text:root.severity==="all"?"All levels":root.severity; onClicked:root.severity=root.severity==="all"?"error":root.severity==="error"?"warning":"all" }
                    ChronicleButton { text:root.category==="all"?"All categories":root.category; onClicked:{var choices=["all"].concat(Model.categories);root.category=choices[(choices.indexOf(root.category)+1)%choices.length]} }
                    ChronicleLabel { Layout.fillWidth:true; text:"● info   ▲ warning   ◆ error · newest 500 matches · local time"; font.pixelSize:Style.font.caption }
                }
                EventLanes { Layout.fillWidth:true; events:root.visibleEvents; fromUs:root.startUs; toUs:root.endUs; selectedId:root.selectedId; onSelected:function(eventId){root.selectEvent(eventId)} }
                PressureTrace { Layout.fillWidth:true; samples:root.view.samples||[]; fromUs:root.startUs; toUs:root.endUs }
                RowLayout {
                    Layout.fillWidth:true
                    Layout.fillHeight:true
                    ListView {
                        id:eventList
                        objectName:"eventList"
                        Layout.fillWidth:true
                        Layout.fillHeight:true
                        Layout.preferredWidth:root.width*0.6
                        clip:true
                        model:root.visibleEvents
                        spacing:Style.space(3)
                        ScrollBar.vertical: ScrollBar {}
                        onMovementStarted: if(!root.frozen) root.toggleFreeze()
                        delegate: ChronicleButton {
                            required property var modelData
                            width:eventList.width-Style.space(14)
                            text:(modelData.severity==="error"?"◆ ":modelData.severity==="warning"?"▲ ":"● ")+new Date(modelData.time_us/1000).toLocaleTimeString()+" · "+modelData.unit+" · "+modelData.message
                            chosen:root.selectedId===modelData.id
                            hint:modelData.message
                            textAlignment:Text.AlignLeft
                            onClicked:{if(!root.frozen)root.toggleFreeze();root.selectEvent(modelData.id)}
                        }
                        ChronicleLabel { anchors.centerIn:parent; width:parent.width-20; wrapMode:Text.Wrap; horizontalAlignment:Text.AlignHCenter; visible:eventList.count===0; text:root.status==="OFFLINE"?"Recorder offline. Open Sources for status.":"No matching evidence in this interval. Widen the time window or clear filters; missing history is not proof that nothing happened." }
                    }
                    Rectangle { Layout.fillHeight:true; implicitWidth:Style.spacing.hairline; color:Color.popups.border }
                    ScrollView {
                        Layout.fillHeight:true
                        Layout.preferredWidth:Math.max(Style.space(230),root.width*0.34)
                        clip:true
                        contentWidth:availableWidth
                        ColumnLayout {
                            width:parent.width
                            ChronicleLabel { text:"EVIDENCE"; color:Color.accent; font.pixelSize:Style.font.caption }
                            ChronicleLabel { Layout.fillWidth:true; wrapMode:Text.WrapAnywhere; text:root.selectedEvent?root.selectedEvent.message:root.selectedId?"Selected event is no longer in this view. No substitute was selected.":"Select a marker or event. Scroll or select a row to freeze the investigation view." }
                            ChronicleLabel {
                                Layout.fillWidth:true; wrapMode:Text.WrapAnywhere; font.pixelSize:Style.font.caption
                                text:root.selectedEvent?"Time: "+Model.timestamp(root.selectedEvent.time_us)+"\nSource: "+root.selectedEvent.source+"\nUnit: "+root.selectedEvent.unit+"\nBoot: "+(root.selectedEvent.boot||"not recorded")+"\nMonotonic µs: "+(root.selectedEvent.monotonic_us===null?"unavailable":root.selectedEvent.monotonic_us)+"\nID: "+root.selectedEvent.id:""
                            }
                            ChronicleButton { text:root.incidentId?"Pin to selected incident":"Create incident + pin"; enabled:!!root.selectedEvent; onClicked:{if(root.incidentId)root.request("pin",{id:root.incidentId,event_id:root.selectedId});else root.request("create_incident",{title:"Investigation",pin_event_id:root.selectedId});root.page=2} }
                            ChronicleLabel { Layout.fillWidth:true; wrapMode:Text.Wrap; font.pixelSize:Style.font.caption; text:"Nearby events are not automatically causes. Categories come from source identity. Messages are redacted best-effort; do not assume they are safe to share." }
                        }
                    }
                }
            }
            ColumnLayout {
                RowLayout { Layout.fillWidth:true
                    Input { id:momentLabel; Layout.fillWidth:true; maximumLength:100; placeholderText:"Name this moment (e.g. Before update)" }
                    ChronicleButton { text:"Mark now"; onClicked:root.request("bookmark",{label:momentLabel.text||"Moment"}) }
                    ChronicleButton { text:"Compare A → B"; enabled:root.bookmarkA!=="" && root.bookmarkB!==""; onClicked:root.request("compare",{a:root.bookmarkA,b:root.bookmarkB}) }
                }
                ChronicleLabel { Layout.fillWidth:true; wrapMode:Text.Wrap; font.pixelSize:Style.font.caption; text:"Marks capture current collected measurements, not the frozen view. Select exact A/B marks for a signed comparison." }
                ListView {
                    id:marks; Layout.fillWidth:true; Layout.fillHeight:true; clip:true; model:root.live.bookmarks||[]; spacing:Style.space(4)
                    ScrollBar.vertical:ScrollBar{}
                    delegate: RowLayout {
                        required property var modelData
                        width:marks.width-Style.space(14)
                        ChronicleLabel { Layout.fillWidth:true; text:modelData.label+" · "+Model.timestamp(modelData.time_us) }
                        ChronicleButton { text:"A"; chosen:root.bookmarkA===modelData.id; onClicked:root.bookmarkA=modelData.id }
                        ChronicleButton { text:"B"; chosen:root.bookmarkB===modelData.id; onClicked:root.bookmarkB=modelData.id }
                        ChronicleButton { text:"Remove"; onClicked:{root.confirmationId="bookmark:"+modelData.id;confirmDialog.open()} }
                    }
                    ChronicleLabel { anchors.centerIn:parent; visible:marks.count===0; text:"No bookmarks yet. Mark a moment before your next change."; wrapMode:Text.Wrap; width:parent.width }
                }
                ScrollView { Layout.fillWidth:true; Layout.preferredHeight:Style.space(180); contentWidth:availableWidth; clip:true
                    ChronicleLabel { width:parent.width; wrapMode:Text.Wrap; font.pixelSize:Style.font.caption; text:root.service && root.service.comparison?JSON.stringify(root.service.comparison,null,2):"No comparison selected. Unavailable measurements are never treated as zero." }
                }
            }
            RowLayout {
                ListView {
                    id:incidents; Layout.fillHeight:true; Layout.preferredWidth:Math.max(Style.space(180),root.width*0.24); clip:true
                    model:root.live.incidents||[]; spacing:Style.space(4)
                    ScrollBar.vertical:ScrollBar{}
                    delegate: ChronicleButton { required property var modelData; width:incidents.width-Style.space(14); text:modelData.title+" · "+modelData.status+" · "+modelData.evidence_count; chosen:root.incidentId===modelData.id; onClicked:root.openIncident(modelData.id) }
                }
                ColumnLayout {
                    Layout.fillWidth:true; Layout.fillHeight:true
                    RowLayout { Layout.fillWidth:true
                        Input { id:incidentTitle; Layout.fillWidth:true; maximumLength:100; placeholderText:"New incident title" }
                        ChronicleButton { text:"Create"; onClicked:root.request("create_incident",{title:incidentTitle.text||"Investigation"}) }
                    }
                    ChronicleLabel { Layout.fillWidth:true; text:root.currentIncident?root.currentIncident.title+" · "+root.currentIncident.status:"Select or create an incident"; color:Color.accent }
                    ScrollView { Layout.fillWidth:true; Layout.preferredHeight:Style.space(120)
                        TextArea { id:notes; objectName:"incidentNotes"; placeholderText:"Investigation notes (4096 characters maximum)"; enabled:!!root.currentIncident; textFormat:TextEdit.PlainText; wrapMode:TextEdit.Wrap; color:Color.popups.text; font.family:Style.font.family; font.pixelSize:Style.font.body; selectByMouse:true; Accessible.name:"Incident notes"; onTextChanged:if(text.length>4096)text=text.slice(0,4096) }
                    }
                    RowLayout {
                        ChronicleButton { text:"Save notes"; enabled:!!root.currentIncident; onClicked:root.request("update_incident",{id:root.incidentId,notes:notes.text,status:root.currentIncident.status}) }
                        ChronicleButton { text:root.currentIncident && root.currentIncident.status==="closed"?"Reopen":"Resolve"; enabled:!!root.currentIncident; onClicked:root.request("update_incident",{id:root.incidentId,notes:notes.text,status:root.currentIncident.status==="closed"?"open":"closed"}) }
                        ChronicleButton { text:"Remove"; enabled:!!root.currentIncident; onClicked:{root.confirmationId="incident:"+root.incidentId;confirmDialog.open()} }
                    }
                    ListView {
                        id:pins; Layout.fillWidth:true; Layout.fillHeight:true; clip:true; spacing:Style.space(4)
                        model:root.currentIncident?root.currentIncident.evidence:[]
                        ScrollBar.vertical:ScrollBar{}
                        delegate: RowLayout { required property var modelData; width:pins.width-Style.space(14)
                            ChronicleLabel { Layout.fillWidth:true; wrapMode:Text.Wrap; text:Model.timestamp(modelData.time_us)+" · "+modelData.unit+"\n"+modelData.message; font.pixelSize:Style.font.caption }
                            ChronicleButton { text:"Unpin"; onClicked:root.request("unpin",{id:root.incidentId,event_id:modelData.id}) }
                        }
                        ChronicleLabel { anchors.centerIn:parent; visible:pins.count===0; width:parent.width; wrapMode:Text.Wrap; text:"No pinned evidence. Select an event on the Timeline and pin it here. Saved copies survive ordinary history retention." }
                    }
                    RowLayout {
                        ChronicleButton { text:root.detailedExport?"Messages + notes included":"Metadata only"; chosen:root.detailedExport; onClicked:root.detailedExport=!root.detailedExport }
                        ChronicleButton { text:"Preview export"; enabled:!!root.currentIncident; onClicked:root.request("preview_export",{id:root.incidentId,detail:root.detailedExport}) }
                    }
                }
            }
            ScrollView {
                contentWidth:availableWidth; clip:true
                ColumnLayout {
                    width:parent.width
                    ChronicleLabel { Layout.fillWidth:true; wrapMode:Text.Wrap; text:"SOURCE COVERAGE"; color:Color.accent }
                    ChronicleLabel { Layout.fillWidth:true; wrapMode:Text.Wrap; text:"User journal is read without elevated privileges. System journal is opt-in and limited to what your account can read. No records can mean no activity, missing retention, or unavailable access—not confirmed health." }
                    Repeater { model:root.live.sources||[]
                        ChronicleLabel { required property var modelData; Layout.fillWidth:true; wrapMode:Text.Wrap; font.pixelSize:Style.font.caption; text:modelData.id+" · "+modelData.status+" · checked "+Model.timestamp(modelData.checked_us)+" · last successful read "+Model.timestamp(modelData.last_success_us) }
                    }
                    RowLayout {
                        ChronicleButton { text:root.live.paused?"Resume recording":"Pause recording"; onClicked:root.request("pause",{paused:!root.live.paused}) }
                        ChronicleButton { text:root.live.system_journal?"Disable system journal":"Enable accessible system journal"; onClicked:root.request("system_journal",{enabled:!root.live.system_journal}) }
                        ChronicleButton { text:"Refresh"; onClicked:root.request("refresh",{}) }
                    }
                    ChronicleLabel { Layout.fillWidth:true; wrapMode:Text.Wrap; text:"BOUNDS & PRIVACY\n10,000 events / 7 days; 720 resource samples; 256 bookmarks; 128 incidents with 64 evidence copies each; 32 private exports. SQLite page budget is 32 MiB. Source reads are limited to 2 MiB / 2 seconds per attempt. A bounded tail can skip history: gaps are reported.\n\nRedaction runs before persistence, but cannot detect every secret. No arbitrary commands, clipboard capture, network upload, automatic repair, or service management. Export metadata first, then review any optional messages and notes.\n\nGRAPHICS\nPSI means percentage of time tasks were stalled; it is not CPU utilization. Lines break across missing or delayed samples. Event ordering uses recorded wall time; boot/monotonic provenance is retained for inspection. Wall-clock adjustments can change apparent order.\n\nKEYBOARD\n/ Search · Space freeze view · ↑/↓ select event · Ctrl+M mark current moment · Tab controls · Esc close. Scrolling the event list freezes the view to preserve your place.\n\nDEVELOPMENT GATE\nThis build has isolated tests. Installation, live popup behavior, native theme/monitor acceptance and compositor soak are still awaiting operator approval." }
                    Item { implicitHeight:Style.space(12) }
                }
            }
        }
        ChronicleLabel { Layout.fillWidth:true; font.pixelSize:Style.font.caption; color:root.service && root.service.lastError?Color.urgent:Color.accent; text:root.service?(root.service.lastError||root.service.lastAction||"Local evidence · correlation is not causation · no automatic repairs"):"Waiting for Chronicle service" }
    }
    Timer { id:queryDelay; interval:250; onTriggered:root.updateQuery() }
    Dialog {
        id:confirmDialog; title:"Remove saved item?"; modal:true; anchors.centerIn:parent; width:Math.min(parent.width-24,Style.space(500)); standardButtons:Dialog.Cancel|Dialog.Ok
        ChronicleLabel { width:parent.width; wrapMode:Text.Wrap; text:"This removes the selected saved item from Chronicle. Export important evidence first. This cannot be undone." }
        onAccepted:{var parts=root.confirmationId.split(":");root.request(parts[0]==="bookmark"?"remove_bookmark":"remove_incident",{id:parts[1],confirm:true});if(parts[0]==="incident")root.incidentId=""}
    }
    Dialog {
        id:exportDialog; objectName:"exportDialog"; title:"Review exact export · no upload"; modal:true; anchors.centerIn:parent; width:Math.min(parent.width-24,Style.space(900)); height:Math.min(parent.height-24,Style.space(620)); standardButtons:Dialog.Cancel
        background:Rectangle { color:Color.popups.background; border.color:Color.popups.border }
        ColumnLayout { anchors.fill:parent
            ChronicleLabel { Layout.fillWidth:true; wrapMode:Text.Wrap; text:"Review every field. Redaction is best-effort. Confirm writes these exact bytes to a private file; preview expires after five minutes." }
            ScrollView { Layout.fillWidth:true; Layout.fillHeight:true
                TextArea { readOnly:true; textFormat:TextEdit.PlainText; selectByMouse:true; wrapMode:TextEdit.WrapAnywhere; color:Color.popups.text; font.family:Style.font.family; font.pixelSize:Style.font.caption; text:root.service && root.service.preview?root.service.preview.text:"" }
            }
            ChronicleButton { text:"Save reviewed export"; enabled:root.service && !!root.service.preview; onClicked:{root.request("confirm_export",{token:root.service.preview.token});exportDialog.close()} }
        }
    }
}
