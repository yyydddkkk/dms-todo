// Hallmark · redesign: hierarchical enlarged todo card v6 · tone: utilitarian · theme: DMS dynamic
// Pre-emit critique: P5 H5 E4 S5 R5 V5 · contrast: delegated to Theme tokens
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: panel

    required property var pluginRoot
    property var targetScreen: null
    property bool shown: false
    property string searchQuery: ""
    property string completedPeriod: "all"
    property string customStartDate: ""
    property string customEndDate: ""
    property string rangeTarget: "start"
    property bool rangePickerOpen: false

    signal closeRequested

    readonly property var activeTasks: buildActiveTasks()
    readonly property var completedTasks: buildCompletedTasks()

    screen: targetScreen
    visible: shown
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.namespace: "dms:dankTodo:expanded-card-v5"
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    function matchesSearch(todo) {
        const query = String(searchQuery || "").trim().toLowerCase()
        if (!query)
            return true
        const tags = todo.tags ? todo.tags.join(" ") : ""
        return (String(todo.text || "") + " " + String(todo.description || "") + " " + tags).toLowerCase().indexOf(query) !== -1
    }

    function buildActiveTasks() {
        pluginRoot.revision
        return pluginRoot.todos.filter(todo => !todo.deletedAt && !todo.completed && matchesSearch(todo))
    }

    function buildCompletedTasks() {
        pluginRoot.revision
        return pluginRoot.completedTasksForPeriod(completedPeriod, new Date(), customStartDate, customEndDate).filter(matchesSearch)
    }

    function initializeCustomRange() {
        if (customStartDate && customEndDate)
            return
        const end = new Date()
        const start = new Date(end)
        start.setDate(start.getDate() - 6)
        customStartDate = pluginRoot.localDateKey(start)
        customEndDate = pluginRoot.localDateKey(end)
    }

    function selectCompletedPeriod(period) {
        completedPeriod = period
        if (period === "custom")
            initializeCustomRange()
    }

    function openRangePicker(target) {
        initializeCustomRange()
        rangeTarget = target
        const key = target === "start" ? customStartDate : customEndDate
        const date = new Date(key + "T12:00:00")
        rangeCalendar.displayDate = date
        rangeCalendar.selectedDate = date
        rangePickerOpen = true
    }

    function closeCard() {
        rangePickerOpen = false
        closeRequested()
    }

    function taskMeta(todo) {
        return pluginRoot.taskMetaText(todo)
    }

    onShownChanged: {
        if (shown) {
            pluginRoot.reloadTodos()
            Qt.callLater(() => keyboardRoot.forceActiveFocus())
        } else {
            rangePickerOpen = false
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.withAlpha(Theme.background, 0.62)

        MouseArea {
            anchors.fill: parent
            onClicked: panel.closeCard()
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: Math.min(860, parent.width - Theme.spacingXL * 2)
            height: Math.min(920, parent.height - Theme.spacingXL * 2)
            radius: Theme.cornerRadius * 1.5
            color: Theme.surface
            border.width: 1
            border.color: Theme.outlineVariant

            MouseArea {
                anchors.fill: parent
            }

            Item {
                id: keyboardRoot
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                focus: panel.shown

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        if (panel.rangePickerOpen)
                            panel.rangePickerOpen = false
                        else
                            panel.closeCard()
                        event.accepted = true
                    }
                }

                Item {
                    id: header
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 52

                    Column {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        StyledText {
                            text: "Todos"
                            font.pixelSize: Theme.fontSizeLarge + 4
                            font.weight: Font.DemiBold
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: panel.pluginRoot.activeCount + " active  ·  " + panel.pluginRoot.doneCount + " completed"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXS

                        DankActionButton {
                            buttonSize: 44
                            iconSize: 20
                            iconName: "download"
                            iconColor: Theme.primary
                            tooltipText: "Export Markdown"
                            onClicked: panel.pluginRoot.exportMarkdown()
                        }

                        DankActionButton {
                            buttonSize: 44
                            iconSize: 20
                            iconName: "close"
                            iconColor: Theme.surfaceText
                            tooltipText: "Close"
                            onClicked: panel.closeCard()
                        }
                    }
                }

                DankTextField {
                    id: expandedSearch
                    anchors.top: header.bottom
                    anchors.topMargin: Theme.spacingS
                    anchors.left: parent.left
                    anchors.right: parent.right
                    placeholderText: "Search tasks, details, and tags"
                    text: panel.searchQuery
                    onTextChanged: panel.searchQuery = text
                }

                Item {
                    id: activeSection
                    anchors.top: expandedSearch.bottom
                    anchors.topMargin: Theme.spacingL
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: Math.max(220, (parent.height - y - Theme.spacingL) * 0.5)

                    Row {
                        id: activeHeader
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 36

                        StyledText {
                            text: "Active"
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: panel.activeTasks.length + (panel.pluginRoot.todos.filter(todo => !todo.deletedAt && !todo.completed && todo.inProgress).length ? ("  ·  " + panel.pluginRoot.todos.filter(todo => !todo.deletedAt && !todo.completed && todo.inProgress).length + " in progress") : "")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }

                    ListView {
                        id: activeList
                        anchors.top: activeHeader.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        clip: true
                        spacing: Theme.spacingXXS
                        model: panel.activeTasks

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            width: 6
                            contentItem: Rectangle {
                                radius: width / 2
                                color: Theme.primary
                                opacity: parent.pressed ? 0.9 : (parent.hovered ? 0.75 : 0.45)
                            }
                        }

                        delegate: Rectangle {
                            id: activeRow
                            required property var modelData
                            property var taskObject: modelData
                            property string taskTitle: String(modelData && modelData.text !== undefined ? modelData.text : "")
                            property string taskDescription: String(modelData && modelData.description !== undefined ? modelData.description : "")
                            readonly property bool inProgress: Boolean(taskObject.inProgress)

                            width: activeList.width - 8
                            height: taskDescription ? 60 : 48
                            radius: Theme.cornerRadius / 2
                            color: activeArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHigh, 0.55) : "transparent"

                            MouseArea {
                                id: activeArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }

                            Item {
                                id: activeStatus
                                width: 44
                                height: 44
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingXS
                                anchors.verticalCenter: parent.verticalCenter

                                DankIcon {
                                    anchors.centerIn: parent
                                    visible: !activeRow.inProgress
                                    name: "radio_button_unchecked"
                                    size: 18
                                    color: Theme.surfaceVariantText
                                }

                                Rectangle {
                                    width: 14
                                    height: 14
                                    radius: 7
                                    anchors.centerIn: parent
                                    visible: activeRow.inProgress
                                    color: Theme.primary
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    ToolTip.visible: containsMouse
                                    ToolTip.delay: 800
                                    ToolTip.text: activeRow.inProgress ? "Left-click to complete · Right-click to cancel" : "Start task"
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.RightButton) {
                                            if (activeRow.inProgress)
                                                panel.pluginRoot.cancelTodoProgress(activeRow.taskObject.id)
                                            return
                                        }
                                        panel.pluginRoot.toggleTodo(activeRow.taskObject.id)
                                    }
                                }
                            }

                            Column {
                                anchors.left: activeStatus.right
                                anchors.leftMargin: Theme.spacingXS
                                anchors.right: activeMeta.left
                                anchors.rightMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                StyledText {
                                    width: parent.width
                                    text: activeRow.taskTitle
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: activeRow.inProgress ? Font.Medium : Font.Normal
                                    color: Theme.surfaceText
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    width: parent.width
                                    visible: activeRow.taskDescription.length > 0
                                    text: activeRow.taskDescription.replace(/\s+/g, " ")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    elide: Text.ElideRight
                                }
                            }

                            StyledText {
                                id: activeMeta
                                anchors.right: activeDelete.left
                                anchors.rightMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(150, implicitWidth)
                                text: panel.taskMeta(activeRow.taskObject)
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                            }

                            Item {
                                id: activeDelete
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingXS
                                anchors.verticalCenter: parent.verticalCenter
                                width: 44
                                height: 44

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: "delete_outline"
                                    size: 17
                                    color: activeDeleteArea.containsMouse ? Theme.error : Theme.surfaceVariantText
                                    opacity: activeDeleteArea.containsMouse ? 1 : 0.55
                                }

                                MouseArea {
                                    id: activeDeleteArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    ToolTip.visible: containsMouse
                                    ToolTip.delay: 800
                                    ToolTip.text: "Move to trash"
                                    onClicked: panel.pluginRoot.deleteTodo(activeRow.taskObject.id)
                                }
                            }
                        }

                        StyledText {
                            anchors.centerIn: parent
                            visible: activeList.count === 0
                            text: panel.searchQuery ? "No matching active tasks" : "No active tasks"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }
                }

                Rectangle {
                    id: sectionDivider
                    anchors.top: activeSection.bottom
                    anchors.topMargin: Theme.spacingM
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Theme.outlineVariant
                    opacity: 0.55
                }

                Item {
                    id: completedSection
                    anchors.top: sectionDivider.bottom
                    anchors.topMargin: Theme.spacingS
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom

                    Row {
                        id: completedHeader
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 36

                        StyledText {
                            text: "Completed"
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: panel.completedTasks.length + " shown  ·  " + panel.pluginRoot.doneCount + " total"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }

                    Row {
                        id: periodRow
                        anchors.top: completedHeader.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 40
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
                                width: periodRow.choiceWidth
                                height: parent.height
                                activeFocusOnTab: true

                                StyledText {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: panel.completedPeriod === modelData.key ? Font.Medium : Font.Normal
                                    color: panel.completedPeriod === modelData.key || periodArea.containsMouse ? Theme.primary : Theme.surfaceVariantText
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 2
                                    radius: 1
                                    visible: panel.completedPeriod === modelData.key || parent.activeFocus
                                    color: Theme.primary
                                }

                                Keys.onReturnPressed: panel.selectCompletedPeriod(modelData.key)
                                MouseArea {
                                    id: periodArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: panel.selectCompletedPeriod(modelData.key)
                                }
                            }
                        }
                    }

                    Row {
                        id: customRangeRow
                        anchors.top: periodRow.bottom
                        anchors.topMargin: visible ? Theme.spacingS : 0
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: visible ? 44 : 0
                        visible: panel.completedPeriod === "custom"
                        spacing: Theme.spacingS

                        Repeater {
                            model: [
                                { key: "start", label: "From" },
                                { key: "end", label: "To" }
                            ]

                            Rectangle {
                                width: (parent.width - parent.spacing) / 2
                                height: parent.height
                                radius: Theme.cornerRadius
                                color: rangeArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh

                                StyledText {
                                    anchors.centerIn: parent
                                    text: modelData.label + "  " + (modelData.key === "start" ? panel.customStartDate : panel.customEndDate)
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                }

                                MouseArea {
                                    id: rangeArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: panel.openRangePicker(modelData.key)
                                }
                            }
                        }
                    }

                    ListView {
                        id: completedList
                        anchors.top: customRangeRow.bottom
                        anchors.topMargin: Theme.spacingS
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        clip: true
                        spacing: Theme.spacingXXS
                        model: panel.completedTasks

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            width: 6
                            contentItem: Rectangle {
                                radius: width / 2
                                color: Theme.primary
                                opacity: parent.pressed ? 0.9 : (parent.hovered ? 0.75 : 0.45)
                            }
                        }

                        delegate: Rectangle {
                            id: completedRow
                            required property var modelData
                            property var taskObject: modelData
                            property string taskTitle: String(modelData && modelData.text !== undefined ? modelData.text : "")
                            property string taskDescription: String(modelData && modelData.description !== undefined ? modelData.description : "")
                            readonly property int hierarchyDepth: panel.pluginRoot.depthWithinTasks(taskObject.id, panel.completedTasks)

                            width: completedList.width - 8
                            height: taskDescription ? 60 : 48
                            radius: Theme.cornerRadius / 2
                            color: completedArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHigh, 0.55) : "transparent"

                            MouseArea {
                                id: completedArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }

                            Item {
                                id: completedStatus
                                width: 44
                                height: 44
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingXS + completedRow.hierarchyDepth * 20
                                anchors.verticalCenter: parent.verticalCenter

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: "check_circle"
                                    size: 18
                                    color: Theme.primary
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    ToolTip.visible: containsMouse
                                    ToolTip.delay: 800
                                    ToolTip.text: "Reset task"
                                    onClicked: panel.pluginRoot.toggleTodo(completedRow.taskObject.id)
                                }
                            }

                            Column {
                                anchors.left: completedStatus.right
                                anchors.leftMargin: Theme.spacingXS
                                anchors.right: completedDate.left
                                anchors.rightMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                StyledText {
                                    width: parent.width
                                    text: completedRow.taskTitle
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.strikeout: true
                                    color: Theme.surfaceText
                                    opacity: 0.68
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    width: parent.width
                                    visible: completedRow.taskDescription.length > 0
                                    text: completedRow.taskDescription.replace(/\s+/g, " ")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    elide: Text.ElideRight
                                }
                            }

                            StyledText {
                                id: completedDate
                                anchors.right: completedDelete.left
                                anchors.rightMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                text: completedRow.taskObject.completedAt ? new Date(completedRow.taskObject.completedAt).toLocaleDateString(Qt.locale(), "MMM d") : ""
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }

                            Item {
                                id: completedDelete
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingXS
                                anchors.verticalCenter: parent.verticalCenter
                                width: 44
                                height: 44

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: "delete_outline"
                                    size: 17
                                    color: completedDeleteArea.containsMouse ? Theme.error : Theme.surfaceVariantText
                                    opacity: completedDeleteArea.containsMouse ? 1 : 0.55
                                }

                                MouseArea {
                                    id: completedDeleteArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    ToolTip.visible: containsMouse
                                    ToolTip.delay: 800
                                    ToolTip.text: "Move to trash"
                                    onClicked: panel.pluginRoot.deleteTodo(completedRow.taskObject.id)
                                }
                            }
                        }

                        StyledText {
                            anchors.centerIn: parent
                            visible: completedList.count === 0
                            text: panel.searchQuery ? "No matching completed tasks" : "No completed tasks in this period"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            z: 100
            visible: panel.rangePickerOpen
            color: Theme.withAlpha(Theme.background, 0.64)

            MouseArea {
                anchors.fill: parent
                onClicked: panel.rangePickerOpen = false
            }

            Rectangle {
                anchors.centerIn: parent
                width: 400
                height: 344
                radius: Theme.cornerRadius
                color: Theme.surfaceContainer
                border.width: 1
                border.color: Theme.outlineVariant

                MouseArea {
                    anchors.fill: parent
                }

                StyledText {
                    anchors.top: parent.top
                    anchors.topMargin: Theme.spacingM
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingL
                    text: panel.rangeTarget === "start" ? "Choose start date" : "Choose end date"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }

                DankActionButton {
                    anchors.top: parent.top
                    anchors.topMargin: Theme.spacingS
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingS
                    buttonSize: 36
                    iconSize: 18
                    iconName: "close"
                    iconColor: Theme.surfaceText
                    onClicked: panel.rangePickerOpen = false
                }

                TodoCalendarGrid {
                    id: rangeCalendar
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Theme.spacingM
                    height: implicitHeight
                    showTaskCounts: false
                    onDatePicked: value => {
                        const picked = panel.pluginRoot.localDateKey(value)
                        if (panel.rangeTarget === "start") {
                            panel.customStartDate = picked
                            if (picked > panel.customEndDate)
                                panel.customEndDate = picked
                        } else {
                            panel.customEndDate = picked
                            if (picked < panel.customStartDate)
                                panel.customStartDate = picked
                        }
                        panel.rangePickerOpen = false
                    }
                }
            }
        }
    }
}
