import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ToolbarButton {
    id: root
    required property LockContext context
    objectName: "faceRetryButton"
    visible: Config.options.lock.security.faceUnlockOnResume
        && context.targetAction === LockContext.ActionEnum.Unlock
    enabled: context.canRetryFaceUnlock
    implicitWidth: retryContent.implicitWidth + 24
    implicitHeight: 40
    Accessible.name: Translation.tr("Retry face authentication")
    onClicked: context.retryFaceUnlock()
    contentItem: RowLayout {
        id: retryContent
        spacing: 6
        MaterialSymbol {
            text: "face"
            iconSize: 22
            color: Appearance.colors.colOnSurface
        }
        StyledText {
            text: Translation.tr("Retry face authentication")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnSurface
        }
    }
}
