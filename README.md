# Dank Todo

A local-first task manager for the [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) bar.

![Screenshot](screenshot.png)

## Features

- Dedicated create/edit page opened from the main list
- One-click toggle between active/completed
- Per-item delete (cascades to subtasks) and "Clear completed" both soft-delete items in storage
- Unified task page with active tasks first and a collapsed, independently scrollable Completed section below
- Trash is a separate page with restore, permanent-delete, and empty-trash actions
- Due dates, priorities, and tags with inline editing
- Integrated calendar date picker in the create/edit page
- Dedicated schedule page with week and month views, per-day task counts, and dated task lists
- Optional due times with desktop reminders at the due time or 10 minutes, 1 hour, or 1 day early
- Daily, weekday, weekly, and monthly recurring tasks that retain completed history
- Create a task directly from the selected day in the schedule page
- Search across task text and tags
- **Drag-and-drop reordering and nesting** — drag a task row and drop above, below, or onto another task
- Unlimited nesting depth, with indented display
- Pill count mode — show active, total, done, or hide the badge
- Storage location configurable; defaults to `$XDG_CONFIG_HOME/dank-todo/todos.json`
- Atomic JSON writes, safe against corruption
- IPC commands for scripting and keybindings

## Code structure

- `DankTodoWidget.qml` — plugin entry, persistence, IPC, and page coordination
- `TodoTaskRowV4.qml` — active shared task row with compact schedule metadata and overflow actions (older versions are retained for DMS cache compatibility)
- `CompletedTasksSectionV4.qml` — active completed-task section and its independent list (older versions are retained for cache compatibility)
- `TodoCalendarGrid.qml` — reusable month grid for date selection and schedule views
- `TodoUtils.js` — pure date, priority, and tag helpers
- `DankTodoSettings.qml` — plugin settings page

## Installation

### Via DMS GUI

1. Open DMS Settings (`Mod` + `,`)
2. Go to the Plugins tab → Browse → enable third-party plugins
3. Install **Dank Todo**
4. Enable it with the toggle, then add the widget to a bar section

### Via DMS CLI

```bash
dms plugins install dankTodo
```

### Manually

```bash
cd ~/.config/DankMaterialShell/plugins
git clone https://github.com/yyydddkkk/dms-todo dankTodo
```

Then in DMS Settings → Plugins, click "Scan for Plugins" and enable **Dank Todo**.

## Usage

Click the pill in the bar to open the popout. The main page is dedicated to browsing and searching tasks. Click the **+** button beside search to open the separate creation page, enter a title and optional date, time, reminder, recurrence, priority, and tags, then save. The schedule page also has a **+** action that preselects the visible date. Click the circle to toggle, the trash icon to delete, or "Clear completed" to move done items to Trash. Deleted tasks can be restored or permanently removed from the Trash view.

All-day tasks do not send notifications. Timed tasks can remind at the due time or in advance. After a reminder fires, use **Snooze 10 minutes** in the task menu to postpone it. Completing a recurring task keeps the completed occurrence and creates the next future occurrence on the original cadence.

Each row also has edit (`✎`) and subtask (`⤵`) buttons next to delete:

- **Edit** — populates the main input with the row's text and switches to "Editing: …" mode. Enter saves, Escape (or the × on the chip) cancels.
- **Subtask** — switches the main input to "Subtask of: …" mode. Enter adds the new todo as a child of that row, Escape (or ×) cancels.

The two modes are exclusive — triggering one clears the other. The + button on the input turns into a ✓ when editing.

**Reordering and grouping**: each non-trash row has a drag handle on the left. While dragging:

- Drop in the **top quarter** of a row → insert as a sibling **before** it
- Drop in the **bottom quarter** → insert as a sibling **after** it (after its entire subtree)
- Drop in the **middle** → become a **child** of that row (indented below it)

A blue line marks sibling drops; a tinted background marks child drops. Dropping a todo onto itself or onto one of its own descendants is blocked.

## Settings

- **Storage directory** — override the default `$XDG_CONFIG_HOME/dank-todo` location
- **Bar pill count** — Active / Total / Done / Hidden
- **Maximum todos** — cap the list size (default 200)
- **Maximum characters per todo** — longer entries are truncated (default 500)

## IPC

```bash
dms ipc call dankTodo add "Buy milk"
dms ipc call dankTodo addChild "Whole milk" <parentId>
dms ipc call dankTodo edit <id> "New text"
dms ipc call dankTodo setDetails <id> 2026-08-17 high work,urgent
dms ipc call dankTodo setSchedule <id> 2026-08-17 09:00 10 weekly
dms ipc call dankTodo snooze <id>
dms ipc call dankTodo toggle <id>
dms ipc call dankTodo remove <id>
dms ipc call dankTodo restore <id>
dms ipc call dankTodo purge <id>
dms ipc call dankTodo emptyTrash
dms ipc call dankTodo move <sourceId> <targetId> <position>   # position: before | after | child
dms ipc call dankTodo clearDone
dms ipc call dankTodo list       # returns JSON array
dms ipc call dankTodo count      # returns "active/total"
```

Great for binding "add todo from current clipboard" to a key in your compositor.

### Niri keybinding example

```kdl
binds {
    Mod+Shift+T hotkey-overlay-title="Add clipboard to Todo" {
        spawn "sh" "-c" "dms ipc call dankTodo add \"$(wl-paste -n)\"";
    }
}
```

## Data format

Todos are stored as plain JSON. Back it up or sync it however you like:

```json
{
  "version": 4,
  "todos": [
    {
      "id": "parent-1",
      "text": "Shopping",
      "completed": false,
      "parentId": null,
      "createdAt": "2026-04-22T14:00:00.000Z",
      "dueDate": "2026-04-23",
      "dueTime": "09:00",
      "reminderMinutes": 10,
      "recurrence": "weekly",
      "reminderState": {},
      "priority": "high",
      "tags": ["shopping"]
    },
    {
      "id": "child-1",
      "text": "Buy milk",
      "completed": false,
      "parentId": "parent-1",
      "createdAt": "2026-04-22T14:00:10.000Z"
    }
  ]
}
```

Array order is display order; `parentId: null` means top-level. Soft-deleted items are retained with `deletedAt`, hidden from normal views and available in Trash. The loader migrates older version 1–3 data automatically; missing schedule fields, priorities, and tags receive safe defaults. Reminder state is persisted so plugin reloads do not duplicate notifications.

## Requirements

- DankMaterialShell
- Niri window manager (though the plugin has no compositor-specific code)

## License

MIT
