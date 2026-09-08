import QtQuick
import QtTest
import qs.Commons
import "../../qml" as Chronicle

TestCase {
    name: "ChronicleGraphics"
    when: windowShown
    visible: true
    width: 500
    height: 220
    Chronicle.PressureTrace {
        id: trace
        width: 500
        height: 140
        fromUs: 0
        toUs: 100000000
        samples: [
            {
                time_us: 10000000,
                values: {
                    cpu_some_avg10: 0
                }
            },
            {
                time_us: 20000000,
                values: {
                    cpu_some_avg10: 5
                }
            },
            {
                time_us: 25000000,
                values: {
                    cpu_some_avg10: null
                }
            }
        ]
    }
    function test_frozen_graph_repaints_when_accent_changes() {
        wait(50);
        const before = grabImage(trace);
        const original = Color.accent;
        Color.accent = "#ff55dd";
        wait(50);
        const changed = !before.equals(grabImage(trace));
        Color.accent = original;
        verify(changed, "Theme changes must repaint a graph even when samples are frozen");
    }
    function test_keyboard_inspects_zero_and_missing_samples() {
        trace.forceActiveFocus();
        trace.inspectedIndex = -1;
        keyClick(Qt.Key_Right);
        compare(trace.inspectedIndex, 0);
        verify(trace.readout.indexOf("0.00%") >= 0);
        keyClick(Qt.Key_Right);
        keyClick(Qt.Key_Right);
        verify(trace.readout.indexOf("unavailable") >= 0);
    }
}
