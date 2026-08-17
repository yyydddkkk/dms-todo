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
            anchors.leftMargin: Theme.spacingS
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingXS

            DankIcon {
                name: section.controller.completedExpanded ? "expand_more" : "chevron_right"
                size: 18
                color: Theme.surfaceVariantText
            }

            StyledText {
                text: "Completed (" + section.pluginRoot.filteredTodos("done").length + ")"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.surfaceVariantText
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
            height: 36
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
        height: Math.min(220, Math.max(48, completedList.contentHeight))
        visible: section.controller.completedExpanded

        ListView {
            id: completedList
            anchors.fill: parent
            clip: true
            spacing: Theme.spacingXXS
            model: section.pluginRoot.filteredTodos("done")

            ScrollBar.vertical: ScrollBar {
                id: completedScrollBar
                policy: ScrollBar.AsNeeded
                visible: completedList.contentHeight > completedList.height
                width: 6
                contentItem: Rectangle {
                    radius: width / 2
                    color: Theme.primary
                    opacity: parent.pressed ? 0.9 : (parent.hovered ? 0.75 : 0.5)
                }
            }

            delegate: Item {
                id: completedRow
                width: completedList.width - (completedScrollBar.visible ? completedScrollBar.width + Theme.spacingS : 0)
                height: actionsOpen ? 84 : 48

                property string taskId: String(modelData.id || "")
                property string taskTitle: String(modelData.text || "")
                property bool actionsOpen: false

                Rectangle {
                    anchors.fill: parent
                    color: rowArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHigh, 0.55) : "transparent"
                }

                Row {
                    id: mainRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 48
                    anchors.leftMargin: Theme.spacingXS
                    anchors.rightMargin: Theme.spacingXS
                    spacing: Theme.spacingXS

                    Item {
                        id: checkButton
                        width: 40
                        height: 40
                        anchors.verticalCenter: parent.verticalCenter

                        DankIcon {
                            anchors.centerIn: parent
                            name: "check_circle"
                            size: 18
                            color: Theme.primary
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: section.pluginRoot.toggleTodo(completedRow.taskId)
                        }
                    }

                    StyledText {
                        width: parent.width - checkButton.width - moreButton.width - parent.spacing * 2
                        height: parent.height
                        text: completedRow.taskTitle
                        font.pixelSize: Theme.fontSizeMedium
                        font.strikeout: true
                        color: Theme.surfaceText
                        opacity: 0.72
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }

                    Item {
                        id: moreButton
                        width: 40
                        height: 40
                        anchors.verticalCenter: parent.verticalCenter

                        DankIcon {
                            anchors.centerIn: parent
                            name: completedRow.actionsOpen ? "expand_less" : "more_vert"
                            size: 17
                            color: Theme.surfaceVariantText
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: completedRow.actionsOpen = !completedRow.actionsOpen
                        }
                    }
                }

                MouseArea {
                    id: rowArea
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 48
                    acceptedButtons: Qt.NoButton
                    hoverEnabled: true
                    z: -1
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingXS
                    anchors.top: mainRow.bottom
                    height: 36
                    spacing: Theme.spacingS
                    visible: completedRow.actionsOpen

                    Item {
                        width: 64
                        height: parent.height

                        StyledText {
                            anchors.centerIn: parent
                            text: "Edit"
                            font.pixelSize: Theme.fontSizeSmall
                            color: editArea.containsMouse ? Theme.primary : Theme.surfaceVariantText
                        }

                        MouseArea {
                            id: editArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: section.controller.startEditing(completedRow.taskId)
                        }
                    }

                    Item {
                        width: 64
                        height: parent.height

                        StyledText {
                            anchors.centerIn: parent
                            text: "Delete"
                            font.pixelSize: Theme.fontSizeSmall
                            color: deleteArea.containsMouse ? Theme.error : Theme.surfaceVariantText
                        }

                        MouseArea {
                            id: deleteArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: section.pluginRoot.deleteTodo(completedRow.taskId)
                        }
                    }
                }

            }
        }
    }
}
