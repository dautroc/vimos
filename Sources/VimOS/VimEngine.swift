import Cocoa

enum VimMode {
    case normal
    case insert
    case visual
}

enum VimOperator {
    case change
}

class VimEngine: KeyboardHookDelegate {
    private var mode: VimMode = .insert
    private let accessibilityManager = AccessibilityManager()
    private var lastKeyCode: Int? // Simple buffer for 'gg'
    private var isWaitingForReplaceChar = false // For 'r' generic command
    
    // Operator Pending State
    private var pendingOperator: VimOperator? = nil

    func handle(keyEvent: CGEvent) -> Bool {
        let flags = keyEvent.flags
        let keyCode = keyEvent.getIntegerValueField(.keyboardEventKeycode)
        
        // print("DEBUG: Key: \(keyCode), Mode: \(mode)")
        
        // Mode Switching Logic
        if keyCode == 53 { // ESC
            if isWaitingForReplaceChar {
                isWaitingForReplaceChar = false
                return true
            }
            if pendingOperator != nil {
                pendingOperator = nil
                accessibilityManager.exitVisualMode()
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
            lastKeyCode = nil // Clear buffers
        }

        if mode == .normal || mode == .visual {
            // Handle 'r' Waiting State
            if mode == .normal && isWaitingForReplaceChar {
                accessibilityManager.replaceCurrentCharacter(with: CGKeyCode(keyCode), flags: flags)
                isWaitingForReplaceChar = false
                return true
            }
            
            // Visual Mode 'c' (Change Selection)
            if mode == .visual && keyCode == 8 { // c
                accessibilityManager.deleteCurrentCharacter()
                // Do not collapse selection as it is deleted
                switchMode(to: .insert, collapseSelection: false)
                return true
            }
            
            // Normal Mode 'c' (Change Operator)
            if mode == .normal && keyCode == 8 { // c
                if pendingOperator == .change {
                    // 'cc' (Change Line)
                    // Select content of line (excluding newline). 
                    // If content exists, delete it. If empty line, just enter insert.
                    if accessibilityManager.selectCurrentLineContent() {
                        accessibilityManager.deleteCurrentCharacter()
                    }
                    switchMode(to: .insert, collapseSelection: false)
                    pendingOperator = nil
                    return true
                }
                pendingOperator = .change
                return true
            }
            
            // 'i' to insert
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
                     executeMotion { self.accessibilityManager.moveToEndOfDocument() }
                     lastKeyCode = nil
                     return true
                } else { // 'g'
                    if lastKeyCode == 5 { // 'gg'
                        executeMotion { self.accessibilityManager.moveToStartOfDocument() }
                        lastKeyCode = nil
                        return true
                    } else {
                        lastKeyCode = 5 // Buffer it
                        return true // Swallow first 'g'
                    }
                }
            } else {
                lastKeyCode = nil
            }

            // Motions
            switch keyCode {
            case 4: // h
                executeMotion { self.accessibilityManager.moveCursor(.left) }
                return true
            case 38: // j
                executeMotion { self.accessibilityManager.moveCursor(.down) }
                return true
            case 40: // k
                executeMotion { self.accessibilityManager.moveCursor(.up) }
                return true
            case 37: // l
                executeMotion { self.accessibilityManager.moveCursor(.right) }
                return true
            
            // Word Motions
            case 13: // w
                executeMotion { self.accessibilityManager.moveWordForward() }
                return true
            case 11: // b
                executeMotion { self.accessibilityManager.moveWordBackward() }
                return true
            case 14: // e
                executeMotion { self.accessibilityManager.moveToEndOfWord() }
                return true
            
            // Advanced Motions
            case 29: // 0 (Zero) 
                 executeMotion { self.accessibilityManager.moveToLineStart() }
                 return true
            
            case 21: // 4. Check for Shift ($)
                if flags.contains(.maskShift) {
                    executeMotion { self.accessibilityManager.moveToLineEnd() }
                    return true
                }
                
            case 22: // 6. Check for Shift (^)
                if flags.contains(.maskShift) {
                    executeMotion { self.accessibilityManager.moveToLineStartNonWhitespace() }
                    return true
                }
            
            // Edit Commands
            case 7: // x
                if mode == .visual {
                     accessibilityManager.deleteCurrentCharacter()
                     switchMode(to: .normal)
                } else {
                    accessibilityManager.deleteCurrentCharacter()
                }
                return true
                
            case 32: // u (Undo)
                if mode == .normal {
                    accessibilityManager.undo()
                    return true
                }
                
            case 15: // r (Replace) or Ctrl-r (Redo)
                if flags.contains(.maskControl) {
                    // Ctrl-r Redo
                    accessibilityManager.redo()
                    return true
                }
                if mode == .normal {
                    isWaitingForReplaceChar = true
                    return true
                }
                return true
                
            case 2: // d (Delete)
                 if mode == .visual {
                     accessibilityManager.deleteCurrentCharacter()
                     switchMode(to: .normal)
                     return true
                 }
                 return true
                
            case 123, 124, 125, 126, 51, 117:
                return false
                 
            default:
                return true
            }
        }
        
        return false // Passthrough in Insert Mode
    }
    
    private func executeMotion(_ motion: () -> Void) {
        if let op = pendingOperator {
            // Operator Pending Mode
            // 1. Enter pseudo-visual mode logic to capture range
            accessibilityManager.enterVisualMode()
            
            // 2. Perform Motion (extending selection)
            motion()
            
            // 3. Execute Operator
            if op == .change {
                accessibilityManager.deleteCurrentCharacter()
                switchMode(to: .insert, collapseSelection: false)
            }
            
            pendingOperator = nil
        } else {
            motion()
        }
    }

    private func switchMode(to newMode: VimMode, collapseSelection: Bool = true) {
        // Clear any pending operator when switching modes to avoid state leaks
        pendingOperator = nil
        
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
            accessibilityManager.setBlockCursor(true)
            
        } else {
            // Switching to Insert Mode
            accessibilityManager.prepareForInsertMode(collapseSelection: collapseSelection)
        }
    }
}
