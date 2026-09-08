pragma Singleton
import QtQuick

QtObject {
    // Isolated test inputs, not a claim of native compositor acceptance.
    property int cornerRadius: 3
    property var font: ({
            family: "monospace",
            caption: 12,
            body: 14,
            subtitle: 16,
            title: 20
        })
    property var spacing: ({
            xxs: 2,
            sm: 4,
            md: 6,
            huge: 16,
            controlPaddingX: 10,
            controlPaddingY: 6,
            hairline: 1
        })
    function space(value) {
        return value;
    }
}
