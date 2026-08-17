import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "TodoUtils.js" as TodoUtils

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
    property bool notificationAvailable: true
    property string filter: "all"
    property string searchQuery: ""
    property string sortMode: "manual"
    readonly property int visibleCount: {
        revision
        let n = 0
        for (let i = 0; i < todos.length; i++) {
            if (!todos[i].deletedAt)
                n++
        }
        return n
    }

    readonly property int activeCount: {
        revision
        let n = 0
        for (let i = 0; i < todos.length; i++) {
            if (!todos[i].deletedAt && !todos[i].completed)
                n++
        }
        return n
    }
    readonly property int doneCount: {
        revision
        return visibleCount - activeCount
    }
    readonly property int deletedCount: {
        revision
        let n = 0
        for (let i = 0; i < todos.length; i++) {
            if (todos[i].deletedAt)
                n++
        }
        return n
    }
    readonly property int todayCount: {
        revision
        const today = localDateKey(new Date())
        let n = 0
        for (let i = 0; i < todos.length; i++) {
            const t = todos[i]
            if (!t.deletedAt && !t.completed && t.dueDate && t.dueDate <= today)
                n++
        }
        return n
    }
    readonly property int upcomingCount: {
        revision
        const today = localDateKey(new Date())
        let n = 0
        for (let i = 0; i < todos.length; i++) {
            const t = todos[i]
            if (!t.deletedAt && !t.completed && t.dueDate && t.dueDate > today)
                n++
        }
        return n
    }
    readonly property int overdueCount: {
        revision
        const today = localDateKey(new Date())
        let n = 0
        for (let i = 0; i < todos.length; i++) {
            const t = todos[i]
            if (!t.deletedAt && !t.completed && t.dueDate && t.dueDate < today)
                n++
        }
        return n
    }

    function uid() {
        return Date.now().toString(36) + Math.random().toString(36).substring(2, 8)
    }

    function localDateKey(date) {
        return TodoUtils.localDateKey(date)
    }

    function normalizeDueDate(value) {
        return TodoUtils.normalizeDueDate(value)
    }

    function normalizeDueTime(value) {
        const text = String(value || "").trim()
        if (!text)
            return ""
        const match = /^(\d{2}):(\d{2})$/.exec(text)
        if (!match)
            return ""
        const hour = Number(match[1])
        const minute = Number(match[2])
        return hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59 ? text : ""
    }

    function normalizeReminderMinutes(value) {
        if (value === null || value === undefined || value === "" || value === "-" || value === "off" || value === "none")
            return null
        const n = Number(value)
        return (n === 0 || n === 10 || n === 60 || n === 1440) ? n : null
    }

    function normalizeRecurrence(value) {
        if (value === "-" || value === "none")
            return ""
        const recurrence = String(value || "").toLowerCase()
        return (recurrence === "daily" || recurrence === "weekdays" || recurrence === "weekly" || recurrence === "monthly") ? recurrence : ""
    }

    function normalizePriority(value) {
        return TodoUtils.normalizePriority(value)
    }

    function normalizeTags(value) {
        return TodoUtils.normalizeTags(value)
    }

    function dueLabel(dueDate, dueTime) {
        if (!dueDate)
            return ""
        const label = TodoUtils.dueLabel(dueDate, new Date())
        return dueTime ? (label + " " + dueTime) : label
    }

    function priorityLabel(priority) {
        if (priority === "high")
            return "H"
        if (priority === "medium")
            return "M"
        if (priority === "low")
            return "L"
        return ""
    }

    function taskMetaText(todo) {
        if (!todo)
            return ""
        const parts = []
        if (todo.dueDate)
            parts.push(dueLabel(todo.dueDate, todo.dueTime))
        if (todo.priority)
            parts.push(priorityLabel(todo.priority))
        if (todo.tags && todo.tags.length)
            parts.push(todo.tags.map(tag => "#" + tag).join(" "))
        return parts.join("  •  ")
    }

    function startOfWeek(date) {
        return TodoUtils.startOfWeek(date, Qt.locale().firstDayOfWeek)
    }

    function tasksForDate(date) {
        revision
        const key = typeof date === "string" ? date : localDateKey(date)
        return todos.filter(t => !t.deletedAt && t.dueDate === key)
    }

    function activeTaskCountForDate(date) {
        const tasks = tasksForDate(date)
        let count = 0
        for (let i = 0; i < tasks.length; i++) {
            if (!tasks[i].completed)
                count++
        }
        return count
    }

    function reminderKey(todo) {
        if (!todo || !todo.dueDate || !todo.dueTime || todo.reminderMinutes === null || todo.reminderMinutes === undefined)
            return ""
        return todo.dueDate + "T" + todo.dueTime + "@" + String(todo.reminderMinutes)
    }

    function taskDueDateTime(todo) {
        if (!todo || !todo.dueDate || !todo.dueTime)
            return null
        const time = normalizeDueTime(todo.dueTime)
        if (!time)
            return null
        const result = new Date(todo.dueDate + "T" + time + ":00")
        return isNaN(result.getTime()) ? null : result
    }

    function recurrenceLabel(recurrence) {
        if (recurrence === "daily")
            return "Daily"
        if (recurrence === "weekdays")
            return "Weekdays"
        if (recurrence === "weekly")
            return "Weekly"
        if (recurrence === "monthly")
            return "Monthly"
        return ""
    }

    function advanceRecurrenceDate(date, recurrence, anchorDay) {
        const next = new Date(date)
        next.setHours(12, 0, 0, 0)
        if (recurrence === "daily") {
            next.setDate(next.getDate() + 1)
        } else if (recurrence === "weekdays") {
            do {
                next.setDate(next.getDate() + 1)
            } while (next.getDay() === 0 || next.getDay() === 6)
        } else if (recurrence === "weekly") {
            next.setDate(next.getDate() + 7)
        } else if (recurrence === "monthly") {
            const wantedDay = Math.max(1, Math.min(31, Number(anchorDay) || next.getDate()))
            const targetMonth = next.getMonth() + 1
            const targetYear = next.getFullYear() + Math.floor(targetMonth / 12)
            const normalizedMonth = ((targetMonth % 12) + 12) % 12
            const lastDay = new Date(targetYear, normalizedMonth + 1, 0).getDate()
            next.setFullYear(targetYear, normalizedMonth, Math.min(wantedDay, lastDay))
        }
        return next
    }

    function nextRecurrenceDate(todo, now) {
        const recurrence = normalizeRecurrence(todo && todo.recurrence)
        const dueDate = normalizeDueDate(todo && todo.dueDate)
        if (!recurrence || !dueDate)
            return ""
        let candidate = new Date(dueDate + "T12:00:00")
        const anchorDay = Number(todo.recurrenceAnchorDay) || candidate.getDate()
        const current = now || new Date()
        let guard = 0
        do {
            candidate = advanceRecurrenceDate(candidate, recurrence, anchorDay)
            guard++
            if (guard > 10000)
                return ""
            if (todo.dueTime) {
                const parts = todo.dueTime.split(":")
                candidate.setHours(Number(parts[0]), Number(parts[1]), 0, 0)
            }
        } while (todo.dueTime ? candidate.getTime() <= current.getTime() : localDateKey(candidate) <= localDateKey(current))
        return localDateKey(candidate)
    }

    function recurringSuccessor(todo) {
        const nextDate = nextRecurrenceDate(todo, new Date())
        if (!nextDate)
            return null
        return {
            id: uid(),
            text: todo.text,
            completed: false,
            parentId: todo.parentId || null,
            createdAt: new Date().toISOString(),
            dueDate: nextDate,
            dueTime: normalizeDueTime(todo.dueTime),
            reminderMinutes: normalizeReminderMinutes(todo.reminderMinutes),
            recurrence: normalizeRecurrence(todo.recurrence),
            recurrenceAnchorDay: Number(todo.recurrenceAnchorDay) || Number(todo.dueDate.substring(8, 10)),
            reminderState: {},
            priority: normalizePriority(todo.priority),
            tags: normalizeTags(todo.tags)
        }
    }

    function canSnooze(todo) {
        const key = reminderKey(todo)
        return Boolean(key && todo && todo.reminderState && todo.reminderState.lastNotifiedKey === key)
    }

    function snoozeTodo(id, minutes) {
        const idx = todos.findIndex(t => t.id === id && !t.deletedAt && !t.completed)
        if (idx === -1)
            return false
        const todo = todos[idx]
        const key = reminderKey(todo)
        if (!key)
            return false
        const delay = Math.max(1, Number(minutes) || 10)
        const state = Object.assign({}, todo.reminderState || {}, {
            lastNotifiedKey: key,
            snoozedUntil: new Date(Date.now() + delay * 60000).toISOString()
        })
        const next = todos.slice()
        next[idx] = Object.assign({}, todo, { reminderState: state })
        todos = next
        revision++
        saveTodos()
        if (typeof ToastService !== "undefined")
            ToastService.showInfo("Reminder snoozed for " + delay + " minutes")
        return true
    }

    function sendReminder(todo) {
        if (notificationAvailable) {
            Quickshell.execDetached(["notify-send", "-u", "normal", "-a", "Dank Todo", "-i", "appointment-soon", "Task reminder", String(todo.text || "")])
        } else if (typeof ToastService !== "undefined") {
            ToastService.showInfo("Task reminder", String(todo.text || ""))
        }
    }

    function checkReminders() {
        const now = new Date()
        const nowMs = now.getTime()
        let changed = false
        const next = todos.slice()
        for (let i = 0; i < next.length; i++) {
            const todo = next[i]
            if (!todo || todo.deletedAt || todo.completed)
                continue
            const due = taskDueDateTime(todo)
            const key = reminderKey(todo)
            if (!due || !key)
                continue
            const state = Object.assign({}, todo.reminderState || {})
            const snoozedMs = state.snoozedUntil ? Date.parse(state.snoozedUntil) : NaN
            if (!isNaN(snoozedMs) && nowMs >= snoozedMs) {
                sendReminder(todo)
                delete state.snoozedUntil
                state.lastNotifiedKey = key
                state.lastNotifiedAt = now.toISOString()
                next[i] = Object.assign({}, todo, { reminderState: state })
                changed = true
                continue
            }
            if (state.lastNotifiedKey === key)
                continue
            const triggerMs = due.getTime() - Number(todo.reminderMinutes) * 60000
            const catchUpEndMs = due.getTime() + 24 * 60 * 60000
            if (nowMs >= triggerMs && nowMs <= catchUpEndMs) {
                sendReminder(todo)
                state.lastNotifiedKey = key
                state.lastNotifiedAt = now.toISOString()
                next[i] = Object.assign({}, todo, { reminderState: state })
                changed = true
            }
        }
        if (changed) {
            todos = next
            revision++
            saveTodos()
        }
    }

    function ensureStorageReady() {
        Quickshell.execDetached(["mkdir", "-p", resolvedStorageDir])
    }

    function saveTodos() {
        const data = {
            version: 4,
            preferences: {
                sortMode: sortMode
            },
            todos: todos
        }
        todoFile.setText(JSON.stringify(data, null, 2))
    }

    function reloadTodos() {
        ensureStorageReady()
        todoFile.reload()
    }

    function normalizeSortMode(value) {
        const mode = String(value || "manual")
        return (mode === "due" || mode === "priority") ? mode : "manual"
    }

    function setSortMode(value) {
        const mode = normalizeSortMode(value)
        if (sortMode === mode)
            return
        sortMode = mode
        revision++
        saveTodos()
    }

    function taskDueSortKey(todo) {
        if (!todo || !todo.dueDate)
            return "~"
        return todo.dueDate + "T" + (todo.dueTime || "00:00")
    }

    function priorityRank(priority) {
        if (priority === "high")
            return 0
        if (priority === "medium")
            return 1
        if (priority === "low")
            return 2
        return 3
    }

    function sortedActiveTodos(items) {
        if (sortMode === "manual" || items.length < 2)
            return items

        const visibleById = new Map()
        for (let i = 0; i < items.length; i++)
            visibleById.set(items[i].id, items[i])

        const groups = []
        const groupsByRoot = new Map()
        for (let i = 0; i < items.length; i++) {
            const todo = items[i]
            let rootTodo = todo
            let guard = 0
            while (rootTodo.parentId && visibleById.has(rootTodo.parentId) && guard < 32) {
                rootTodo = visibleById.get(rootTodo.parentId)
                guard++
            }
            let group = groupsByRoot.get(rootTodo.id)
            if (!group) {
                group = { rootId: rootTodo.id, originalIndex: groups.length, items: [] }
                groupsByRoot.set(rootTodo.id, group)
                groups.push(group)
            }
            group.items.push(todo)
        }

        function groupDueKey(group) {
            let key = "~"
            for (let i = 0; i < group.items.length; i++) {
                const candidate = root.taskDueSortKey(group.items[i])
                if (candidate < key)
                    key = candidate
            }
            return key
        }

        function groupPriorityRank(group) {
            let rank = 3
            for (let i = 0; i < group.items.length; i++)
                rank = Math.min(rank, root.priorityRank(group.items[i].priority))
            return rank
        }

        groups.sort((a, b) => {
            if (sortMode === "priority") {
                const priorityDelta = groupPriorityRank(a) - groupPriorityRank(b)
                if (priorityDelta !== 0)
                    return priorityDelta
            }
            const dueA = groupDueKey(a)
            const dueB = groupDueKey(b)
            if (dueA < dueB)
                return -1
            if (dueA > dueB)
                return 1
            return a.originalIndex - b.originalIndex
        })

        const sorted = []
        for (let i = 0; i < groups.length; i++)
            sorted.push(...groups[i].items)
        return sorted
    }

    function shortcutDate(kind, baseDate) {
        const result = new Date(baseDate || new Date())
        result.setHours(12, 0, 0, 0)
        if (kind === "tomorrow") {
            result.setDate(result.getDate() + 1)
        } else if (kind === "nextMonday") {
            let days = (8 - result.getDay()) % 7
            if (days === 0)
                days = 7
            result.setDate(result.getDate() + days)
        }
        return localDateKey(result)
    }

    function filteredTodos(filterKey) {
        revision
        const today = localDateKey(new Date())
        let result
        if (filterKey === "trash") {
            result = todos.filter(t => Boolean(t.deletedAt))
        } else {
            result = todos.filter(t => !t.deletedAt)
            if (filterKey === "active")
                result = result.filter(t => !t.completed && !hasCompletedAncestor(t.id))
            else if (filterKey === "today")
                result = result.filter(t => !t.completed && t.dueDate && t.dueDate <= today)
            else if (filterKey === "upcoming")
                result = result.filter(t => !t.completed && t.dueDate && t.dueDate > today)
            else if (filterKey === "done")
                result = result.filter(t => t.completed)
        }
        const query = String(searchQuery || "").trim().toLowerCase()
        if (query) {
            result = result.filter(t => {
                const tags = t.tags ? t.tags.join(" ") : ""
                return (String(t.text || "") + " " + tags).toLowerCase().indexOf(query) !== -1
            })
        }
        return filterKey === "active" ? sortedActiveTodos(result) : result
    }

    function hasCompletedAncestor(id) {
        let cur = todos.find(t => t.id === id)
        while (cur && cur.parentId) {
            cur = todos.find(t => t.id === cur.parentId)
            if (cur && !cur.deletedAt && cur.completed)
                return true
        }
        return false
    }

    function depthOf(id) {
        let d = 0
        let cur = todos.find(t => t.id === id)
        while (cur && cur.parentId) {
            d++
            if (d > 16)
                return d
            cur = todos.find(t => t.id === cur.parentId)
        }
        return d
    }

    function getDescendantIds(id) {
        const result = new Set()
        let changed = true
        while (changed) {
            changed = false
            for (const t of todos) {
                const pid = t.parentId || null
                if (pid === null)
                    continue
                if ((pid === id || result.has(pid)) && !result.has(t.id)) {
                    result.add(t.id)
                    changed = true
                }
            }
        }
        return result
    }

    function isDescendant(candidateId, ancestorId) {
        if (!candidateId || !ancestorId)
            return false
        if (candidateId === ancestorId)
            return true
        return getDescendantIds(ancestorId).has(candidateId)
    }

    function subtreeIndices(id) {
        const indices = []
        const startIdx = todos.findIndex(t => t.id === id)
        if (startIdx === -1)
            return indices
        const descendants = getDescendantIds(id)
        indices.push(startIdx)
        for (let i = startIdx + 1; i < todos.length; i++) {
            if (descendants.has(todos[i].id))
                indices.push(i)
        }
        return indices
    }

    function addTodo(text, parentId, metadata) {
        const trimmed = String(text || "").replace(/\s+/g, " ").trim()
        if (!trimmed.length)
            return false
        if (visibleCount >= maxItems) {
            if (typeof ToastService !== "undefined")
                ToastService.showWarning("Max " + maxItems + " todos reached")
            return false
        }
        const meta = metadata || {}
        const dueDate = normalizeDueDate(meta.dueDate)
        const dueTime = dueDate ? normalizeDueTime(meta.dueTime) : ""
        const recurrence = dueDate ? normalizeRecurrence(meta.recurrence) : ""
        const entry = {
            id: uid(),
            text: trimmed.substring(0, maxTextLength),
            completed: false,
            parentId: parentId || null,
            createdAt: new Date().toISOString(),
            dueDate: dueDate,
            dueTime: dueTime,
            reminderMinutes: dueTime ? normalizeReminderMinutes(meta.reminderMinutes) : null,
            recurrence: recurrence,
            recurrenceAnchorDay: recurrence === "monthly" ? Number(dueDate.substring(8, 10)) : null,
            reminderState: {},
            priority: normalizePriority(meta.priority),
            tags: normalizeTags(meta.tags)
        }
        if (entry.parentId) {
            // Insert right after parent so it becomes the first visible child
            const parentIdx = todos.findIndex(t => t.id === entry.parentId && !t.deletedAt)
            if (parentIdx === -1) {
                entry.parentId = null
                todos = [entry].concat(todos)
            } else {
                const next = todos.slice()
                next.splice(parentIdx + 1, 0, entry)
                todos = next
            }
        } else {
            todos = [entry].concat(todos)
        }
        revision++
        saveTodos()
        return true
    }

    function toggleTodo(id) {
        const idx = todos.findIndex(t => t.id === id && !t.deletedAt)
        if (idx === -1)
            return
        const next = todos.slice()
        const wasCompleted = Boolean(next[idx].completed)
        const source = next[idx]
        next[idx] = Object.assign({}, source, {
            completed: !wasCompleted,
            completedAt: !wasCompleted ? new Date().toISOString() : undefined,
            reminderState: !wasCompleted ? {} : (source.reminderState || {})
        })
        if (!wasCompleted && source.recurrence && source.dueDate && !source.nextRecurrenceId) {
            const successor = recurringSuccessor(source)
            if (successor) {
                next[idx] = Object.assign({}, next[idx], { nextRecurrenceId: successor.id })
                next.splice(idx, 0, successor)
            }
        }
        todos = next
        revision++
        saveTodos()
    }

    function deleteTodo(id) {
        const toDelete = new Set([id])
        const descendants = getDescendantIds(id)
        descendants.forEach(d => toDelete.add(d))
        const deletedAt = new Date().toISOString()
        let changed = false
        const next = todos.map(t => {
            if (!toDelete.has(t.id) || t.deletedAt)
                return t
            changed = true
            return Object.assign({}, t, {
                deletedAt: deletedAt
            })
        })
        if (!changed)
            return
        todos = next
        revision++
        saveTodos()
    }

    function moveTodo(sourceId, targetId, position) {
        if (!sourceId || !targetId || sourceId === targetId)
            return
        if (isDescendant(targetId, sourceId))
            return
        const sourceIdx = todos.findIndex(t => t.id === sourceId && !t.deletedAt)
        const targetIdx = todos.findIndex(t => t.id === targetId && !t.deletedAt)
        if (sourceIdx === -1 || targetIdx === -1)
            return

        const sourceIndices = subtreeIndices(sourceId)
        const sourceBlock = sourceIndices.map(i => todos[i])
        const sourceIdSet = new Set(sourceBlock.map(t => t.id))

        // Remove the source block from the array
        const remaining = todos.filter(t => !sourceIdSet.has(t.id))

        // Determine new parentId for the source and insert position in `remaining`
        const targetInRemainingIdx = remaining.findIndex(t => t.id === targetId)
        if (targetInRemainingIdx === -1)
            return
        const target = remaining[targetInRemainingIdx]

        let newParentId = null
        let insertAt = targetInRemainingIdx
        if (position === "before") {
            newParentId = target.parentId || null
            insertAt = targetInRemainingIdx
        } else if (position === "child") {
            newParentId = target.id
            insertAt = targetInRemainingIdx + 1
        } else {
            // "after": insert after target's full subtree
            newParentId = target.parentId || null
            let end = targetInRemainingIdx
            const targetDescendants = new Set()
            let changed = true
            while (changed) {
                changed = false
                for (const t of remaining) {
                    const pid = t.parentId || null
                    if (pid === null)
                        continue
                    if ((pid === target.id || targetDescendants.has(pid)) && !targetDescendants.has(t.id)) {
                        targetDescendants.add(t.id)
                        changed = true
                    }
                }
            }
            for (let i = targetInRemainingIdx + 1; i < remaining.length; i++) {
                if (targetDescendants.has(remaining[i].id))
                    end = i
                else
                    break
            }
            insertAt = end + 1
        }

        // Update the root of the source block with its new parentId
        sourceBlock[0] = Object.assign({}, sourceBlock[0], {
            parentId: newParentId
        })

        const next = remaining.slice()
        next.splice(insertAt, 0, ...sourceBlock)
        todos = next
        revision++
        saveTodos()
    }

    function editTodo(id, newText) {
        const trimmed = String(newText || "").replace(/\s+/g, " ").trim()
        if (!trimmed.length)
            return
        const idx = todos.findIndex(t => t.id === id && !t.deletedAt)
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

    function editTodoDetails(id, newText, metadata) {
        const trimmed = String(newText || "").replace(/\s+/g, " ").trim()
        if (!trimmed.length)
            return false
        const idx = todos.findIndex(t => t.id === id && !t.deletedAt)
        if (idx === -1)
            return false
        const meta = metadata || {}
        const current = todos[idx]
        const dueDate = normalizeDueDate(meta.dueDate)
        const dueTime = dueDate ? normalizeDueTime(meta.dueTime) : ""
        const reminderMinutes = dueTime ? normalizeReminderMinutes(meta.reminderMinutes) : null
        const recurrence = dueDate ? normalizeRecurrence(meta.recurrence) : ""
        const scheduleChanged = current.dueDate !== dueDate
            || current.dueTime !== dueTime
            || current.reminderMinutes !== reminderMinutes
            || current.recurrence !== recurrence
        const next = todos.slice()
        next[idx] = Object.assign({}, current, {
            text: trimmed.substring(0, maxTextLength),
            dueDate: dueDate,
            dueTime: dueTime,
            reminderMinutes: reminderMinutes,
            recurrence: recurrence,
            recurrenceAnchorDay: recurrence === "monthly" ? (current.recurrence === "monthly" && current.dueDate === dueDate ? current.recurrenceAnchorDay : Number(dueDate.substring(8, 10))) : null,
            reminderState: scheduleChanged ? {} : (current.reminderState || {}),
            priority: normalizePriority(meta.priority),
            tags: normalizeTags(meta.tags)
        })
        todos = next
        revision++
        saveTodos()
        return true
    }

    function restoreTodo(id) {
        const source = todos.find(t => t.id === id && t.deletedAt)
        if (!source)
            return
        const batch = source.deletedAt
        const descendants = getDescendantIds(id)
        const toRestore = new Set([id])
        descendants.forEach(d => toRestore.add(d))
        const next = todos.map(t => {
            if (!toRestore.has(t.id) || t.deletedAt !== batch)
                return t
            const restored = Object.assign({}, t)
            delete restored.deletedAt
            return restored
        })
        const restoredRoot = next.find(t => t.id === id)
        if (restoredRoot && restoredRoot.parentId) {
            const parent = next.find(t => t.id === restoredRoot.parentId)
            if (!parent || parent.deletedAt)
                restoredRoot.parentId = null
        }
        todos = next
        revision++
        saveTodos()
    }

    function permanentlyDeleteTodo(id) {
        const toDelete = new Set([id])
        getDescendantIds(id).forEach(d => toDelete.add(d))
        const next = todos.filter(t => !toDelete.has(t.id))
        if (next.length === todos.length)
            return
        todos = next
        revision++
        saveTodos()
    }

    function emptyTrash() {
        const next = todos.filter(t => !t.deletedAt)
        if (next.length === todos.length)
            return
        const remainingIds = new Set(next.map(t => t.id))
        for (let i = 0; i < next.length; i++) {
            if (next[i].parentId && !remainingIds.has(next[i].parentId))
                next[i] = Object.assign({}, next[i], { parentId: null })
        }
        todos = next
        revision++
        saveTodos()
    }

    function clearCompleted() {
        const deletedAt = new Date().toISOString()
        let changed = false
        const next = todos.map(t => {
            if (t.deletedAt || !t.completed)
                return t
            changed = true
            return Object.assign({}, t, {
                deletedAt: deletedAt
            })
        })
        if (!changed)
            return
        todos = next
        revision++
        saveTodos()
    }

    function pillCountLabel() {
        switch (countMode) {
        case "total":
            return String(visibleCount)
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
            const storedPreferences = parsed && parsed.preferences && typeof parsed.preferences === "object" ? parsed.preferences : {}
            root.sortMode = root.normalizeSortMode(storedPreferences.sortMode)
            const clean = []
            const seenIds = new Set()
            for (let i = 0; i < raw.length; i++) {
                const t = raw[i]
                if (!t || typeof t.text !== "string")
                    continue
                let id = t.id || root.uid()
                if (seenIds.has(id))
                    id = root.uid()
                seenIds.add(id)
                const dueDate = root.normalizeDueDate(t.dueDate)
                const dueTime = dueDate ? root.normalizeDueTime(t.dueTime) : ""
                const recurrence = dueDate ? root.normalizeRecurrence(t.recurrence) : ""
                const reminderMinutes = dueTime ? root.normalizeReminderMinutes(t.reminderMinutes) : null
                const reminderState = t.reminderState && typeof t.reminderState === "object" ? {
                    lastNotifiedKey: String(t.reminderState.lastNotifiedKey || ""),
                    lastNotifiedAt: String(t.reminderState.lastNotifiedAt || ""),
                    snoozedUntil: String(t.reminderState.snoozedUntil || "")
                } : {}
                clean.push({
                    id: id,
                    text: String(t.text).substring(0, root.maxTextLength),
                    completed: Boolean(t.completed),
                    parentId: t.parentId || null,
                    createdAt: t.createdAt || new Date().toISOString(),
                    completedAt: t.completedAt,
                    deletedAt: t.deletedAt,
                    dueDate: dueDate,
                    dueTime: dueTime,
                    reminderMinutes: reminderMinutes,
                    recurrence: recurrence,
                    recurrenceAnchorDay: recurrence === "monthly" ? Math.max(1, Math.min(31, Number(t.recurrenceAnchorDay) || Number(dueDate.substring(8, 10)))) : null,
                    reminderState: reminderState,
                    nextRecurrenceId: t.nextRecurrenceId || undefined,
                    priority: root.normalizePriority(t.priority),
                    tags: root.normalizeTags(t.tags)
                })
            }
            const byId = new Map()
            for (let i = 0; i < clean.length; i++)
                byId.set(clean[i].id, clean[i])
            // Drop dangling parent references. Keep links between deleted tasks so
            // a whole subtree can be restored from the trash.
            for (let i = 0; i < clean.length; i++) {
                const pid = clean[i].parentId
                const parent = pid ? byId.get(pid) : null
                if (pid && !parent)
                    clean[i].parentId = null
            }
            root.todos = clean
            root.revision++
            if (!parsed || Number(parsed.version) !== 4 || !parsed.preferences)
                Qt.callLater(root.saveTodos)
            Qt.callLater(root.checkReminders)
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
            const ok = root.addTodo(text, null)
            return ok ? "OK" : "FAILED"
        }

        function addChild(text: string, parentId: string): string {
            const ok = root.addTodo(text, parentId)
            return ok ? "OK" : "FAILED"
        }

        function toggle(id: string): string {
            root.toggleTodo(id)
            return "OK"
        }

        function edit(id: string, text: string): string {
            root.editTodo(id, text)
            return "OK"
        }

        function setDetails(id: string, dueDate: string, priority: string, tags: string): string {
            const todo = root.todos.find(t => t.id === id && !t.deletedAt)
            if (!todo)
                return "NOT_FOUND"
            root.editTodoDetails(id, todo.text, {
                dueDate: dueDate,
                dueTime: todo.dueTime,
                reminderMinutes: todo.reminderMinutes,
                recurrence: todo.recurrence,
                priority: priority,
                tags: tags
            })
            return "OK"
        }

        function setSchedule(id: string, dueDate: string, dueTime: string, reminder: string, recurrence: string): string {
            const todo = root.todos.find(t => t.id === id && !t.deletedAt)
            if (!todo)
                return "NOT_FOUND"
            const normalizedDate = dueDate === "-" ? "" : root.normalizeDueDate(dueDate)
            const normalizedTime = dueTime === "-" ? "" : root.normalizeDueTime(dueTime)
            if (dueDate !== "-" && !normalizedDate)
                return "INVALID_DATE"
            if (dueTime !== "-" && !normalizedTime)
                return "INVALID_TIME"
            root.editTodoDetails(id, todo.text, {
                dueDate: normalizedDate,
                dueTime: normalizedTime,
                reminderMinutes: reminder,
                recurrence: recurrence,
                priority: todo.priority,
                tags: todo.tags
            })
            return "OK"
        }

        function snooze(id: string): string {
            return root.snoozeTodo(id, 10) ? "OK" : "FAILED"
        }

        function remove(id: string): string {
            root.deleteTodo(id)
            return "OK"
        }

        function restore(id: string): string {
            root.restoreTodo(id)
            return "OK"
        }

        function purge(id: string): string {
            root.permanentlyDeleteTodo(id)
            return "OK"
        }

        function emptyTrash(): string {
            root.emptyTrash()
            return "OK"
        }

        function move(sourceId: string, targetId: string, position: string): string {
            root.moveTodo(sourceId, targetId, position)
            return "OK"
        }

        function clearDone(): string {
            root.clearCompleted()
            return "OK"
        }

        function list(): string {
            try {
                return JSON.stringify(root.filteredTodos("all"))
            } catch (_) {
                return "[]"
            }
        }

        function count(): string {
            return root.activeCount + "/" + root.visibleCount
        }
    }

    Process {
        id: notificationProbe
        command: ["sh", "-c", "command -v notify-send >/dev/null 2>&1"]
        running: true
        onExited: (exitCode, exitStatus) => root.notificationAvailable = exitCode === 0
    }

    Timer {
        id: reminderTimer
        interval: 30000
        repeat: true
        running: true
        onTriggered: root.checkReminders()
    }

    Component.onCompleted: reloadTodos()

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
            detailsText: root.visibleCount === 0 ? "Nothing here yet" : (root.activeCount + " active • " + root.doneCount + " done" + (root.overdueCount > 0 ? (" • " + root.overdueCount + " overdue") : ""))
            showCloseButton: true

            onVisibleChanged: {
                if (visible)
                    root.reloadTodos()
                else {
                    popoutColumn.cancelComposer()
                    popoutColumn.completedExpanded = false
                    if (popoutColumn.trashOpen)
                        popoutColumn.closeTrash()
                    if (popoutColumn.calendarOpen)
                        popoutColumn.closeCalendar()
                }
            }

            Column {
                id: popoutColumn
                width: 380
                spacing: Theme.spacingM

                property string addingChildOfId: ""
                property string editingId: ""
                property string composePriority: ""
                property string composeDueTime: ""
                property var composeReminderMinutes: null
                property string composeRecurrence: ""
                property bool timePickerOpen: false
                property int timePickerHour: 9
                property int timePickerMinute: 0
                property string editorReturnPage: "main"
                property bool editorOpen: false
                property bool trashOpen: false
                property bool datePickerOpen: false
                property bool calendarOpen: false
                property string calendarMode: "week"
                property date calendarAnchorDate: new Date()
                property date selectedCalendarDate: new Date()
                property string previousFilter: "all"
                property string previousSearch: ""
                property bool completedExpanded: false
                property bool sortMenuOpen: false

                function resetMetadata() {
                    dueDateInput.text = ""
                    composeDueTime = ""
                    tagsInput.text = ""
                    composePriority = ""
                    composeReminderMinutes = null
                    composeRecurrence = ""
                    datePickerOpen = false
                    timePickerOpen = false
                }

                function padTimePart(value) {
                    const number = Math.max(0, Number(value) || 0)
                    return number < 10 ? ("0" + number) : String(number)
                }

                function openTimePicker() {
                    const normalized = root.normalizeDueTime(composeDueTime)
                    if (normalized) {
                        const parts = normalized.split(":")
                        timePickerHour = Number(parts[0])
                        timePickerMinute = Number(parts[1])
                    } else {
                        const now = new Date()
                        let roundedMinute = Math.ceil(now.getMinutes() / 5) * 5
                        let hour = now.getHours()
                        if (roundedMinute >= 60) {
                            roundedMinute = 0
                            hour = (hour + 1) % 24
                        }
                        timePickerHour = hour
                        timePickerMinute = roundedMinute
                    }
                    datePickerOpen = false
                    timePickerOpen = true
                }

                function shiftTimePicker(minutes) {
                    let total = timePickerHour * 60 + timePickerMinute + minutes
                    total = ((total % 1440) + 1440) % 1440
                    timePickerHour = Math.floor(total / 60)
                    timePickerMinute = total % 60
                }

                function confirmTimePicker() {
                    composeDueTime = padTimePart(timePickerHour) + ":" + padTimePart(timePickerMinute)
                    timePickerOpen = false
                }

                function clearTimePicker() {
                    composeDueTime = ""
                    composeReminderMinutes = null
                    timePickerOpen = false
                }

                function toggleDatePicker() {
                    timePickerOpen = false
                    datePickerOpen = !datePickerOpen
                }

                function finishEditor() {
                    const returnToCalendar = editorReturnPage === "calendar"
                    editorReturnPage = "main"
                    editorOpen = false
                    calendarOpen = returnToCalendar
                }

                function startCreating() {
                    sortMenuOpen = false
                    editorReturnPage = "main"
                    editingId = ""
                    addingChildOfId = ""
                    addInput.text = ""
                    resetMetadata()
                    trashOpen = false
                    calendarOpen = false
                    editorOpen = true
                    addInput.forceActiveFocus()
                }

                function startCreatingForDate(date) {
                    sortMenuOpen = false
                    editingId = ""
                    addingChildOfId = ""
                    addInput.text = ""
                    resetMetadata()
                    dueDateInput.text = root.localDateKey(date)
                    editorReturnPage = "calendar"
                    trashOpen = false
                    calendarOpen = false
                    editorOpen = true
                    addInput.forceActiveFocus()
                }

                function startAddingChild(parentId) {
                    sortMenuOpen = false
                    editorReturnPage = calendarOpen ? "calendar" : "main"
                    editingId = ""
                    addInput.text = ""
                    resetMetadata()
                    addingChildOfId = parentId
                    calendarOpen = false
                    editorOpen = true
                    addInput.forceActiveFocus()
                }

                function startEditing(id) {
                    sortMenuOpen = false
                    editorReturnPage = calendarOpen ? "calendar" : "main"
                    addingChildOfId = ""
                    const t = root.todos.find(x => x.id === id)
                    if (!t)
                        return
                    editingId = id
                    addInput.text = t.text
                    dueDateInput.text = t.dueDate || ""
                    composeDueTime = t.dueTime || ""
                    tagsInput.text = t.tags ? t.tags.join(", ") : ""
                    composePriority = t.priority || ""
                    composeReminderMinutes = t.reminderMinutes === undefined ? null : t.reminderMinutes
                    composeRecurrence = t.recurrence || ""
                    calendarOpen = false
                    editorOpen = true
                    addInput.selectAll()
                    addInput.forceActiveFocus()
                }

                function cancelComposer() {
                    editingId = ""
                    addingChildOfId = ""
                    addInput.text = ""
                    resetMetadata()
                    finishEditor()
                }

                function openTrash() {
                    sortMenuOpen = false
                    previousFilter = root.filter === "trash" ? "all" : root.filter
                    previousSearch = root.searchQuery
                    root.filter = "trash"
                    root.searchQuery = ""
                    trashOpen = true
                    editorOpen = false
                }

                function closeTrash() {
                    trashOpen = false
                    root.filter = previousFilter || "all"
                    root.searchQuery = previousSearch
                }

                function openCalendar() {
                    sortMenuOpen = false
                    previousSearch = root.searchQuery
                    root.searchQuery = ""
                    calendarAnchorDate = new Date()
                    selectedCalendarDate = new Date()
                    calendarOpen = true
                    trashOpen = false
                    editorOpen = false
                }

                function closeCalendar() {
                    calendarOpen = false
                    root.searchQuery = previousSearch
                }

                function shiftCalendarWeek(delta) {
                    const anchor = new Date(calendarAnchorDate)
                    anchor.setDate(anchor.getDate() + delta * 7)
                    calendarAnchorDate = anchor
                    const selected = new Date(selectedCalendarDate)
                    selected.setDate(selected.getDate() + delta * 7)
                    selectedCalendarDate = selected
                }

                function submitComposer() {
                    if (String(dueDateInput.text || "").trim() && !root.normalizeDueDate(dueDateInput.text)) {
                        if (typeof ToastService !== "undefined")
                            ToastService.showWarning("Use a valid date in YYYY-MM-DD format")
                        dueDateInput.forceActiveFocus()
                        return false
                    }
                    if (composeDueTime && !root.normalizeDueDate(dueDateInput.text)) {
                        if (typeof ToastService !== "undefined")
                            ToastService.showWarning("Choose a date before adding a time")
                        dueDateInput.forceActiveFocus()
                        return false
                    }
                    if (editingId) {
                        const id = editingId
                        const newText = addInput.text
                        const ok = root.editTodoDetails(id, newText, {
                            dueDate: dueDateInput.text,
                            dueTime: composeDueTime,
                            reminderMinutes: composeReminderMinutes,
                            recurrence: composeRecurrence,
                            priority: composePriority,
                            tags: tagsInput.text
                        })
                        if (ok) {
                            editingId = ""
                            addInput.text = ""
                            resetMetadata()
                            finishEditor()
                        }
                        return ok
                    }
                    if (root.addTodo(addInput.text, addingChildOfId || null, {
                        dueDate: dueDateInput.text,
                        dueTime: composeDueTime,
                        reminderMinutes: composeReminderMinutes,
                        recurrence: composeRecurrence,
                        priority: composePriority,
                        tags: tagsInput.text
                    })) {
                        addInput.text = ""
                        addingChildOfId = ""
                        resetMetadata()
                        finishEditor()
                        return true
                    }
                    return false
                }

                // Drop composer state if the referenced item disappears
                Connections {
                    target: root
                    function onTodosChanged() {
                        if (popoutColumn.editingId && !root.todos.find(t => t.id === popoutColumn.editingId)) {
                            popoutColumn.editingId = ""
                            addInput.text = ""
                            popoutColumn.editorOpen = false
                        }
                        if (popoutColumn.addingChildOfId && !root.todos.find(t => t.id === popoutColumn.addingChildOfId)) {
                            popoutColumn.addingChildOfId = ""
                            popoutColumn.editorOpen = false
                        }
                    }
                }

                // Secondary-page header for create, edit, and subtask flows.
                Rectangle {
                    width: parent.width
                    height: 40
                    radius: 0
                    color: "transparent"
                    visible: popoutColumn.editorOpen

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingXS
                        anchors.rightMargin: Theme.spacingS
                        spacing: Theme.spacingS

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: backArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                            anchors.verticalCenter: parent.verticalCenter

                            DankIcon {
                                anchors.centerIn: parent
                                name: "arrow_back"
                                size: 18
                                color: Theme.surfaceText
                            }

                            MouseArea {
                                id: backArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: popoutColumn.cancelComposer()
                            }
                        }

                        StyledText {
                            text: popoutColumn.editingId ? "Edit task" : (popoutColumn.addingChildOfId ? "New subtask" : "New task")
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            elide: Text.ElideRight
                            width: parent.width - 32 - Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 40
                    radius: 0
                    color: "transparent"
                    visible: popoutColumn.calendarOpen

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingXS
                        anchors.rightMargin: Theme.spacingS
                        spacing: Theme.spacingS

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: calendarBackArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                            anchors.verticalCenter: parent.verticalCenter

                            DankIcon {
                                anchors.centerIn: parent
                                name: "arrow_back"
                                size: 18
                                color: Theme.surfaceText
                            }

                            MouseArea {
                                id: calendarBackArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: popoutColumn.closeCalendar()
                            }
                        }

                        StyledText {
                            text: "Schedule"
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 40
                    radius: 0
                    color: "transparent"
                    visible: popoutColumn.trashOpen

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingXS
                        anchors.rightMargin: Theme.spacingS
                        spacing: Theme.spacingS

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: trashBackArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                            anchors.verticalCenter: parent.verticalCenter

                            DankIcon {
                                anchors.centerIn: parent
                                name: "arrow_back"
                                size: 18
                                color: Theme.surfaceText
                            }

                            MouseArea {
                                id: trashBackArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: popoutColumn.closeTrash()
                            }
                        }

                        StyledText {
                            text: "Trash" + (root.deletedCount > 0 ? ("  ·  " + root.deletedCount) : "")
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                Component {
                    id: completedSectionComponent

                    CompletedTasksSectionV4 {
                        pluginRoot: root
                        controller: popoutColumn
                    }
                }

                Item {
                    width: parent.width
                    height: Math.max(addInput.implicitHeight, 40)
                    visible: popoutColumn.editorOpen

                    DankTextField {
                        id: addInput
                        anchors.left: parent.left
                        anchors.right: addButton.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        placeholderText: {
                            if (popoutColumn.editingId)
                                return "Edit and press Enter"
                            if (popoutColumn.addingChildOfId)
                                return "Subtask text and press Enter"
                            return "Task title"
                        }
                        maximumLength: root.maxTextLength
                        onAccepted: popoutColumn.submitComposer()
                        Keys.onEscapePressed: popoutColumn.cancelComposer()
                    }

                    Rectangle {
                        id: addButton
                        width: 40
                        height: 40
                        radius: Theme.cornerRadius
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        color: addArea.pressed ? Theme.primaryHover : Theme.primary

                        DankIcon {
                            anchors.centerIn: parent
                            name: "check"
                            size: 20
                            color: Theme.onPrimary
                        }

                        MouseArea {
                            id: addArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: popoutColumn.submitComposer()
                        }
                    }
                }

                Column {
                    id: metadataForm
                    width: parent.width
                    spacing: Theme.spacingM
                    visible: popoutColumn.editorOpen

                    Column {
                        width: parent.width
                        spacing: 5

                        StyledText {
                            text: "Due date"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        Item {
                            width: parent.width
                            height: 40

                            DankTextField {
                                id: dueDateInput
                                anchors.left: parent.left
                                anchors.right: datePickerButton.left
                                anchors.rightMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                placeholderText: "YYYY-MM-DD (optional)"
                            }

                            Rectangle {
                                id: datePickerButton
                                width: 40
                                height: 40
                                radius: Theme.cornerRadius
                                activeFocusOnTab: true
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                color: datePickerArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                                border.width: 1
                                border.color: activeFocus || popoutColumn.datePickerOpen ? Theme.primary : Theme.outlineVariant
                                Keys.onReturnPressed: popoutColumn.toggleDatePicker()
                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Space) {
                                        popoutColumn.toggleDatePicker()
                                        event.accepted = true
                                    }
                                }

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: "calendar_month"
                                    size: 19
                                    color: popoutColumn.datePickerOpen ? Theme.primary : Theme.surfaceText
                                }

                                MouseArea {
                                    id: datePickerArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    ToolTip.visible: containsMouse
                                    ToolTip.delay: 800
                                    ToolTip.text: "Choose date"
                                    onClicked: popoutColumn.toggleDatePicker()
                                }
                            }
                        }

                        Row {
                            id: dateShortcutRow
                            width: parent.width
                            spacing: Theme.spacingXS
                            property real choiceWidth: (width - spacing * 2) / 3

                            Repeater {
                                model: [
                                    { key: "today", label: "Today" },
                                    { key: "tomorrow", label: "Tomorrow" },
                                    { key: "nextMonday", label: "Next Monday" }
                                ]

                                Rectangle {
                                    readonly property string shortcutValue: root.shortcutDate(modelData.key, new Date())
                                    readonly property bool selected: root.normalizeDueDate(dueDateInput.text) === shortcutValue
                                    width: dateShortcutRow.choiceWidth
                                    height: 30
                                    radius: Theme.cornerRadius
                                    color: selected ? Theme.withAlpha(Theme.primary, 0.16) : (dateShortcutArea.containsMouse ? Theme.surfaceContainerHighest : "transparent")

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: parent.selected ? Font.Medium : Font.Normal
                                        color: parent.selected ? Theme.primary : Theme.surfaceVariantText
                                    }

                                    MouseArea {
                                        id: dateShortcutArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            dueDateInput.text = parent.shortcutValue
                                            popoutColumn.datePickerOpen = false
                                        }
                                    }
                                }
                            }
                        }

                        TodoCalendarGrid {
                            width: parent.width
                            height: visible ? implicitHeight : 0
                            visible: popoutColumn.datePickerOpen
                            todos: root.todos
                            showTaskCounts: true
                            onVisibleChanged: {
                                if (visible) {
                                    const initial = root.normalizeDueDate(dueDateInput.text) ? new Date(dueDateInput.text + "T12:00:00") : new Date()
                                    displayDate = initial
                                    selectedDate = initial
                                }
                            }
                            onDatePicked: value => {
                                dueDateInput.text = root.localDateKey(value)
                                popoutColumn.datePickerOpen = false
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 5

                        StyledText {
                            text: "Time"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        Rectangle {
                            id: timePickerButton
                            width: parent.width
                            height: 40
                            radius: Theme.cornerRadius
                            color: timePickerArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                            border.width: 1
                            border.color: popoutColumn.timePickerOpen ? Theme.primary : Theme.outlineVariant

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingM
                                anchors.rightMargin: Theme.spacingM
                                spacing: Theme.spacingS

                                DankIcon {
                                    name: "schedule"
                                    size: 18
                                    color: popoutColumn.composeDueTime ? Theme.primary : Theme.surfaceVariantText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    width: parent.width - 18 - 18 - parent.spacing * 2
                                    text: popoutColumn.composeDueTime || "All day"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: popoutColumn.composeDueTime ? Theme.surfaceText : Theme.surfaceVariantText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                DankIcon {
                                    name: popoutColumn.timePickerOpen ? "expand_less" : "expand_more"
                                    size: 18
                                    color: Theme.surfaceVariantText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: timePickerArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (popoutColumn.timePickerOpen)
                                        popoutColumn.timePickerOpen = false
                                    else
                                        popoutColumn.openTimePicker()
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: popoutColumn.timePickerOpen ? 104 : 0
                            visible: popoutColumn.timePickerOpen
                            radius: Theme.cornerRadius
                            color: Theme.surfaceContainerHigh

                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.spacingM

                                DankNumberStepper {
                                    text: popoutColumn.padTimePart(popoutColumn.timePickerHour)
                                    textSize: Theme.fontSizeMedium
                                    onIncrement: () => popoutColumn.shiftTimePicker(60)
                                    onDecrement: () => popoutColumn.shiftTimePicker(-60)
                                }

                                StyledText {
                                    text: ":"
                                    font.pixelSize: Theme.fontSizeLarge
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                DankNumberStepper {
                                    text: popoutColumn.padTimePart(popoutColumn.timePickerMinute)
                                    textSize: Theme.fontSizeMedium
                                    onIncrement: () => popoutColumn.shiftTimePicker(5)
                                    onDecrement: () => popoutColumn.shiftTimePicker(-5)
                                }

                                Column {
                                    spacing: Theme.spacingXS
                                    anchors.verticalCenter: parent.verticalCenter

                                    Rectangle {
                                        width: 72
                                        height: 32
                                        radius: Theme.cornerRadius
                                        color: timeDoneArea.containsMouse ? Theme.primaryHover : Theme.primary

                                        StyledText {
                                            anchors.centerIn: parent
                                            text: "Done"
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.onPrimary
                                        }

                                        MouseArea {
                                            id: timeDoneArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: popoutColumn.confirmTimePicker()
                                        }
                                    }

                                    Rectangle {
                                        width: 72
                                        height: 28
                                        radius: Theme.cornerRadius
                                        color: allDayArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                                        StyledText {
                                            anchors.centerIn: parent
                                            text: "All day"
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                        }

                                        MouseArea {
                                            id: allDayArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: popoutColumn.clearTimePicker()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 5
                        visible: Boolean(root.normalizeDueTime(popoutColumn.composeDueTime))

                        StyledText {
                            text: "Reminder"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        Row {
                            id: reminderChoices
                            width: parent.width
                            spacing: Theme.spacingXS
                            property real choiceWidth: (width - spacing * 4) / 5

                            Repeater {
                                model: [
                                    { key: null, label: "Off" },
                                    { key: 0, label: "At time" },
                                    { key: 10, label: "10m" },
                                    { key: 60, label: "1h" },
                                    { key: 1440, label: "1d" }
                                ]

                                Rectangle {
                                    width: reminderChoices.choiceWidth
                                    height: 32
                                    radius: Theme.cornerRadius
                                    color: popoutColumn.composeReminderMinutes === modelData.key ? Theme.primary : (reminderChoiceArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.pixelSize: Theme.fontSizeSmall * 0.9
                                        color: popoutColumn.composeReminderMinutes === modelData.key ? Theme.onPrimary : Theme.surfaceText
                                    }

                                    MouseArea {
                                        id: reminderChoiceArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: popoutColumn.composeReminderMinutes = modelData.key
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 5
                        visible: Boolean(root.normalizeDueDate(dueDateInput.text))

                        StyledText {
                            text: "Repeat"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        Row {
                            id: recurrenceChoices
                            width: parent.width
                            spacing: Theme.spacingXS
                            property real choiceWidth: (width - spacing * 4) / 5

                            Repeater {
                                model: [
                                    { key: "", label: "None" },
                                    { key: "daily", label: "Daily" },
                                    { key: "weekdays", label: "Mon–Fri" },
                                    { key: "weekly", label: "Weekly" },
                                    { key: "monthly", label: "Monthly" }
                                ]

                                Rectangle {
                                    width: recurrenceChoices.choiceWidth
                                    height: 32
                                    radius: Theme.cornerRadius
                                    color: popoutColumn.composeRecurrence === modelData.key ? Theme.primary : (recurrenceChoiceArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.pixelSize: Theme.fontSizeSmall * 0.82
                                        color: popoutColumn.composeRecurrence === modelData.key ? Theme.onPrimary : Theme.surfaceText
                                    }

                                    MouseArea {
                                        id: recurrenceChoiceArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: popoutColumn.composeRecurrence = modelData.key
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 5

                        StyledText {
                            text: "Priority"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        Row {
                            id: priorityChoices
                            width: parent.width
                            spacing: Theme.spacingXS
                            property real choiceWidth: (width - spacing * 3) / 4

                            Repeater {
                                model: [
                                    { key: "", label: "None" },
                                    { key: "low", label: "Low" },
                                    { key: "medium", label: "Medium" },
                                    { key: "high", label: "High" }
                                ]

                                Rectangle {
                                    width: priorityChoices.choiceWidth
                                    height: 32
                                    radius: Theme.cornerRadius
                                    color: popoutColumn.composePriority === modelData.key ? Theme.primary : (priorityChoiceArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)
                                    border.width: popoutColumn.composePriority === modelData.key ? 0 : 1
                                    border.color: modelData.key === "high" ? Theme.error : Theme.outlineVariant

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: popoutColumn.composePriority === modelData.key ? Theme.onPrimary : Theme.surfaceText
                                    }

                                    MouseArea {
                                        id: priorityChoiceArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: popoutColumn.composePriority = modelData.key
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 5

                        StyledText {
                            text: "Tags"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        DankTextField {
                            id: tagsInput
                            width: parent.width
                            placeholderText: "work, home (optional)"
                        }
                    }
                }

                Column {
                    id: schedulePage
                    width: parent.width
                    spacing: Theme.spacingM
                    visible: popoutColumn.calendarOpen

                    Row {
                        id: calendarModeRow
                        width: 152
                        spacing: Theme.spacingXS
                        property real choiceWidth: 72

                        Repeater {
                            model: [
                                { key: "week", label: "Week" },
                                { key: "month", label: "Month" }
                            ]

                            Item {
                                width: calendarModeRow.choiceWidth
                                height: 32

                                StyledText {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: popoutColumn.calendarMode === modelData.key ? Font.Medium : Font.Normal
                                    color: popoutColumn.calendarMode === modelData.key || modeArea.containsMouse ? Theme.primary : Theme.surfaceVariantText
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 2
                                    radius: 1
                                    visible: popoutColumn.calendarMode === modelData.key
                                    color: Theme.primary
                                }

                                MouseArea {
                                    id: modeArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: popoutColumn.calendarMode = modelData.key
                                }
                            }
                        }
                    }

                    Column {
                        id: weekCalendar
                        width: parent.width
                        spacing: Theme.spacingS
                        visible: popoutColumn.calendarMode === "week"

                        Row {
                            width: parent.width
                            height: 30

                            DankActionButton {
                                buttonSize: 28
                                iconSize: 15
                                iconName: "chevron_left"
                                iconColor: Theme.primary
                                onClicked: popoutColumn.shiftCalendarWeek(-1)
                            }

                            StyledText {
                                width: parent.width - 84
                                height: 28
                                text: {
                                    const start = root.startOfWeek(popoutColumn.calendarAnchorDate)
                                    const end = new Date(start)
                                    end.setDate(end.getDate() + 6)
                                    return start.toLocaleDateString(Qt.locale(), "MMM d") + " – " + end.toLocaleDateString(Qt.locale(), "MMM d, yyyy")
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            DankActionButton {
                                buttonSize: 28
                                iconSize: 15
                                iconName: "today"
                                iconColor: Theme.primary
                                onClicked: {
                                    popoutColumn.calendarAnchorDate = new Date()
                                    popoutColumn.selectedCalendarDate = new Date()
                                }
                            }

                            DankActionButton {
                                buttonSize: 28
                                iconSize: 15
                                iconName: "chevron_right"
                                iconColor: Theme.primary
                                onClicked: popoutColumn.shiftCalendarWeek(1)
                            }
                        }

                        Row {
                            width: parent.width
                            height: 68
                            spacing: Theme.spacingXXS

                            Repeater {
                                model: 7

                                Rectangle {
                                    id: weekDayCell
                                    readonly property date dayDate: {
                                        const day = root.startOfWeek(popoutColumn.calendarAnchorDate)
                                        day.setDate(day.getDate() + index)
                                        return day
                                    }
                                    readonly property bool selected: root.localDateKey(dayDate) === root.localDateKey(popoutColumn.selectedCalendarDate)
                                    readonly property bool today: root.localDateKey(dayDate) === root.localDateKey(new Date())
                                    readonly property int count: root.activeTaskCountForDate(dayDate)

                                    width: (parent.width - parent.spacing * 6) / 7
                                    height: parent.height
                                    radius: Theme.cornerRadius
                                    color: selected ? Theme.withAlpha(Theme.primary, 0.14) : (weekDayArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHigh, 0.55) : "transparent")
                                    border.width: today ? 1 : 0
                                    border.color: Theme.primary

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 3

                                        StyledText {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: weekDayCell.dayDate.toLocaleDateString(Qt.locale(), "ddd")
                                            font.pixelSize: Theme.fontSizeSmall * 0.82
                                            color: Theme.surfaceVariantText
                                        }

                                        StyledText {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: weekDayCell.dayDate.getDate()
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: weekDayCell.selected || weekDayCell.today ? Font.Medium : Font.Normal
                                            color: weekDayCell.selected || weekDayCell.today ? Theme.primary : Theme.surfaceText
                                        }

                                        StyledText {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            visible: weekDayCell.count > 0
                                            text: weekDayCell.count
                                            font.pixelSize: 9
                                            color: Theme.primary
                                        }
                                    }

                                    MouseArea {
                                        id: weekDayArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: popoutColumn.selectedCalendarDate = weekDayCell.dayDate
                                    }
                                }
                            }
                        }
                    }

                    TodoCalendarGrid {
                        id: monthCalendar
                        width: parent.width
                        height: visible ? implicitHeight : 0
                        visible: popoutColumn.calendarMode === "month"
                        todos: root.todos
                        showTaskCounts: true
                        onVisibleChanged: {
                            if (visible) {
                                displayDate = popoutColumn.calendarAnchorDate
                                selectedDate = popoutColumn.selectedCalendarDate
                            }
                        }
                        onDatePicked: value => {
                            popoutColumn.selectedCalendarDate = value
                            popoutColumn.calendarAnchorDate = value
                        }
                    }

                    Row {
                        width: parent.width
                        height: 30

                        StyledText {
                            width: parent.width - 30
                            height: parent.height
                            text: popoutColumn.selectedCalendarDate.toLocaleDateString(Qt.locale(), "dddd, MMMM d")
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            verticalAlignment: Text.AlignVCenter
                        }

                        DankActionButton {
                            buttonSize: 28
                            iconSize: 17
                            iconName: "add"
                            iconColor: Theme.primary
                            onClicked: popoutColumn.startCreatingForDate(popoutColumn.selectedCalendarDate)
                        }
                    }

                    Item {
                        width: parent.width
                        height: Math.min(popoutColumn.calendarMode === "month" ? 130 : 240, Math.max(48, calendarTaskList.contentHeight))

                        ListView {
                            id: calendarTaskList
                            anchors.fill: parent
                            spacing: Theme.spacingXXS
                            clip: true
                            model: root.tasksForDate(popoutColumn.selectedCalendarDate)

                            delegate: Item {
                                width: calendarTaskList.width
                                height: calendarRow.implicitHeight

                                property var taskObject: modelData
                                property string taskTitle: String(modelData && modelData.text !== undefined ? modelData.text : "")

                                TodoTaskRowV4 {
                                    id: calendarRow
                                    anchors.fill: parent
                                    pluginRoot: root
                                    controller: popoutColumn
                                    taskData: parent.taskObject
                                    taskText: parent.taskTitle
                                    mode: parent.taskObject && parent.taskObject.completed ? "completed" : "calendar"
                                    dragEnabled: false
                                }
                            }

                            StyledText {
                                anchors.centerIn: parent
                                visible: calendarTaskList.count === 0
                                text: "No tasks due"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 40
                    visible: !popoutColumn.editorOpen && !popoutColumn.trashOpen && !popoutColumn.calendarOpen

                    DankTextField {
                        id: searchInput
                        anchors.left: parent.left
                        anchors.right: sortButton.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        placeholderText: "Search tasks and tags"
                        onTextChanged: root.searchQuery = text
                    }

                    Rectangle {
                        id: sortButton
                        width: 40
                        height: 40
                        radius: Theme.cornerRadius
                        activeFocusOnTab: true
                        anchors.right: calendarButton.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        color: {
                            if (sortArea.containsMouse || popoutColumn.sortMenuOpen)
                                return Theme.withAlpha(Theme.primary, 0.18)
                            return root.sortMode === "manual" ? "transparent" : Theme.withAlpha(Theme.primary, 0.11)
                        }
                        border.width: 1
                        border.color: activeFocus || root.sortMode !== "manual" ? Theme.primary : "transparent"
                        Keys.onReturnPressed: popoutColumn.sortMenuOpen = !popoutColumn.sortMenuOpen
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Space) {
                                popoutColumn.sortMenuOpen = !popoutColumn.sortMenuOpen
                                event.accepted = true
                            }
                        }

                        DankIcon {
                            anchors.centerIn: parent
                            name: "sort"
                            size: 19
                            color: root.sortMode === "manual" ? Theme.surfaceVariantText : Theme.primary
                        }

                        MouseArea {
                            id: sortArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            ToolTip.visible: containsMouse
                            ToolTip.delay: 800
                            ToolTip.text: root.sortMode === "due" ? "Sort: Due date" : (root.sortMode === "priority" ? "Sort: Priority" : "Sort: Manual")
                            onClicked: popoutColumn.sortMenuOpen = !popoutColumn.sortMenuOpen
                        }
                    }

                    Rectangle {
                        id: calendarButton
                        width: 40
                        height: 40
                        radius: Theme.cornerRadius
                        activeFocusOnTab: true
                        anchors.right: createButton.left
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        color: calendarArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.2) : Theme.withAlpha(Theme.primary, 0.11)
                        border.width: 1
                        border.color: activeFocus ? Theme.primary : "transparent"
                        Keys.onReturnPressed: popoutColumn.openCalendar()
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Space) {
                                popoutColumn.openCalendar()
                                event.accepted = true
                            }
                        }

                        DankIcon {
                            anchors.centerIn: parent
                            name: "calendar_month"
                            size: 19
                            color: Theme.primary
                        }

                        MouseArea {
                            id: calendarArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            ToolTip.visible: containsMouse
                            ToolTip.delay: 800
                            ToolTip.text: "Schedule"
                            onClicked: popoutColumn.openCalendar()
                        }
                    }

                    Rectangle {
                        id: createButton
                        width: 40
                        height: 40
                        radius: Theme.cornerRadius
                        activeFocusOnTab: true
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        color: createArea.pressed ? Theme.primaryHover : Theme.primary
                        border.width: 1
                        border.color: activeFocus ? Theme.onPrimary : "transparent"
                        Keys.onReturnPressed: popoutColumn.startCreating()
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Space) {
                                popoutColumn.startCreating()
                                event.accepted = true
                            }
                        }

                        DankIcon {
                            anchors.centerIn: parent
                            name: "add"
                            size: 21
                            color: Theme.onPrimary
                        }

                        MouseArea {
                            id: createArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            ToolTip.visible: containsMouse
                            ToolTip.delay: 800
                            ToolTip.text: "New task"
                            onClicked: popoutColumn.startCreating()
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: visible ? 32 : 0
                    visible: !popoutColumn.editorOpen && !popoutColumn.trashOpen && !popoutColumn.calendarOpen && popoutColumn.sortMenuOpen

                    Row {
                        id: sortChoices
                        anchors.fill: parent
                        spacing: Theme.spacingXS
                        property real choiceWidth: (width - spacing * 2) / 3

                        Repeater {
                            model: [
                                { key: "manual", label: "Manual" },
                                { key: "due", label: "Due date" },
                                { key: "priority", label: "Priority" }
                            ]

                            Rectangle {
                                width: sortChoices.choiceWidth
                                height: parent.height
                                radius: Theme.cornerRadius
                                color: root.sortMode === modelData.key ? Theme.withAlpha(Theme.primary, 0.16) : (sortChoiceArea.containsMouse ? Theme.surfaceContainerHighest : "transparent")

                                StyledText {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: root.sortMode === modelData.key ? Font.Medium : Font.Normal
                                    color: root.sortMode === modelData.key ? Theme.primary : Theme.surfaceVariantText
                                }

                                MouseArea {
                                    id: sortChoiceArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.setSortMode(modelData.key)
                                        popoutColumn.sortMenuOpen = false
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    id: listContainer
                    width: parent.width
                    height: Math.min(320, Math.max(48, todoList.contentHeight))
                    visible: !popoutColumn.editorOpen && !popoutColumn.calendarOpen

                    property string dragId: ""
                    readonly property int indentStep: 20

                    ListView {
                        id: todoList
                        anchors.fill: parent
                        spacing: Theme.spacingXXS
                        clip: listContainer.dragId === ""
                        interactive: listContainer.dragId === ""
                        model: {
                            if (popoutColumn.trashOpen)
                                return root.filteredTodos("trash")
                            return root.filteredTodos("active")
                        }

                        displaced: Transition {
                            NumberAnimation {
                                properties: "y"
                                duration: 180
                                easing.type: Easing.OutQuad
                            }
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

                        delegate: Item {
                            id: slot
                            width: todoList.width - (todoScrollBar.visible ? (todoScrollBar.width + Theme.spacingS) : 0)
                            height: taskRow.implicitHeight

                            property string itemId: modelData ? modelData.id : ""
                            property int depth: modelData && !popoutColumn.trashOpen ? root.depthOf(modelData.id) : 0
                            property string dropZone: ""
                            readonly property bool isDragSource: listContainer.dragId === slot.itemId
                            readonly property bool acceptsDrag: {
                                if (!listContainer.dragId || popoutColumn.trashOpen || root.sortMode !== "manual" || slot.isDragSource)
                                    return false
                                return !root.isDescendant(slot.itemId, listContainer.dragId)
                            }

                            Item {
                                id: dragProxy
                                width: slot.width
                                height: slot.height
                                z: slot.isDragSource ? 1000 : 0

                                Drag.active: taskRow.dragging && !popoutColumn.trashOpen && root.sortMode === "manual"
                                Drag.source: slot
                                Drag.hotSpot.x: dragProxy.width / 2
                                Drag.hotSpot.y: dragProxy.height / 2

                                TodoTaskRowV4 {
                                    id: taskRow
                                    x: slot.depth * listContainer.indentStep
                                    width: dragProxy.width - x
                                    height: implicitHeight
                                    pluginRoot: root
                                    controller: popoutColumn
                                    taskData: modelData
                                    taskText: String(modelData.text || "")
                                    mode: popoutColumn.trashOpen ? "trash" : "active"
                                    dragTarget: dragProxy
                                    dragEnabled: !popoutColumn.trashOpen && root.sortMode === "manual"
                                    dragSource: slot.isDragSource
                                    childDropTarget: listContainer.dragId && slot.dropZone === "child" && slot.acceptsDrag

                                    onDragBegan: listContainer.dragId = slot.itemId
                                    onDragFinished: {
                                        dragProxy.Drag.drop()
                                        listContainer.dragId = ""
                                        dragProxy.x = 0
                                        dragProxy.y = 0
                                    }
                                    onDragCancelled: {
                                        listContainer.dragId = ""
                                        dragProxy.x = 0
                                        dragProxy.y = 0
                                    }
                                }

                                Rectangle {
                                    anchors.left: taskRow.left
                                    anchors.right: taskRow.right
                                    anchors.top: taskRow.top
                                    anchors.topMargin: -1
                                    height: 2
                                    radius: 1
                                    color: Theme.primary
                                    visible: slot.dropZone === "before" && slot.acceptsDrag
                                }

                                Rectangle {
                                    anchors.left: taskRow.left
                                    anchors.right: taskRow.right
                                    anchors.bottom: taskRow.bottom
                                    anchors.bottomMargin: -1
                                    height: 2
                                    radius: 1
                                    color: Theme.primary
                                    visible: slot.dropZone === "after" && slot.acceptsDrag
                                }
                            }

                            DropArea {
                                anchors.fill: parent

                                onPositionChanged: drag => {
                                    if (!slot.acceptsDrag) {
                                        slot.dropZone = ""
                                        return
                                    }
                                    const y = drag.y
                                    const h = slot.height
                                    if (y < h * 0.25)
                                        slot.dropZone = "before"
                                    else if (y > h * 0.75)
                                        slot.dropZone = "after"
                                    else
                                        slot.dropZone = "child"
                                }
                                onExited: slot.dropZone = ""
                                onDropped: drop => {
                                    const sourceId = listContainer.dragId
                                    const zone = slot.dropZone
                                    slot.dropZone = ""
                                    if (sourceId && zone && slot.acceptsDrag)
                                        root.moveTodo(sourceId, slot.itemId, zone)
                                }
                            }
                        }

                        StyledText {
                            anchors.centerIn: parent
                            visible: todoList.count === 0
                            text: popoutColumn.trashOpen ? "Trash is empty" : (root.searchQuery ? "No matching active tasks" : "No active tasks")
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }

                Loader {
                    width: parent.width
                    active: visible
                    visible: !popoutColumn.editorOpen && !popoutColumn.calendarOpen && !popoutColumn.trashOpen
                    sourceComponent: completedSectionComponent
                    height: visible && item ? item.implicitHeight : 0
                }

                Item {
                    width: parent.width
                    height: 30
                    visible: !popoutColumn.editorOpen && !popoutColumn.calendarOpen && (!popoutColumn.trashOpen || root.deletedCount > 0)

                    Rectangle {
                        id: trashButton
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        height: 30
                        radius: Theme.cornerRadius
                        activeFocusOnTab: true
                        visible: !popoutColumn.trashOpen
                        color: trashArea.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                        border.width: 1
                        border.color: activeFocus ? Theme.primary : "transparent"
                        Keys.onReturnPressed: popoutColumn.openTrash()
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Space) {
                                popoutColumn.openTrash()
                                event.accepted = true
                            }
                        }

                        DankIcon {
                            anchors.centerIn: parent
                            name: "delete_outline"
                            size: 17
                            color: root.deletedCount > 0 ? Theme.primary : Theme.surfaceText
                        }

                        MouseArea {
                            id: trashArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            ToolTip.visible: containsMouse
                            ToolTip.delay: 800
                            ToolTip.text: "Trash"
                            onClicked: popoutColumn.openTrash()
                        }
                    }

                    Rectangle {
                        id: clearButton
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: clearLabel.implicitWidth + Theme.spacingM * 2
                        height: 30
                        visible: popoutColumn.trashOpen && root.deletedCount > 0
                        radius: Theme.cornerRadius
                        color: clearArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                        border.width: 1
                        border.color: Theme.outlineVariant

                        StyledText {
                            id: clearLabel
                            anchors.centerIn: parent
                            text: "Empty trash"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                        }

                        MouseArea {
                            id: clearArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.emptyTrash()
                        }
                    }
                }
            }
        }
    }
}
