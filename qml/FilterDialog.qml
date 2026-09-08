import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons

ChronicleDialog {
    id: root
    property string selectedUnit: ""
    readonly property var terms: exclusions.text.split("\n").map(function (t) {
        return t.trim();
    }).filter(function (t) {
        return !!t;
    })
    readonly property bool valid: terms.length <= 8 && terms.every(function (t) {
        return t.length <= 200;
    })
    signal applied(string unit, var exclude)
    function showFilters(unit, exclude) {
        unitInput.text = unit;
        exclusions.text = exclude.join("\n");
        open();
    }
    title: "Focus the evidence"
    modal: true
    width: Math.min(parent.width - 24, Style.space(700))
    height: Math.min(parent.height - 24, Style.space(540))
    standardButtons: Dialog.Cancel
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    background: Rectangle {
        color: Color.popups.background
        border.color: Color.popups.border
    }
    ColumnLayout {
        anchors.fill: parent
        ChronicleLabel {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: "Hide known noise from this view, without deleting history. Search, level and category controls still apply."
        }
        ChronicleLabel {
            text: "Exact unit · leave empty for all"
        }
        RowLayout {
            Input {
                id: unitInput
                objectName: "unitFilterInput"
                Layout.fillWidth: true
                maximumLength: 160
                Accessible.name: "Exact unit"
                placeholderText: "pipewire.service"
            }
            ChronicleButton {
                text: "Use selected"
                enabled: !!root.selectedUnit
                onClicked: unitInput.text = root.selectedUnit
            }
        }
        ChronicleLabel {
            text: "Hide messages or units containing · one literal phrase per line"
        }
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Notes {
                id: exclusions
                objectName: "exclusionInput"
                maximumCharacters: 1800
                Accessible.name: "Excluded phrases"
                placeholderText: "health check\nperiodic refresh"
            }
        }
        ChronicleLabel {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font.pixelSize: Style.font.caption
            color: root.valid ? Color.popups.text : Color.urgent
            text: root.valid ? root.terms.length + "/8 phrases · 200 characters each · case-insensitive · no regex or wildcard syntax" : "Use up to eight phrases, with no more than 200 characters in each."
        }
        RowLayout {
            ChronicleButton {
                text: "Apply filters"
                objectName: "applyFilters"
                enabled: root.valid
                onClicked: {
                    root.applied(unitInput.text, root.terms);
                    root.close();
                }
            }
            ChronicleButton {
                text: "Clear unit + exclusions"
                onClicked: {
                    root.applied("", []);
                    root.close();
                }
            }
        }
    }
}
