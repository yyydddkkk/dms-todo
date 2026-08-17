import QtQuick
import qs.Common
import qs.Widgets
import "TodoUtils.js" as TodoUtils

Item {
    id: calendar

    property date displayDate: new Date()
    property date selectedDate: new Date()
    property var todos: []
    property bool showTaskCounts: true
    signal datePicked(date value)

    implicitHeight: 276

    function localDateKey(date) {
        return TodoUtils.localDateKey(date)
    }

    function weekStartJs() {
        return Qt.locale().firstDayOfWeek % 7
    }

    function startOfWeek(date) {
        return TodoUtils.startOfWeek(date, Qt.locale().firstDayOfWeek)
    }

    function taskCount(date) {
        const key = localDateKey(date)
        let count = 0
        for (let i = 0; i < todos.length; i++) {
            const task = todos[i]
            if (!task.deletedAt && !task.completed && task.dueDate === key)
                count++
        }
        return count
    }

    function shiftMonth(delta) {
        const next = new Date(displayDate.getFullYear(), displayDate.getMonth() + delta, 1)
        displayDate = next
    }

    Column {
        anchors.fill: parent
        spacing: Theme.spacingS

        Row {
            width: parent.width
            height: 30

            DankActionButton {
                buttonSize: 28
                iconSize: 15
                iconName: "chevron_left"
                iconColor: Theme.primary
                onClicked: calendar.shiftMonth(-1)
            }

            StyledText {
                width: parent.width - 84
                height: 28
                text: calendar.displayDate.toLocaleDateString(Qt.locale(), "MMMM yyyy")
                font.pixelSize: Theme.fontSizeMedium
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
                    const now = new Date()
                    calendar.displayDate = now
                    calendar.selectedDate = now
                    calendar.datePicked(now)
                }
            }

            DankActionButton {
                buttonSize: 28
                iconSize: 15
                iconName: "chevron_right"
                iconColor: Theme.primary
                onClicked: calendar.shiftMonth(1)
            }
        }

        Row {
            width: parent.width
            height: 18

            Repeater {
                model: {
                    const names = []
                    const first = calendar.weekStartJs()
                    for (let i = 0; i < 7; i++) {
                        const date = new Date(2026, 7, 16 + ((first + i) % 7))
                        names.push(date.toLocaleDateString(Qt.locale(), "ddd"))
                    }
                    return names
                }

                StyledText {
                    width: parent.width / 7
                    height: 18
                    text: modelData
                    font.pixelSize: Theme.fontSizeSmall * 0.9
                    font.weight: Font.Medium
                    color: Theme.surfaceVariantText
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        Grid {
            id: monthGrid
            width: parent.width
            height: parent.height - 30 - 18 - parent.spacing * 2
            columns: 7
            rows: 6

            readonly property date firstDay: {
                const first = new Date(calendar.displayDate.getFullYear(), calendar.displayDate.getMonth(), 1)
                return calendar.startOfWeek(first)
            }

            Repeater {
                model: 42

                Rectangle {
                    id: dayCell
                    readonly property date dayDate: {
                        const result = new Date(monthGrid.firstDay)
                        result.setDate(result.getDate() + index)
                        return result
                    }
                    readonly property bool currentMonth: dayDate.getMonth() === calendar.displayDate.getMonth()
                    readonly property bool today: calendar.localDateKey(dayDate) === calendar.localDateKey(new Date())
                    readonly property bool selected: calendar.localDateKey(dayDate) === calendar.localDateKey(calendar.selectedDate)
                    readonly property int count: calendar.taskCount(dayDate)

                    width: monthGrid.width / 7
                    height: monthGrid.height / 6
                    radius: Theme.cornerRadius
                    color: selected ? Theme.withAlpha(Theme.primary, 0.14) : (dayArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHigh, 0.55) : "transparent")
                    border.width: today ? 1 : 0
                    border.color: Theme.primary

                    StyledText {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: dayCell.count > 0 && calendar.showTaskCounts ? -4 : 0
                        text: dayCell.dayDate.getDate()
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: dayCell.selected || dayCell.today ? Font.Medium : Font.Normal
                        color: dayCell.currentMonth ? Theme.surfaceText : Theme.surfaceVariantText
                    }

                    StyledText {
                        visible: calendar.showTaskCounts && dayCell.count > 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        text: dayCell.count
                        font.pixelSize: 9
                        color: dayCell.selected ? Theme.primary : Theme.surfaceVariantText
                        opacity: 0.82
                    }

                    MouseArea {
                        id: dayArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            calendar.selectedDate = dayCell.dayDate
                            calendar.displayDate = dayCell.dayDate
                            calendar.datePicked(dayCell.dayDate)
                        }
                    }
                }
            }
        }
    }
}
