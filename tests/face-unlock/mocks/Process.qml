import QtQml
QtObject {
    property list<string> command
    property var environment
    property bool running: false
    property QtObject stdout
    signal started()
    signal exited(int exitCode)
    Component.onCompleted: {
        if (command[1] === "monitor") Harness.monitor = this;
        else Harness.query = this;
    }
}
