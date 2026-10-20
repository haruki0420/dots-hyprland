import QtQml

QtObject {
    property string config: ""
    property string configDirectory: ""
    property bool active: false
    property bool responseRequired: false
    signal pamMessage()
    signal completed(int result)
    function respond(text) {}

    function start() {
        Harness.current = this;
        Harness.starts++;
        active = Harness.startAllowed;
        return active;
    }
    function abort() {
        Harness.aborts++;
        active = false;
    }
    function finish(result) {
        active = false;
        completed(result);
    }
}
