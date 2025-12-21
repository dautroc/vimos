import Cocoa

enum VimMode {
    case normal
    case insert
    case visual
}

class VimEngine: KeyboardHookDelegate {
    private var mode: VimMode = .insert
    private let accessibilityManager = AccessibilityManager()
    private var lastKeyCode: Int? // Simple buffer for 'gg'
    private var isWaitingForReplaceChar = false // For 'r' generic command

    func handle(keyEvent: CGEvent) -> Bool {
        let flags = keyEvent.flags
        let keyCode = keyEvent.getIntegerValueField(.keyboardEventKeycode)
        
        // print("DEBUG: Key: \(keyCode), Mode: \(mode)")
        
        // ... (Mode switching logic remains)
        
        // Toggle Mode: Caps Lock (example) or Ctrl-[ (Esc)
        // For simplicity using Escape (53) to enter Normal and 'i' (34) to enter Insert
        
        // Monitor for Mode Switch
        if keyCode == 53 { // ESC
            if isWaitingForReplaceChar {
                isWaitingForReplaceChar = false // Cancel 'r'
                return true
            }
            if mode == .insert {
                switchMode(to: .normal)
                return true // Swallow ESC
            }
            if mode == .visual {
                switchMode(to: .normal)
                return true
            }
        }

        if mode == .normal || mode == .visual {
            // Handle 'r' Waiting State (Normal/Visual?) - usually Normal only
            if mode == .normal && isWaitingForReplaceChar {
                // Perform replacement with the pressed key
                // Convert event to character if possible, or just pass keycode/flags
                accessibilityManager.replaceCurrentCharacter(with: CGKeyCode(keyCode), flags: flags)
                isWaitingForReplaceChar = false
                return true // Swallow the character typed (since we re-injected it via simulation)
            }
            
            // Handle Normal Mode Commands
            
            // 'i' to insert (Normal or Visual)
            // In Visual mode, this mimics 'c' (change selection) effectively if the user types next.
            if (mode == .normal || mode == .visual) && keyCode == 34 {
                switchMode(to: .insert)
                return true
            }
            
            // 'v' to toggle Visual Mode
            if keyCode == 9 {
                if mode == .visual {
                    switchMode(to: .normal)
                } else {
                    switchMode(to: .visual)
                }
                return true
            }
            
            // Special handling for 'g' (5)
            if keyCode == 5 {
                if flags.contains(.maskShift) { // 'G'
                     accessibilityManager.moveToEndOfDocument()
                     lastKeyCode = nil
                     return true
                } else { // 'g'
                    if lastKeyCode == 5 { // 'gg'
                        accessibilityManager.moveToStartOfDocument()
                        lastKeyCode = nil
                        return true
                    } else {
                        lastKeyCode = 5 // Buffer it
                        return true // Swallow first 'g'
                    }
                }
            } else {
                // If we had a buffered 'g' and pressed something else,
                // technically we should execute the partial command or ignore.
                // Vim behaviors vary (e.g. 'gh' might mean something).
                // For now, clear buffer.
                lastKeyCode = nil
            }

            // Movements
            switch keyCode {
            // ... (h, j, k, l, w, b, etc remain)

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
            
            // Edit Commands
            case 7: // x (Cut/Delete char or selection)
                if mode == .visual {
                    // In visual mode, x deletes the selection
                     accessibilityManager.deleteCurrentCharacter() // This actually sends delete key, which works for selection too
                     switchMode(to: .normal)
                } else {
                    accessibilityManager.deleteCurrentCharacter()
                }
                return true
                
            case 15: // r (Replace)
                if mode == .normal {
                    isWaitingForReplaceChar = true
                    return true
                }
                return true // Ignore in visual for now
                
            case 2: // d (Delete)
                 if mode == .visual {
                     accessibilityManager.deleteCurrentCharacter() // Delete selection
                     switchMode(to: .normal)
                     return true
                 }
                 // Normal mode 'd' usually waits for motion. Not implemented yet fully?
                 // For now, ignore or implement 'dd'?
                 return true
                
            // Passthrough for simulated arrow keys and deletes (so we don't block our own actions)
            case 123, 124, 125, 126, 51, 117:
                return false
                 
            default:
                // Swallow other keys in normal/visual mode for now to prevent typing
               // Or maybe pass through modifiers?
                return true
            }
        }
        
        return false // Passthrough in Insert Mode
    }

    private func switchMode(to newMode: VimMode) {
        let previousMode = mode
        mode = newMode
        print("Switched to \(mode)")
        
        if mode == .normal {
            // Vim Behavior: When entering Normal mode, cursor moves one step left.
            // Only if coming from Insert
            if previousMode == .insert {
                 accessibilityManager.moveCursor(.left)
            }
             accessibilityManager.exitVisualMode()
             accessibilityManager.setBlockCursor(true)
             
        } else if mode == .visual {
            accessibilityManager.enterVisualMode()
            accessibilityManager.setBlockCursor(true) // Visual mode also uses block-like selection usually
            
        } else {
            // Switching to Insert Mode
            accessibilityManager.prepareForInsertMode()
        }
    }
}
