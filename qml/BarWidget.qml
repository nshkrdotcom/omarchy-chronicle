import QtQuick
import qs.Commons
import qs.Ui as Ui

Ui.BarWidget {
    id: root
    moduleName: "nshkr.chronicle"
    property string omarchyPath: ""
    property var shell: null
    property var manifest: null
    readonly property var chronicleService: root.bar && root.bar.shell ? root.bar.shell.serviceFor(root.moduleName) : null
    readonly property bool opened: panelLoader.item ? panelLoader.item.opened : false
    readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing : false
    function open(payloadJson) {
        if (panelLoader.item)
            panelLoader.item.open();
    }
    function close() {
        if (panelLoader.item)
            panelLoader.item.close();
    }
    function toggle() {
        if (opened)
            close();
        else
            open("{}");
    }
    function closeForPopoutSwitch() {
        if (panelLoader.item)
            panelLoader.item.closeForPopoutSwitch();
    }
    function inject() {
        if (!panelLoader.item)
            return;
        panelLoader.item.bar = root.bar;
        panelLoader.item.anchorItem = button;
        panelLoader.item.hostWidget = root;
        panelLoader.item.service = root.chronicleService;
        panelLoader.item.settings = root.settings;
    }
    onBarChanged: inject()
    onChronicleServiceChanged: inject()
    onSettingsChanged: inject()
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight
    Loader {
        id: panelLoader
        active: true
        visible: false
        source: Qt.resolvedUrl("Panel.qml")
        onLoaded: {
            root.inject();
            Qt.callLater(root.inject);
        }
    }
    Ui.WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        fixedWidth: root.vertical ? -1 : Style.bar.statusSlot
        fixedHeight: root.vertical ? Style.bar.statusSlot : -1
        horizontalMargin: 0
        labelVisible: false
        text: "CH"
        tooltipText: "Chronicle · What changed before this broke?\n" + (root.chronicleService && root.chronicleService.daemonRunning ? root.chronicleService.snapshot.paused ? "Recording paused" : "Local recorder running" : "Recorder unavailable")
        Ui.OpticalGlyph {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: root.vertical ? 0 : -Style.spacing.xxs
            width: Style.bar.iconCanvas
            height: Style.bar.iconCanvas
            text: "CH"
            fontFamily: button.fontFamily
            fontSize: button.fontSize
            color: button.foreground
        }
        onPressed: function (mouseButton) {
            if (mouseButton === Qt.LeftButton)
                root.toggle();
        }
    }
}
