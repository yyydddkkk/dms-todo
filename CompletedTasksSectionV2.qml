import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets

Column {
    id: section

    required property var pluginRoot
    required property var controller

    spacing: Theme.spacingXS

    Rectangle {
        width: parent.width
        height: 40
        radius: 0
        color: headerArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHigh, 0.45) : "transparent"

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: Theme.outlineVariant
            opacity: 0.55
        }

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Theme.spacingS
            spacing: Theme.spacingXS

            DankIcon {
                name: section.controller.completedExpanded ? "expand_more" : "chevron_right"
                size: 18
                color: Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: "Completed (" + section.pluginRoot.filteredTodos("done").length + ")"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: headerArea
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: clearButton.visible ? clearButton.left : parent.right
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: section.controller.completedExpanded = !section.controller.completedExpanded
        }

        Item {
            id: clearButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: visible ? 112 : 0
            height: 32
            visible: section.controller.completedExpanded && section.pluginRoot.doneCount > 0

            StyledText {
                anchors.centerIn: parent
                text: "Clear completed"
                font.pixelSize: Theme.fontSizeSmall
                color: clearArea.containsMouse ? Theme.error : Theme.surfaceVariantText
            }

            MouseArea {
                id: clearArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: section.pluginRoot.clearCompleted()
            }
        }
    }

    Item {
        width: parent.width
        height: Math.min(180, Math.max(48, completedList.contentHeight))
        visible: section.controller.completedExpanded

        ListView {
            id: completedList
            anchors.fill: parent
            spacing: 0
            clip: true
            model: section.pluginRoot.filteredTodos("done")

            ScrollBar.vertical: ScrollBar {
                id: completedScrollBar
                policy: ScrollBar.AsNeeded
                visible: completedList.contentHeight > completedList.height
                width: 6
                minimumSize: 0.1
                contentItem: Rectangle {
                    radius: width / 2
                    color: Theme.primary
                    opacity: parent.pressed ? 0.9 : (parent.hovered ? 0.75 : 0.5)
                }
                background: Rectangle {
                    radius: width / 2
                    color: Theme.surfaceContainerHighest
                    opacity: 0.3
                }
            }

            delegate: TodoTaskRowV2 {
                width: completedList.width - (completedScrollBar.visible ? completedScrollBar.width + Theme.spacingS : 0)
                height: implicitHeight
                pluginRoot: section.pluginRoot
                controller: section.controller
                taskData: modelData
                taskText: String(modelData.text || "")
                mode: "completed"
                dragEnabled: false
            }

            StyledText {
                anchors.centerIn: parent
                visible: completedList.count === 0
                text: section.pluginRoot.searchQuery ? "No matching completed tasks" : "No completed tasks"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }
    }
}
