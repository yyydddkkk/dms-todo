.pragma library

function localDateKey(date) {
    const y = date.getFullYear()
    const month = date.getMonth() + 1
    const day = date.getDate()
    const m = month < 10 ? ("0" + month) : String(month)
    const d = day < 10 ? ("0" + day) : String(day)
    return y + "-" + m + "-" + d
}

function normalizeDueDate(value) {
    const text = String(value || "").trim()
    if (!text)
        return ""
    const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(text)
    if (!match)
        return ""
    const date = new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]))
    return localDateKey(date) === text ? text : ""
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
    if (value === null || value === undefined || value === "")
        return null
    const n = Number(value)
    return (n === 0 || n === 10 || n === 60 || n === 1440) ? n : null
}

function normalizeRecurrence(value) {
    const recurrence = String(value || "").toLowerCase()
    return (recurrence === "daily" || recurrence === "weekdays" || recurrence === "weekly" || recurrence === "monthly") ? recurrence : ""
}

function normalizePriority(value) {
    const priority = String(value || "").toLowerCase()
    return (priority === "high" || priority === "medium" || priority === "low") ? priority : ""
}

function normalizeTags(value) {
    const raw = Array.isArray(value) ? value : String(value || "").split(/[\s,]+/)
    const result = []
    const seen = new Set()
    for (let i = 0; i < raw.length; i++) {
        const tag = String(raw[i] || "").trim().replace(/^#+/, "").substring(0, 30)
        const key = tag.toLowerCase()
        if (tag && !seen.has(key)) {
            seen.add(key)
            result.push(tag)
        }
        if (result.length >= 10)
            break
    }
    return result
}

function dueLabel(dueDate, today) {
    if (!dueDate)
        return ""
    const todayKey = localDateKey(today)
    const tomorrow = new Date(today)
    tomorrow.setDate(tomorrow.getDate() + 1)
    if (dueDate === todayKey)
        return "Today"
    if (dueDate === localDateKey(tomorrow))
        return "Tomorrow"
    return dueDate
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

function startOfWeek(date, firstDayOfWeek) {
    const result = new Date(date)
    const firstDay = Number(firstDayOfWeek) % 7
    const diff = (result.getDay() - firstDay + 7) % 7
    result.setDate(result.getDate() - diff)
    result.setHours(12, 0, 0, 0)
    return result
}
