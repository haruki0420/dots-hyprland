pragma Singleton
import QtQml
QtObject {
    property var options: ({lock: {security: {faceUnlockOnResume: true}}})
}
