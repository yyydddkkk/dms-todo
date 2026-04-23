# Dank Todo

A simple, locally-saved TODO list widget for the [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) bar.

![Screenshot](screenshot.png)

## Features

- Quick-add input (Enter to submit) right in the popout
- One-click toggle between active/completed
- Per-item delete, plus "Clear completed" shortcut
- Filter chips: All / Active / Done
- Pill count mode — show active, total, done, or hide the badge
- Storage location configurable; defaults to `$XDG_CONFIG_HOME/dank-todo/todos.json`
- Atomic JSON writes, safe against corruption
- IPC commands for scripting and keybindings

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
git clone https://github.com/deepu105/dms-dank-todo dankTodo
```

Then in DMS Settings → Plugins, click "Scan for Plugins" and enable **Dank Todo**.

## Usage

Click the pill in the bar to open the popout. Type a todo and press Enter. Click the circle to toggle, the trash icon to delete, or "Clear completed" to wipe done items.

## Settings

- **Storage directory** — override the default `$XDG_CONFIG_HOME/dank-todo` location
- **Bar pill count** — Active / Total / Done / Hidden
- **Maximum todos** — cap the list size (default 200)
- **Maximum characters per todo** — longer entries are truncated (default 500)

## IPC

```bash
dms ipc call dankTodo add "Buy milk"
dms ipc call dankTodo toggle <id>
dms ipc call dankTodo remove <id>
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
    "version": 1,
    "todos": [
        {
            "id": "…",
            "text": "Buy milk",
            "completed": false,
            "createdAt": "2026-04-22T14:00:00.000Z"
        }
    ]
}
```

## Requirements

- DankMaterialShell
- Niri window manager (though the plugin has no compositor-specific code)

## License

MIT
