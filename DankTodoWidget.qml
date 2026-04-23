import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    readonly property string defaultStorageDir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/dank-todo"
    readonly property string resolvedStorageDir: {
        const custom = String(pluginData.storagePath || "").trim()
        return custom.length > 0 ? custom : defaultStorageDir
    }
    readonly property string storageFilePath: resolvedStorageDir + "/todos.json"

    function parseIntOr(value, fallback, min) {
        const n = parseInt(value, 10)
        if (isNaN(n))
            return fallback
        return (min !== undefined && n < min) ? min : n
    }

    property int maxItems: parseIntOr(pluginData.maxItems, 200, 10)
    property int maxTextLength: parseIntOr(pluginData.maxTextLength, 500, 40)
    property string countMode: {
        const v = String(pluginData.countMode || "active")
        return (v === "total" || v === "done" || v === "hidden") ? v : "active"
    }

    property var todos: []
    property int revision: 0
    property string filter: "all"

    readonly property int activeCount: {
        revision
        let n = 0
        for (let i = 0; i < todos.length; i++) {
            if (!todos[i].completed)
                n++
        }
        return n
    }
    readonly property int doneCount: {
        revision
        return todos.length - activeCount
    }

    function uid() {
        return Date.now().toString(36) + Math.random().toString(36).substring(2, 8)
    }

    function ensureStorageReady() {
        Quickshell.execDetached(["mkdir", "-p", resolvedStorageDir])
    }

    function saveTodos() {
        const data = {
            version: 1,
            todos: todos
        }
        todoFile.setText(JSON.stringify(data, null, 2))
    }

    function addTodo(text) {
        const trimmed = String(text || "").replace(/\s+/g, " ").trim()
        if (!trimmed.length)
            return false
        if (todos.length >= maxItems) {
            if (typeof ToastService !== "undefined")
                ToastService.showWarning("Max " + maxItems + " todos reached")
            return false
        }
        const entry = {
            id: uid(),
            text: trimmed.substring(0, maxTextLength),
            completed: false,
            createdAt: new Date().toISOString()
        }
        todos = [entry].concat(todos)
        revision++
        saveTodos()
        return true
    }

    function toggleTodo(id) {
        const idx = todos.findIndex(t => t.id === id)
        if (idx === -1)
            return
        const next = todos.slice()
        next[idx] = Object.assign({}, next[idx], {
            completed: !next[idx].completed,
            completedAt: !next[idx].completed ? new Date().toISOString() : undefined
        })
        todos = next
        revision++
        saveTodos()
    }

    function deleteTodo(id) {
        const next = todos.filter(t => t.id !== id)
        if (next.length === todos.length)
            return
        todos = next
        revision++
        saveTodos()
    }

    function editTodo(id, newText) {
        const trimmed = String(newText || "").replace(/\s+/g, " ").trim()
        if (!trimmed.length)
            return
        const idx = todos.findIndex(t => t.id === id)
        if (idx === -1)
            return
        const next = todos.slice()
        next[idx] = Object.assign({}, next[idx], {
            text: trimmed.substring(0, maxTextLength)
        })
        todos = next
        revision++
        saveTodos()
    }

    function clearCompleted() {
        const next = todos.filter(t => !t.completed)
        if (next.length === todos.length)
            return
        todos = next
        revision++
        saveTodos()
    }

    function pillCountLabel() {
        switch (countMode) {
        case "total":
            return String(todos.length)
        case "done":
            return String(doneCount)
        case "hidden":
            return ""
        default:
            return String(activeCount)
        }
    }

    FileView {
        id: todoFile
        path: root.storageFilePath
        watchChanges: false
        blockWrites: false
        atomicWrites: true
        printErrors: false

        onLoaded: {
            let parsed = null
            try {
                parsed = JSON.parse(text())
            } catch (_) {
                parsed = null
            }
            const raw = parsed && Array.isArray(parsed.todos) ? parsed.todos : (Array.isArray(parsed) ? parsed : [])
            const clean = []
            for (let i = 0; i < raw.length; i++) {
                const t = raw[i]
                if (!t || typeof t.text !== "string")
                    continue
                clean.push({
                    id: t.id || root.uid(),
                    text: String(t.text).substring(0, root.maxTextLength),
                    completed: Boolean(t.completed),
                    createdAt: t.createdAt || new Date().toISOString(),
                    completedAt: t.completedAt
                })
            }
            root.todos = clean
            root.revision++
        }
        onLoadFailed: error => {
            if (error === 2) {
                root.todos = []
                root.revision++
                root.ensureStorageReady()
                root.saveTodos()
            }
        }
    }

    IpcHandler {
        target: "dankTodo"

        function add(text: string): string {
            const ok = root.addTodo(text)
            return ok ? "OK" : "FAILED"
        }

        function toggle(id: string): string {
            root.toggleTodo(id)
            return "OK"
        }

        function remove(id: string): string {
            root.deleteTodo(id)
            return "OK"
        }

        function clearDone(): string {
            root.clearCompleted()
            return "OK"
        }

        function list(): string {
            try {
                return JSON.stringify(root.todos)
            } catch (_) {
                return "[]"
            }
        }

        function count(): string {
            return root.activeCount + "/" + root.todos.length
        }
    }

    Component.onCompleted: {
        ensureStorageReady()
        todoFile.reload()
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                name: root.activeCount > 0 ? "checklist" : "check_circle"
                size: Theme.iconSize - 6
                color: root.activeCount > 0 ? Theme.primary : Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.pillCountLabel()
                visible: text.length > 0
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            DankIcon {
                name: root.activeCount > 0 ? "checklist" : "check_circle"
                size: Theme.iconSize - 6
                color: root.activeCount > 0 ? Theme.primary : Theme.surfaceVariantText
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: root.pillCountLabel()
                visible: text.length > 0
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.surfaceVariantText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popout

            headerText: "Todos"
            detailsText: root.todos.length === 0 ? "Nothing here yet" : (root.activeCount + " active • " + root.doneCount + " done")
            showCloseButton: true

            Column {
                id: popoutColumn
                width: 380
                spacing: Theme.spacingM

                Item {
                    width: parent.width
                    height: Math.max(addInput.implicitHeight, 40)

                    DankTextField {
                        id: addInput
                        anchors.left: parent.left
                        anchors.right: addButton.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        placeholderText: "Add a todo and press Enter"
                        maximumLength: root.maxTextLength
                        onAccepted: {
                            if (root.addTodo(text))
                                text = ""
                            forceActiveFocus()
                        }
                    }

                    Rectangle {
                        id: addButton
                        width: 40
                        height: 40
                        radius: Theme.cornerRadius
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        color: addArea.containsMouse ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)

                        DankIcon {
                            anchors.centerIn: parent
                            name: "add"
                            size: 20
                            color: addArea.containsMouse ? Theme.onPrimary : Theme.primary
                        }

                        MouseArea {
                            id: addArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.addTodo(addInput.text))
                                    addInput.text = ""
                                addInput.forceActiveFocus()
                            }
                        }
                    }
                }

                Row {
                    id: filterRow
                    width: parent.width
                    spacing: Theme.spacingXS

                    property real chipWidth: (width - spacing * 2) / 3

                    Repeater {
                        model: [
                            {
                                key: "all",
                                label: "All",
                                count: root.todos.length
                            },
                            {
                                key: "active",
                                label: "Active",
                                count: root.activeCount
                            },
                            {
                                key: "done",
                                label: "Done",
                                count: root.doneCount
                            }
                        ]

                        Rectangle {
                            width: filterRow.chipWidth
                            height: 28
                            radius: Theme.cornerRadius
                            color: root.filter === modelData.key ? Theme.primary : (chipArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)
                            border.width: root.filter === modelData.key ? 0 : 1
                            border.color: Theme.outlineVariant

                            StyledText {
                                anchors.centerIn: parent
                                text: modelData.label + " (" + modelData.count + ")"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: root.filter === modelData.key ? Font.Medium : Font.Normal
                                color: root.filter === modelData.key ? Theme.onPrimary : Theme.surfaceText
                            }

                            MouseArea {
                                id: chipArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.filter = modelData.key
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: Math.min(300, Math.max(48, todoList.contentHeight))

                    ListView {
                        id: todoList
                        anchors.fill: parent
                        spacing: Theme.spacingXS
                        clip: true
                        model: {
                            root.revision
                            if (root.filter === "active")
                                return root.todos.filter(t => !t.completed)
                            if (root.filter === "done")
                                return root.todos.filter(t => t.completed)
                            return root.todos
                        }

                        ScrollBar.vertical: ScrollBar {
                            id: todoScrollBar
                            policy: ScrollBar.AsNeeded
                            visible: todoList.contentHeight > todoList.height
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

                        delegate: Rectangle {
                            width: todoList.width - (todoScrollBar.visible ? (todoScrollBar.width + Theme.spacingS) : 0)
                            height: Math.max(36, todoText.implicitHeight + Theme.spacingS * 2)
                            radius: Theme.cornerRadius / 2
                            color: itemHover.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                            border.width: itemHover.containsMouse ? 1 : 0
                            border.color: Theme.outlineVariant

                            Row {
                                id: itemRow
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingS
                                anchors.rightMargin: Theme.spacingXS
                                spacing: Theme.spacingS

                                DankIcon {
                                    id: checkIcon
                                    name: modelData.completed ? "check_circle" : "radio_button_unchecked"
                                    size: 18
                                    color: modelData.completed ? Theme.primary : Theme.surfaceVariantText
                                    anchors.verticalCenter: parent.verticalCenter

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.toggleTodo(modelData.id)
                                    }
                                }

                                StyledText {
                                    id: todoText
                                    width: parent.width - checkIcon.width - deleteBtn.width - Theme.spacingS * 2
                                    text: modelData.text
                                    color: modelData.completed ? Theme.surfaceVariantText : Theme.surfaceText
                                    font.strikeout: modelData.completed
                                    wrapMode: Text.WordWrap
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Rectangle {
                                    id: deleteBtn
                                    width: 26
                                    height: 26
                                    radius: 13
                                    color: deleteArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.2) : "transparent"
                                    anchors.verticalCenter: parent.verticalCenter

                                    DankIcon {
                                        anchors.centerIn: parent
                                        name: "delete"
                                        size: 16
                                        color: deleteArea.containsMouse ? Theme.error : Theme.surfaceVariantText
                                    }

                                    MouseArea {
                                        id: deleteArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.deleteTodo(modelData.id)
                                    }
                                }
                            }

                            MouseArea {
                                id: itemHover
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                                z: -1
                            }
                        }

                        StyledText {
                            anchors.centerIn: parent
                            visible: todoList.count === 0
                            text: {
                                if (root.filter === "active")
                                    return "No active todos"
                                if (root.filter === "done")
                                    return "No completed todos"
                                return "No todos yet"
                            }
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 30
                    visible: root.doneCount > 0

                    Rectangle {
                        id: clearButton
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: clearLabel.implicitWidth + Theme.spacingM * 2
                        height: 30
                        radius: Theme.cornerRadius
                        color: clearArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                        border.width: 1
                        border.color: Theme.outlineVariant

                        StyledText {
                            id: clearLabel
                            anchors.centerIn: parent
                            text: "Clear completed"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                        }

                        MouseArea {
                            id: clearArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.clearCompleted()
                        }
                    }
                }
            }
        }
    }
}
