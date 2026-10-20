pragma Singleton
import QtQml

QtObject {
    property var current: null
    property int starts: 0
    property int aborts: 0
    property bool startAllowed: true
    property var monitor: null
    property var query: null
    function reset() {
        current = null;
        starts = 0;
        aborts = 0;
        startAllowed = true;
        monitor = null;
        query = null;
    }
}
