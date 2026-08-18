// Hallmark · macrostructure: Workbench · tone: utilitarian · theme: DMS dynamic
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
    property string viewFilter: "all"
    property string searchQuery: ""
    property string selectedId: ""
    property string completedPeriod: "all"
    property string customStartDate: ""
    property string customEndDate: ""
    property string rangeTarget: "start"
    property bool rangePickerOpen: false

    signal closeRequested

    readonly property var filteredTasks: buildFilteredTasks()
    readonly property var selectedTask: {
        pluginRoot.revision
        return pluginRoot.todos.find(todo => todo.id === selectedId) || null
    }

    screen: targetScreen
    visible: shown
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.namespace: "dms:dankTodo:task-center-v2"
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    function buildFilteredTasks() {
        pluginRoot.revision
        let tasks
        if (viewFilter === "completed") {
            tasks = pluginRoot.completedTasksForPeriod(completedPeriod, new Date(), customStartDate, customEndDate)
        } else if (viewFilter === "trash") {
            tasks = pluginRoot.todos.filter(todo => Boolean(todo.deletedAt))
        } else if (viewFilter === "active") {
            tasks = pluginRoot.todos.filter(todo => !todo.deletedAt && !todo.completed && !todo.inProgress)
        } else if (viewFilter === "progress") {
            tasks = pluginRoot.todos.filter(todo => !todo.deletedAt && !todo.completed && todo.inProgress)
        } else {
            tasks = pluginRoot.todos.filter(todo => !todo.deletedAt)
        }

        const query = String(searchQuery || "").trim().toLowerCase()
        if (!query)
            return tasks
        return tasks.filter(todo => {
            const tags = todo.tags ? todo.tags.join(" ") : ""
            return (String(todo.text || "") + " " + String(todo.description || "") + " " + tags).toLowerCase().indexOf(query) !== -1
        })
    }

    function countForFilter(filter) {
        pluginRoot.revision
        if (filter === "all")
            return pluginRoot.visibleCount
        if (filter === "active")
            return pluginRoot.todos.filter(todo => !todo.deletedAt && !todo.completed && !todo.inProgress).length
        if (filter === "progress")
            return pluginRoot.todos.filter(todo => !todo.deletedAt && !todo.completed && todo.inProgress).length
        if (filter === "completed")
            return pluginRoot.doneCount
        return pluginRoot.deletedCount
    }

    function filterLabel(filter) {
        if (filter === "active")
            return "Not started"
        if (filter === "progress")
            return "In progress"
        if (filter === "completed")
            return "Completed"
        if (filter === "trash")
            return "Trash"
        return "All tasks"
    }

    function statusLabel(todo) {
        if (!todo)
            return ""
        if (todo.deletedAt)
            return "In trash"
        if (todo.completed)
            return "Completed"
        if (todo.inProgress)
            return "In progress"
        return "Not started"
    }

    function taskMeta(todo) {
        if (!todo)
            return ""
        if (todo.completedAt)
            return "Completed " + new Date(todo.completedAt).toLocaleDateString(Qt.locale(), "MMM d, yyyy")
        if (todo.deletedAt)
            return "Deleted " + new Date(todo.deletedAt).toLocaleDateString(Qt.locale(), "MMM d, yyyy")
        return pluginRoot.taskMetaText(todo)
    }

    function ensureSelection() {
        if (filteredTasks.some(todo => todo.id === selectedId))
            return
        selectedId = filteredTasks.length ? filteredTasks[0].id : ""
    }

    function selectFilter(filter) {
        viewFilter = filter
        rangePickerOpen = false
        Qt.callLater(ensureSelection)
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
        Qt.callLater(ensureSelection)
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

    function closePanel() {
        rangePickerOpen = false
        closeRequested()
    }

    function cycleSelectedTask() {
        if (selectedTask && !selectedTask.deletedAt)
            pluginRoot.toggleTodo(selectedTask.id)
    }

    onShownChanged: {
        if (shown) {
            pluginRoot.reloadTodos()
            Qt.callLater(ensureSelection)
            Qt.callLater(() => contentRoot.forceActiveFocus())
        } else {
            rangePickerOpen = false
        }
    }

    onFilteredTasksChanged: Qt.callLater(ensureSelection)

    Connections {
        target: pluginRoot
        function onRevisionChanged() {
            Qt.callLater(panel.ensureSelection)
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.background

        Item {
            id: contentRoot
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: Theme.spacingXL
            anchors.bottomMargin: Theme.spacingXL
            width: Math.min(1180, parent.width - Theme.spacingXL * 2)
            focus: panel.shown

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    if (panel.rangePickerOpen)
                        panel.rangePickerOpen = false
                    else
                        panel.closePanel()
                    event.accepted = true
                }
            }

            Item {
                id: header
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 56

                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    StyledText {
                        text: "Task center"
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
                    spacing: Theme.spacingM

                    DankTextField {
                        id: fullscreenSearch
                        width: 320
                        placeholderText: "Search tasks, details, and tags"
                        text: panel.searchQuery
                        onTextChanged: panel.searchQuery = text
                    }

                    DankActionButton {
                        buttonSize: 44
                        iconSize: 20
                        iconName: "close"
                        iconColor: Theme.surfaceText
                        tooltipText: "Close task center"
                        onClicked: panel.closePanel()
                    }
                }
            }

            Item {
                id: workbench
                anchors.top: header.bottom
                anchors.topMargin: Theme.spacingL
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                Item {
                    id: sidebar
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    width: 180

                    Column {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: Theme.spacingXS

                        Repeater {
                            model: ["all", "active", "progress", "completed", "trash"]

                            Item {
                                width: parent.width
                                height: 44
                                activeFocusOnTab: true

                                Row {
                                    anchors.fill: parent
                                    spacing: Theme.spacingS

                                    Rectangle {
                                        width: 5
                                        height: 5
                                        radius: 3
                                        color: panel.viewFilter === modelData ? Theme.primary : "transparent"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        width: parent.width - 5 - countText.width - parent.spacing * 2
                                        text: panel.filterLabel(modelData)
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: panel.viewFilter === modelData ? Font.Medium : Font.Normal
                                        color: panel.viewFilter === modelData || navArea.containsMouse ? Theme.primary : Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        id: countText
                                        text: panel.countForFilter(modelData)
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 1
                                    visible: parent.activeFocus
                                    color: Theme.primary
                                }

                                Keys.onReturnPressed: panel.selectFilter(modelData)
                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Space) {
                                        panel.selectFilter(modelData)
                                        event.accepted = true
                                    }
                                }

                                MouseArea {
                                    id: navArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: panel.selectFilter(modelData)
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: sidebar.right
                    anchors.leftMargin: Theme.spacingM
                    width: 1
                    color: Theme.outlineVariant
                    opacity: 0.55
                }

                Item {
                    id: detailPane
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    width: Math.min(340, parent.width * 0.29)

                    Rectangle {
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        width: 1
                        color: Theme.outlineVariant
                        opacity: 0.55
                    }

                    Column {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingXL
                        spacing: Theme.spacingM

                        StyledText {
                            text: "Details"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceVariantText
                        }

                        StyledText {
                            width: parent.width
                            text: panel.selectedTask ? String(panel.selectedTask.text || "") : "Select a task"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.DemiBold
                            color: Theme.surfaceText
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }

                        StyledText {
                            width: parent.width
                            visible: Boolean(panel.selectedTask)
                            text: panel.statusLabel(panel.selectedTask)
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: panel.selectedTask && panel.selectedTask.inProgress ? Theme.primary : Theme.surfaceVariantText
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.outlineVariant
                            opacity: 0.5
                            visible: Boolean(panel.selectedTask)
                        }

                        ScrollView {
                            width: parent.width
                            height: Math.max(80, parent.height - detailActions.height - 190)
                            clip: true
                            visible: Boolean(panel.selectedTask)
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                            ScrollBar.vertical.policy: ScrollBar.AsNeeded

                            StyledText {
                                width: parent.width
                                text: panel.selectedTask && panel.selectedTask.description ? panel.selectedTask.description : "No details"
                                font.pixelSize: Theme.fontSizeMedium
                                color: panel.selectedTask && panel.selectedTask.description ? Theme.surfaceText : Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                            }
                        }

                        StyledText {
                            width: parent.width
                            visible: Boolean(panel.selectedTask)
                            text: panel.taskMeta(panel.selectedTask)
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            wrapMode: Text.WordWrap
                        }

                        Column {
                            id: detailActions
                            width: parent.width
                            spacing: Theme.spacingS
                            visible: Boolean(panel.selectedTask)

                            Rectangle {
                                width: parent.width
                                height: 44
                                radius: Theme.cornerRadius
                                color: primaryActionArea.pressed ? Theme.primaryHover : Theme.primary

                                StyledText {
                                    anchors.centerIn: parent
                                    text: {
                                        if (!panel.selectedTask)
                                            return ""
                                        if (panel.selectedTask.deletedAt)
                                            return "Restore task"
                                        if (panel.selectedTask.completed)
                                            return "Reset task"
                                        if (panel.selectedTask.inProgress)
                                            return "Complete task"
                                        return "Start task"
                                    }
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: Theme.onPrimary
                                }

                                MouseArea {
                                    id: primaryActionArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!panel.selectedTask)
                                            return
                                        if (panel.selectedTask.deletedAt)
                                            panel.pluginRoot.restoreTodo(panel.selectedTask.id)
                                        else
                                            panel.cycleSelectedTask()
                                    }
                                }
                            }

                            Item {
                                width: parent.width
                                height: 44

                                StyledText {
                                    anchors.centerIn: parent
                                    text: panel.selectedTask && panel.selectedTask.deletedAt ? "Delete permanently" : "Move to trash"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: dangerArea.containsMouse ? Theme.error : Theme.surfaceVariantText
                                }

                                MouseArea {
                                    id: dangerArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!panel.selectedTask)
                                            return
                                        if (panel.selectedTask.deletedAt)
                                            panel.pluginRoot.permanentlyDeleteTodo(panel.selectedTask.id)
                                        else
                                            panel.pluginRoot.deleteTodo(panel.selectedTask.id)
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    id: listPane
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: sidebar.right
                    anchors.leftMargin: Theme.spacingXL * 2
                    anchors.right: detailPane.left
                    anchors.rightMargin: Theme.spacingXL

                    Column {
                        id: listHeader
                        width: parent.width
                        spacing: Theme.spacingS

                        Row {
                            width: parent.width
                            height: 36

                            StyledText {
                                text: panel.filterLabel(panel.viewFilter)
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: panel.filteredTasks.length + " tasks"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }

                        Row {
                            id: completedPeriodRow
                            width: parent.width
                            height: visible ? 40 : 0
                            visible: panel.viewFilter === "completed"
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
                                    width: completedPeriodRow.choiceWidth
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
                            width: parent.width
                            height: visible ? 44 : 0
                            visible: panel.viewFilter === "completed" && panel.completedPeriod === "custom"
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
                                    activeFocusOnTab: true
                                    color: rangeArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: modelData.label + "  " + (modelData.key === "start" ? panel.customStartDate : panel.customEndDate)
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                    }

                                    Keys.onReturnPressed: panel.openRangePicker(modelData.key)
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
                    }

                    ListView {
                        id: fullscreenList
                        anchors.top: listHeader.bottom
                        anchors.topMargin: Theme.spacingS
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        clip: true
                        spacing: Theme.spacingXXS
                        model: panel.filteredTasks

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
                            id: taskRow
                            required property var modelData
                            property var taskObject: modelData
                            property string taskTitle: String(modelData && modelData.text !== undefined ? modelData.text : "")
                            property string taskDescription: String(modelData && modelData.description !== undefined ? modelData.description : "")
                            readonly property bool selected: panel.selectedId === taskObject.id
                            readonly property bool completed: Boolean(taskObject.completed)
                            readonly property bool inProgress: !completed && Boolean(taskObject.inProgress)
                            readonly property bool inTrash: Boolean(taskObject.deletedAt)

                            width: fullscreenList.width - 8
                            height: taskDescription ? 68 : 56
                            radius: Theme.cornerRadius / 2
                            color: selected ? Theme.withAlpha(Theme.primary, 0.09) : (rowArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHigh, 0.55) : "transparent")
                            border.width: activeFocus ? 1 : 0
                            border.color: Theme.primary
                            activeFocusOnTab: true

                            MouseArea {
                                id: rowArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    panel.selectedId = taskRow.taskObject.id
                                    taskRow.forceActiveFocus()
                                }
                            }

                            Item {
                                id: statusButton
                                width: 44
                                height: 44
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingXS
                                anchors.verticalCenter: parent.verticalCenter
                                z: 2

                                DankIcon {
                                    anchors.centerIn: parent
                                    visible: taskRow.inTrash || !taskRow.inProgress
                                    name: taskRow.inTrash ? "delete_outline" : (taskRow.completed ? "check_circle" : "radio_button_unchecked")
                                    size: 18
                                    color: taskRow.completed || taskRow.inTrash ? Theme.primary : Theme.surfaceVariantText
                                }

                                Rectangle {
                                    width: 14
                                    height: 14
                                    radius: 7
                                    anchors.centerIn: parent
                                    visible: taskRow.inProgress
                                    color: Theme.primary
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                        panel.selectedId = taskRow.taskObject.id
                                        if (taskRow.inTrash) {
                                            if (mouse.button === Qt.LeftButton)
                                                panel.pluginRoot.restoreTodo(taskRow.taskObject.id)
                                            return
                                        }
                                        if (mouse.button === Qt.RightButton) {
                                            if (taskRow.inProgress)
                                                panel.pluginRoot.cancelTodoProgress(taskRow.taskObject.id)
                                            return
                                        }
                                        panel.pluginRoot.toggleTodo(taskRow.taskObject.id)
                                    }
                                }
                            }

                            Column {
                                anchors.left: statusButton.right
                                anchors.leftMargin: Theme.spacingXS
                                anchors.right: metaText.left
                                anchors.rightMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3

                                StyledText {
                                    width: parent.width
                                    text: taskRow.taskTitle
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: taskRow.inProgress ? Font.Medium : Font.Normal
                                    font.strikeout: taskRow.completed
                                    color: Theme.surfaceText
                                    opacity: taskRow.completed ? 0.68 : 1
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    width: parent.width
                                    visible: taskRow.taskDescription.length > 0
                                    text: taskRow.taskDescription.replace(/\s+/g, " ")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    elide: Text.ElideRight
                                }
                            }

                            StyledText {
                                id: metaText
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(170, implicitWidth)
                                text: panel.taskMeta(taskRow.taskObject)
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            visible: fullscreenList.count === 0
                            spacing: Theme.spacingS

                            DankIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: "search_off"
                                size: 22
                                color: Theme.surfaceVariantText
                            }

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: panel.searchQuery ? "No matching tasks" : "No tasks in this view"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceVariantText
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            z: 100
            visible: panel.rangePickerOpen
            color: Theme.withAlpha(Theme.background, 0.72)

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
