import QtQuick
import qs.Commons
import qs.Ui as Ui

Ui.Panel {
    id: root
    moduleName: "nshkr.chronicle"
    manageIpc: false
    property var anchorItem: null
    property var hostWidget: null
    property var service: null
    readonly property string ownerId: "panel-" + Date.now() + "-" + Math.random()
    onOpenedChanged: {
        if (service)
            service.setPanelOpen(ownerId, opened);
        if (!opened)
            cockpit.frozen = false;
    }
    onServiceChanged: if (service)
        service.setPanelOpen(ownerId, opened)
    Ui.KeyboardPanel {
        id: panel
        anchorItem: root.anchorItem
        owner: root.hostWidget || root
        bar: root.bar
        open: root.opened
        focusTarget: cockpit
        centerOnBar: true
        padding: Style.space(8)
        contentWidth: panel.fittedContentWidth(Style.space(1280))
        contentHeight: panel.cappedContentHeight(Style.space(840))
        Cockpit {
            id: cockpit
            anchors.fill: parent
            service: root.service
            onDismissed: root.close()
        }
    }
    Timer {
        interval: 1000
        running: root.opened
        repeat: true
        onTriggered: cockpit.nowUs = Date.now() * 1000
    }
    Component.onDestruction: if (service)
        service.setPanelOpen(ownerId, false)
}
