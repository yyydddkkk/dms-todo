// Hallmark · component: completed time filter v6 · genre: modern-minimal · theme: DMS dynamic
// Pre-emit critique: P5 H4 E4 S5 R5 V4 · contrast: delegated to Theme tokens
import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets

Column {
    id: section

    required property var pluginRoot
    required property var controller

    property string customStartDate: ""
    property string customEndDate: ""
    property string rangeTarget: "start"
    property bool rangeCalendarOpen: false
    readonly property var visibleTasks: pluginRoot.completedTasksForPeriod(controller.completedTimeFilter, new Date(), customStartDate, customEndDate)

    function initializeCustomRange() {
        if (customStartDate && customEndDate)
            return
        const end = new Date()
        const start = new Date(end)
        start.setDate(start.getDate() - 6)
        customStartDate = pluginRoot.localDateKey(start)
        customEndDate = pluginRoot.localDateKey(end)
    }

    function selectPeriod(period) {
        controller.completedTimeFilter = period
        rangeCalendarOpen = false
        if (period === "custom")
            initializeCustomRange()
    }

    function openRangeCalendar(target) {
        initializeCustomRange()
        rangeTarget = target
        const value = target === "start" ? customStartDate : customEndDate
        const date = new Date(value + "T12:00:00")
        rangeCalendar.displayDate = date
        rangeCalendar.selectedDate = date
        rangeCalendarOpen = true
    }

    function emptyText() {
        if (controller.completedTimeFilter === "thisWeek")
            return "No tasks completed this week"
        if (controller.completedTimeFilter === "lastWeek")
            return "No tasks completed last week"
        if (controller.completedTimeFilter === "thisMonth")
            return "No tasks completed this month"
        if (controller.completedTimeFilter === "custom")
            return "No tasks completed in this range"
        return "No completed tasks"
    }

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
            visible: section.controller.completedExpanded && section.controller.completedTimeFilter === "all" && section.pluginRoot.doneCount > 0

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

    Column {
        width: parent.width
        spacing: Theme.spacingXS
        visible: section.controller.completedExpanded

        Row {
            id: periodChoices
            width: parent.width
            height: 44
            spacing: Theme.spacingXXS
            property real choiceWidth: (width - spacing * 4) / 5

            Repeater {
                model: [
                    { key: "all", label: "All" },
                    { key: "thisWeek", label: "This week" },
                    { key: "lastWeek", label: "Last week" },
                    { key: "thisMonth", label: "This month" },
                    { key: "custom", label: "Custom" }
                ]

                Item {
                    width: periodChoices.choiceWidth
                    height: parent.height
                    activeFocusOnTab: true

                    StyledText {
                        anchors.centerIn: parent
                        text: modelData.label
                        font.pixelSize: Theme.fontSizeSmall * 0.9
                        font.weight: section.controller.completedTimeFilter === modelData.key ? Font.Medium : Font.Normal
                        color: section.controller.completedTimeFilter === modelData.key || periodArea.containsMouse ? Theme.primary : Theme.surfaceVariantText
                        opacity: periodArea.pressed ? 0.72 : 1
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 2
                        radius: 1
                        visible: section.controller.completedTimeFilter === modelData.key || parent.activeFocus
                        color: Theme.primary
                    }

                    Keys.onReturnPressed: section.selectPeriod(modelData.key)
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Space) {
                            section.selectPeriod(modelData.key)
                            event.accepted = true
                        }
                    }

                    MouseArea {
                        id: periodArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: section.selectPeriod(modelData.key)
                    }
                }
            }
        }

        Row {
            width: parent.width
            height: 44
            spacing: Theme.spacingS
            visible: section.controller.completedTimeFilter === "custom"

            Repeater {
                model: [
                    { key: "start", label: "From" },
                    { key: "end", label: "To" }
                ]

                Rectangle {
                    width: (parent.width - parent.spacing) / 2
                    height: parent.height
                    radius: Theme.cornerRadius
                    activeFocusOnTab: true
                    color: rangeArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                    border.width: section.rangeCalendarOpen && section.rangeTarget === modelData.key ? 1 : 0
                    border.color: Theme.primary

                    StyledText {
                        anchors.centerIn: parent
                        text: modelData.label + "  " + (modelData.key === "start" ? section.customStartDate : section.customEndDate)
                        font.pixelSize: Theme.fontSizeSmall
                        color: section.rangeCalendarOpen && section.rangeTarget === modelData.key ? Theme.primary : Theme.surfaceText
                        opacity: rangeArea.pressed ? 0.72 : 1
                    }

                    Keys.onReturnPressed: section.openRangeCalendar(modelData.key)
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Space) {
                            section.openRangeCalendar(modelData.key)
                            event.accepted = true
                        }
                    }

                    MouseArea {
                        id: rangeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: section.openRangeCalendar(modelData.key)
                    }
                }
            }
        }

        TodoCalendarGrid {
            id: rangeCalendar
            width: parent.width
            height: visible ? implicitHeight : 0
            visible: section.controller.completedTimeFilter === "custom" && section.rangeCalendarOpen
            showTaskCounts: false
            onDatePicked: value => {
                const picked = section.pluginRoot.localDateKey(value)
                if (section.rangeTarget === "start") {
                    section.customStartDate = picked
                    if (picked > section.customEndDate)
                        section.customEndDate = picked
                } else {
                    section.customEndDate = picked
                    if (picked < section.customStartDate)
                        section.customStartDate = picked
                }
                section.rangeCalendarOpen = false
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
            model: section.visibleTasks

            StyledText {
                anchors.centerIn: parent
                visible: completedList.count === 0
                text: section.emptyText()
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

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
