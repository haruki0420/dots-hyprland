pragma Singleton
import QtQml

QtObject {
    property var current: null
    property int starts: 0
    property int aborts: 0
    property bool startAllowed: true
    function reset() {
        current = null;
        starts = 0;
        aborts = 0;
        startAllowed = true;
    }
}
