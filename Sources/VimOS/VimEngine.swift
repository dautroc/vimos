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
            
            case 37: // l
                accessibilityManager.moveCursor(.right)
                return true
            
            // Word Motions
            case 13: // w
                accessibilityManager.moveWordForward()
                return true
            case 11: // b
                 accessibilityManager.moveWordBackward()
                 return true
            
            case 14: // e
                accessibilityManager.moveToEndOfWord()
                return true
            
            // Advanced Motions
            case 29: // 0 (Zero) 
                 accessibilityManager.moveToLineStart()
                 return true
            
            case 21: // 4. Check for Shift ($)
                if flags.contains(.maskShift) {
                    accessibilityManager.moveToLineEnd()
                    return true
                }
                
            case 22: // 6. Check for Shift (^)
                if flags.contains(.maskShift) {
                    accessibilityManager.moveToLineStartNonWhitespace()
                    return true
                }
                
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
