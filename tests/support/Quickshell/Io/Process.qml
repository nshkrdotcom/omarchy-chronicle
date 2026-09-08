import QtQuick
// Transport stub only. Python subprocess integration is tested independently.
Item {
    property var command: []
    property bool stdinEnabled: false
    property bool running: false
    property QtObject stdout: null
    property QtObject stderr: null
    property var writes: []
    signal started()
    signal exited(int code, int status)
    function write(line) { writes = writes.concat([line]) }
    onRunningChanged: if(running) started()
}
