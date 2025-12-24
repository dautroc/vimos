# VimOS

VimOS brings Vim-like modal editing capabilities to the macOS operating system environment. It intercepts keyboard events to simulate Vim motions and operators in any text field.

## Features

### Global Shortcuts

- **Option + V**: Toggle VimOS Enabled/Disabled globally.

### Modes

- **Normal Mode**: Navigation and command execution (Default).
- **Insert Mode**: Standard typing.
- **Visual Mode**: Character-wise selection.
- **Visual Line Mode**: Line-wise selection.

### Supported Motions & Commands

#### Navigation

- `h`, `j`, `k`, `l`: Left, Down, Up, Right
- `w`: Move forward by word
- `b`: Move backward by word
- `e`: Move to end of word
- `0`: Move to start of line
- `$`: Move to end of line
- `^`: Move to first non-whitespace character of line
- `gg`: Move to start of document
- `G`: Move to end of document
- `t{char}`: Move cursor to before the next occurrence of `{char}`

#### Editing

- `i`: Insert before cursor
- `a`: Insert after cursor (Append)
- `A`: Insert at end of line (Append Line)
- `o`: Open new line below and enter Insert Mode
- `O`: Open new line above and enter Insert Mode
- `x`: Delete character under cursor
- `r{char}`: Replace character under cursor with `{char}`
- `u`: Undo
- `Ctrl+r`: Redo
- `cc`: Change current line (delete line and enter Insert Mode)
- `C`: Change from cursor to end of line
- `ci{object}`: Change Inner Object
  - Supports: `"` (quotes), `'` (single quotes), `` ` `` (backticks)
  - Supports: `(` or `)` or `b` (parentheses)
  - Supports: `{` or `}` or `B` (curly braces)
  - Supports: `[` or `]` (brackets)
  - Supports: `<` or `>` (angle brackets)

#### Yank & Paste (Clipboard)

- `yy`: Yank (copy) current line
- `Y`: Yank from cursor to end of line
- `p`: Paste after cursor (or below line if linewise)
- `P`: Paste before cursor (or above line if linewise)

#### Visual Selection

- `v`: Toggle Visual Mode (Character-wise)
- `V`: Toggle Visual Line Mode (Line-wise)
- `h`, `j`, `k`, `l`, `w`, `b`, `e`, `$`, `0`, `^`: Expand/Contract selection
- `d`: Delete selection
- `c`: Change selection (delete and enter Insert Mode)
- `y`: Yank selection
- `p`: Paste over selection (Replace)

## Installation & Build

### Installation

To install the application:

1. Download and unzip the release.
2. Run the following command to prepare the app (clears quarantine attributes):
   ```bash
   xattr -c path_to_VimOS
   ```
   _(Replace `path_to_VimOS` with the actual path to your `VimOS.app`)_
3. Move `VimOS.app` to `/Applications` and launch it.
4. Grant Accessibility permissions when prompted.
5. **Restart the application** to ensure full functionality.

### Building from Source

To build the application manually, use the provided release script:

```bash
./scripts/release.sh v1.0.0
```

This command will:

1. Build the Swift project in Release mode.
2. Generate the `VimOS.app` bundle with the correct icon and structure.
3. Create a `VimOS_v1.0.0.zip` archive ready for distribution.

Alternatively, for development/debugging:

```bash
swift run VimOS
```

## Configuration

VimOS supports customizable key mappings and application suppression via a JSON configuration file located at `~/.vimos/config.json`.

### Example Configuration

```json
{
  "mappings": [
    {
      "from": "jk",
      "to": "<esc>",
      "modes": ["insert"]
    },
    {
      "from": "gh",
      "to": "^",
      "modes": ["normal"]
    },
    {
      "from": "gl",
      "to": "$",
      "modes": ["normal"]
    }
  ],
  "ignoredApplications": [
    "com.apple.Terminal",
    "com.googlecode.iterm2",
    "com.microsoft.VSCode"
  ],
  "toggleShortcut": "Option+v"
}
```

### Options

- **mappings**: Array of mapping objects.
  - `from`: The key sequence to trigger the mapping (case-sensitive).
  - `to`: The target key or action (supports `^`, `$`, `<esc>`).
  - `modes`: List of modes where the mapping is active (`normal`, `insert`, `visual`). Defaults to all if omitted.
- **ignoredApplications**: List of Bundle Identifiers for applications where VimOS should be disabled.
  - Note: Terminal emulators (iTerm2, Terminal) are often best ignored to avoid conflict with their internal Vim.
- **toggleShortcut**: Global shortcut to toggle VimOS (Default: "Option+v").
  - Format: "Modifier+key" (e.g. "Option+s").
  - Supported modifiers: `Option`, `Alt`, `Command`, `Cmd`, `Control`, `Ctrl`, `Shift`.

## Development

### Running the Application

To start the VimOS application:

```bash
swift run VimOS
```

Requires Accessibility permissions to control the cursor and intercept keys. The app will prompt for permissions on first launch.
Ensure you grant access in **System Settings > Privacy & Security > Accessibility**.

### Running Tests

VimOS includes a custom test runner to verify logic without side effects.

```bash
swift run VimOSTestRunner
```

## Architecture

- **VimOSCore**: The core logic library containing `VimEngine` and `AccessibilityManager`.
- **VimOS**: The main executable that hooks into macOS events.
- **VimOSTestRunner**: A standalone executable for running unit tests.

## Requirements

- macOS 10.13+
- Swift 6.0+
