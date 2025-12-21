# VimOS

VimOS brings Vim-like modal editing capabilities to the macOS operating system environment. It intercepts keyboard events to simulate Vim motions and operators in any text field.

## Features

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

#### Editing

- `i`: Enter Insert Mode
- `x`: Delete character under cursor
- `u`: Undo
- `Ctrl+r`: Redo
- `cc`: Change current line (delete line and enter Insert Mode)
- `o`: Open new line below and enter Insert Mode
- `O`: Open new line above and enter Insert Mode

#### Visual Selection

- `v`: Toggle Visual Mode
- `V`: Toggle Visual Line Mode
- `d` (in Visual): Delete selection
- `c` (in Visual): Change selection

## Usage

### Running the Application

To start the VimOS application:

```bash
swift run VimOS
```

Requires Accessibility permissions to control the cursor and intercept keys. The app will prompt for permissions on first launch.

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
