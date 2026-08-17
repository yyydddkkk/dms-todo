// Hallmark · component: task row v3 · genre: utilitarian · theme: DMS dynamic
// Pre-emit critique: P5 H4 E4 S5 R5 V4 · contrast: delegated to Theme tokens
import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets

Rectangle {
    id: row

    required property var pluginRoot
    required property var controller
    required property var taskData
    property string taskText: taskData && taskData.text !== undefined ? String(taskData.text) : ""
    property string mode: "active"
    property Item dragTarget: null
    property bool dragEnabled: mode === "active"
    property bool dragSource: false
    property bool childDropTarget: false
    readonly property bool dragging: rowArea.drag.active
    readonly property bool isTrash: mode === "trash"
    readonly property bool isCompleted: mode === "completed" || Boolean(taskData.completed)
    readonly property bool showDate: !isTrash && !isCompleted && Boolean(taskData.dueDate)
    readonly property bool showPriority: !isTrash && !isCompleted && Boolean(taskData.priority)

    signal dragBegan
    signal dragFinished
    signal dragCancelled

    function openActionMenu() {
        actionMenu.popup(moreButton, -actionMenu.width + moreButton.width, moreButton.height + Theme.spacingXXS)
    }

    implicitHeight: 48
    activeFocusOnTab: true
    radius: Theme.cornerRadius / 2
    color: {
        if (childDropTarget)
            return Theme.withAlpha(Theme.primary, 0.16)
        if (rowArea.containsMouse)
            return Theme.withAlpha(Theme.surfaceContainerHigh, 0.55)
        if (!isCompleted && !isTrash && taskData.priority === "high")
            return Theme.withAlpha(Theme.error, 0.055)
        return "transparent"
    }
    border.width: 1
    border.color: activeFocus || dragSource ? Theme.primary : "transparent"
    opacity: dragSource ? 0.72 : 1

    Keys.onReturnPressed: {
        if (!isTrash)
            controller.startEditing(taskData.id)
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space && !isTrash) {
            pluginRoot.toggleTodo(taskData.id)
            event.accepted = true
        } else if (event.key === Qt.Key_Menu || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))) {
            openActionMenu()
            event.accepted = true
        }
    }
    Keys.onEscapePressed: actionMenu.close()

    MouseArea {
        id: rowArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: row.isTrash ? Qt.ArrowCursor : Qt.PointingHandCursor
        drag.target: row.dragEnabled ? row.dragTarget : null
        drag.axis: Drag.YAxis
        drag.threshold: 4
        preventStealing: true
        onPressed: {
            row.forceActiveFocus()
            if (row.dragEnabled)
                row.dragBegan()
        }
        onReleased: {
            if (row.dragEnabled)
                row.dragFinished()
        }
        onCanceled: {
            if (row.dragEnabled)
                row.dragCancelled()
        }
        onClicked: {
            row.forceActiveFocus()
            if (!row.isTrash)
                row.controller.startEditing(row.taskData.id)
        }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingXS
        anchors.rightMargin: Theme.spacingXS
        spacing: Theme.spacingXS

        Item {
            id: checkButton
            width: visible ? 40 : 0
            height: 40
            visible: !row.isTrash
            anchors.verticalCenter: parent.verticalCenter

            DankIcon {
                anchors.centerIn: parent
                name: row.isCompleted ? "check_circle" : "radio_button_unchecked"
                size: 18
                color: row.isCompleted ? Theme.primary : Theme.surfaceVariantText
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: row.pluginRoot.toggleTodo(row.taskData.id)
            }
        }

        Item {
            id: content
            width: parent.width
                - (!row.isTrash ? checkButton.width : 0)
                - moreButton.width
                - parent.spacing * 2
            height: parent.height

            StyledText {
                id: titleText
                anchors.left: parent.left
                anchors.right: metaText.visible ? metaText.left : parent.right
                anchors.rightMargin: metaText.visible ? Theme.spacingS : 0
                anchors.verticalCenter: parent.verticalCenter
                text: row.taskText
                font.pixelSize: Theme.fontSizeMedium
                font.weight: row.taskData.priority === "high" && !row.isCompleted ? Font.Medium : Font.Normal
                font.strikeout: row.isCompleted
                color: row.isTrash ? Theme.surfaceVariantText : Theme.surfaceText
                opacity: row.isCompleted ? 0.68 : 1
                elide: Text.ElideRight
            }

            StyledText {
                id: metaText
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: row.showPriority || row.showDate
                text: {
                    const parts = []
                    if (row.showPriority)
                        parts.push(row.pluginRoot.priorityLabel(row.taskData.priority))
                    if (row.showDate)
                        parts.push(row.pluginRoot.dueLabel(row.taskData.dueDate))
                    return parts.join(" · ")
                }
                font.pixelSize: Theme.fontSizeSmall
                color: {
                    const today = row.pluginRoot.localDateKey(new Date())
                    if (row.showDate && row.taskData.dueDate < today)
                        return Theme.error
                    if (row.taskData.priority === "high")
                        return Theme.error
                    if ((row.showDate && row.taskData.dueDate === today) || row.taskData.priority === "medium")
                        return Theme.primary
                    return Theme.surfaceVariantText
                }
            }
        }

        Item {
            id: moreButton
            width: 40
            height: 40
            anchors.verticalCenter: parent.verticalCenter

            DankIcon {
                anchors.centerIn: parent
                name: "more_vert"
                size: 17
                color: Theme.surfaceVariantText
                opacity: moreArea.containsMouse || actionMenu.visible ? 1 : 0.62
            }

            MouseArea {
                id: moreArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                ToolTip.visible: containsMouse
                ToolTip.delay: 800
                ToolTip.text: "More actions"
                onClicked: {
                    row.forceActiveFocus()
                    row.openActionMenu()
                }
            }
        }
    }


    Menu {
        id: actionMenu
        width: 156
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        onClosed: row.forceActiveFocus()

        background: Rectangle {
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.width: 1
            border.color: Theme.outlineVariant
        }

        MenuItem {
            text: row.isTrash ? "Restore" : "Edit"
            height: 40
            contentItem: StyledText {
                text: parent.text
                leftPadding: Theme.spacingS
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
            }
            background: Rectangle {
                color: parent.hovered ? Theme.primaryHoverLight : "transparent"
                radius: Theme.cornerRadius / 2
            }
            onTriggered: {
                if (row.isTrash)
                    row.pluginRoot.restoreTodo(row.taskData.id)
                else
                    row.controller.startEditing(row.taskData.id)
            }
        }

        MenuItem {
            text: "Add subtask"
            height: visible ? 40 : 0
            visible: !row.isTrash && !row.isCompleted
            contentItem: StyledText {
                text: parent.text
                leftPadding: Theme.spacingS
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
            }
            background: Rectangle {
                color: parent.hovered ? Theme.primaryHoverLight : "transparent"
                radius: Theme.cornerRadius / 2
            }
            onTriggered: row.controller.startAddingChild(row.taskData.id)
        }

        MenuItem {
            text: row.isTrash ? "Delete permanently" : "Delete"
            height: 40
            contentItem: StyledText {
                text: parent.text
                leftPadding: Theme.spacingS
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.error
            }
            background: Rectangle {
                color: parent.hovered ? Theme.errorHover : "transparent"
                radius: Theme.cornerRadius / 2
            }
            onTriggered: {
                if (row.isTrash)
                    row.pluginRoot.permanentlyDeleteTodo(row.taskData.id)
                else
                    row.pluginRoot.deleteTodo(row.taskData.id)
            }
        }
    }
}
