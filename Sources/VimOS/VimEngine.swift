import Cocoa

enum VimMode {
    case normal
    case insert
}

class VimEngine: KeyboardHookDelegate {
    private var mode: VimMode = .insert
    private let accessibilityManager = AccessibilityManager()

    func handle(keyEvent: CGEvent) -> Bool {
        let flags = keyEvent.flags
        let keyCode = keyEvent.getIntegerValueField(.keyboardEventKeycode)
        
        // Toggle Mode: Caps Lock (example) or Ctrl-[ (Esc)
        // For simplicity using Escape (53) to enter Normal and 'i' (34) to enter Insert
        
        // Monitor for Mode Switch
        if keyCode == 53 { // ESC
            if mode == .insert {
                switchMode(to: .normal)
                return true // Swallow ESC
            }
        }

        if mode == .normal {
            // Handle Normal Mode Commands
            
            // 'i' to insert
            if keyCode == 34 {
                switchMode(to: .insert)
                return true
            }
            
            // Movements
            // h: 4, j: 38, k: 40, l: 37
            switch keyCode {
            case 4: // h
                accessibilityManager.moveCursor(.left)
                return true
            case 38: // j
                accessibilityManager.moveCursor(.down)
                return true
            case 40: // k
                accessibilityManager.moveCursor(.up)
                return true
            case 37: // l
                accessibilityManager.moveCursor(.right)
                return true
            
            // Advanced Motions
            case 29: // 0 (Zero) - Go to start of line (approximated as start of text for now or simulated Cmd+Left)
                 // Or better: use AX to set range to 0?
                 // Let's use AX text reading for '0' as a demo
                 if let text = accessibilityManager.getText() {
                     // For 0, we want line start. Since we don't have multiline parsing yet, let's do "Start of Line" via simulation or just Start of Text via AX.
                     // Simulating Cmd+Left is easier for "Start of Line".
                     // But to prove AX works, let's try to jump to start of text [0,0]
                     let range = CFRange(location: 0, length: 0)
                     accessibilityManager.setSelectedRange(range)
                 }
                 return true
                 
            case 22: // 6 (Shift+4 = $)
                 return true
                 
            case 1: // s
                 return true
                 
            // Passthrough for simulated arrow keys (so we don't block our own movements)
            case 123, 124, 125, 126:
                return false
                 
            default:
                // Swallow other keys in normal mode for now to prevent typing
               // Or maybe pass through modifiers?
                return true
            }
        }
        
        return false // Passthrough in Insert Mode
    }

    private func switchMode(to newMode: VimMode) {
        mode = newMode
        print("Switched to \(mode)")
        // Visual feedback could be added here (e.g. status bar icon)
    }
}
