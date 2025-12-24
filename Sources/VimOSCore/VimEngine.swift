import Cocoa

public enum VimMode: Sendable {
    case normal
    case insert
    case visual
}

public enum VimOperator: Sendable {
    case change
}



public class VimEngine: KeyboardHookDelegate {
    private var mode: VimMode = .insert
    private let accessibilityManager: AccessibilityManagerProtocol
    private var lastMode: VimMode = .insert // To track previous mode efficiently
    private var lastKeyCode: Int? // Simple buffer for 'gg'
    private var isWaitingForReplaceChar = false // For 'r' generic command
    
    // Operator Pending State
    private var pendingOperator: VimOperator? = nil
    private var isWaitingForTillChar = false // State for 't' command
    private var isWaitingForTextObject = false // State for 'i' (inner) modifier
    
    private let keyMappingWorker = KeyMappingWorker()
    
    public init(accessibilityManager: AccessibilityManagerProtocol = AccessibilityManager()) {
        self.accessibilityManager = accessibilityManager
    }

    public func handle(keyEvent: CGEvent) -> Bool {
        // ALWAYS pass through modifier key changes (flagsChanged)
        // This ensures Left/Right Shift, Ctrl, Alt, Cmd state is preserved
        if keyEvent.type == .flagsChanged {
            return false
        }
        
        if keyEvent.getIntegerValueField(.eventSourceUserData) == 0x555 {
            return false
        }
        
        // Key Mapping (Skip if internal recursion flag 0x999 is set)
        if keyEvent.getIntegerValueField(.eventSourceUserData) != 0x999 {
            let (handled, mappedEvents) = keyMappingWorker.process(keyEvent, mode: mode)
            if handled {
                if let events = mappedEvents {
                    for event in events {
                        // Mark to skip mapping for recursive call
                        event.setIntegerValueField(.eventSourceUserData, value: 0x999)
                        if !self.handle(keyEvent: event) {
                            // If logic didn't consume it (e.g. valid key in insert mode), post to system
                            // Mark as simulated (0x555) so Tap -> VimEngine ignores it
                            event.setIntegerValueField(.eventSourceUserData, value: 0x555)
                            event.post(tap: .cghidEventTap)
                        }
                    }
                }
                return true // Swallow original
            }
        }

        let flags = keyEvent.flags
        let keyCode = keyEvent.getIntegerValueField(.keyboardEventKeycode)
        
        // 1. Check for Vim-specific Modifier Commands (Exceptions to Passthrough)
        
        // Ctrl+r (Redo)
        if flags.contains(.maskControl) && keyCode == 15 {
             accessibilityManager.redo()
             return true
        }
        
        // 2. Pass through System Shortcuts (Cmd, Option, Control)
        // If it's a modifier combo we didn't handle above, let the system have it.
        // We check if any of the major modifiers are present. 
        // Note: Shift is not sufficient on its own (Shift+A is valid input), but Cmd+Shift+Space should pass.
        if flags.contains(.maskCommand) || flags.contains(.maskAlternate) || flags.contains(.maskControl) {
            return false
        }
        
        // Mode Switching Logic
        if keyCode == 53 { // ESC
            if isWaitingForReplaceChar || isWaitingForTillChar || isWaitingForTextObject {
                isWaitingForReplaceChar = false
                isWaitingForTillChar = false
                isWaitingForTextObject = false
                return true
            }
            if pendingOperator != nil {
                pendingOperator = nil
                accessibilityManager.exitVisualMode(collapseSelection: true)
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
            
            // Handle 't' Waiting State
            if isWaitingForTillChar {
                if let event = NSEvent(cgEvent: keyEvent), let char = event.characters, !char.isEmpty {
                     executeMotion { self.accessibilityManager.moveToNextOccurrence(of: char, stopBefore: true) }
                }
                isWaitingForTillChar = false
                return true
            }
            
            // Handle Inner Object Waiting State
            if isWaitingForTextObject {
                if let event = NSEvent(cgEvent: keyEvent), let char = event.characters, !char.isEmpty {
                    executeMotion { self.accessibilityManager.selectInnerObject(char: char) }
                }
                isWaitingForTextObject = false
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
                if flags.contains(.maskShift) {
                    // 'C' - Change to end of line (c$)
                    pendingOperator = .change
                    executeMotion { self.accessibilityManager.moveToLineEnd() }
                    return true
                }
                
                if pendingOperator == .change {
                    // 'cc' (Change Line)
                    if accessibilityManager.selectCurrentLineContent(includeNewline: false) {
                        accessibilityManager.deleteCurrentCharacter()
                    }
                    switchMode(to: .insert, collapseSelection: false)
                    pendingOperator = nil
                    return true
                }
                pendingOperator = .change
                return true
            }
            
            // 'i' to insert or Inner Object Modifier
            if (mode == .normal || mode == .visual) && keyCode == 34 {
                if pendingOperator != nil {
                    // ci... -> i means "inner"
                    isWaitingForTextObject = true
                    return true
                }
                switchMode(to: .insert)
                return true
            }
            
            // 'v' to toggle Visual / Visual Line
            if keyCode == 9 { // v
                 if flags.contains(.maskShift) { // V (Visual Line)
                     // If we are already in visual, we just switch behavior (AccessibilityManager handles re-entrance check/update)
                     if mode != .visual {
                         switchMode(to: .visual) 
                     }
                     // Call enterVisualLineMode AFTER switching to visual, 
                     // because switchMode calls enterVisualMode which might reset selection logic.
                     accessibilityManager.enterVisualLineMode()
                 } else { // v (Visual Character)
                     if mode == .visual {
                         switchMode(to: .normal)
                     } else {
                         switchMode(to: .visual)
                     }
                 }
                return true
            }
            
            // Double-key commands (g, y)
            if keyCode == 5 { // g
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
            } else if keyCode == 16 { // y
                if mode == .visual {
                    accessibilityManager.yank()
                    switchMode(to: .normal)
                    return true
                }
                if mode == .normal {
                    if flags.contains(.maskShift) { // Y
                        accessibilityManager.yankRestOfLine()
                        switchMode(to: .normal)
                        lastKeyCode = nil
                        return true
                    }
                    if lastKeyCode == 16 { // yy
                        accessibilityManager.yankCurrentLine(includeNewline: true)
                        switchMode(to: .normal)
                        lastKeyCode = nil
                        return true
                    }
                    lastKeyCode = 16
                    return true
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
            
            // 7. Insert Motions (a, A, o, O)
            
            case 0: // a
                if mode == .normal {
                    if flags.contains(.maskShift) { // A
                        accessibilityManager.moveToLineRealEnd()
                        switchMode(to: .insert, collapseSelection: false)
                    } else { // a
                        accessibilityManager.moveCursor(.right)
                        switchMode(to: .insert)
                    }
                    return true
                }
                
            case 31: // o
                if mode == .normal {
                    if flags.contains(.maskShift) { // O
                        accessibilityManager.openNewLineAbove()
                        switchMode(to: .insert, collapseSelection: false)
                    } else { // o
                        accessibilityManager.openNewLineBelow()
                        switchMode(to: .insert, collapseSelection: false)
                    }
                    return true
                }
            
            // Edit Commands
            case 7: // x
                if mode == .visual {
                     if accessibilityManager.isVisualLineMode {
                         accessibilityManager.deleteVisualLine()
                     } else {
                         accessibilityManager.deleteCurrentCharacter()
                     }
                     // Delay switchMode to allow delete event to process
                     DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                         self.switchMode(to: .normal, collapseSelection: false, updateCursorImmediate: false)
                     }
                } else {
                    accessibilityManager.deleteCurrentCharacter()
                }
                return true
                
            case 32: // u (Undo)
                if mode == .normal {
                    accessibilityManager.undo()
                    return true
                }
                
            // Ctrl+r handled at top level
            case 15: // r (Replace)
                if mode == .normal {
                    isWaitingForReplaceChar = true
                    return true
                }
                        case 17: // t (Till motion)
                isWaitingForTillChar = true
                return true
            
            case 35: // p
                if mode == .visual {
                    accessibilityManager.pasteInVisual()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                        self.switchMode(to: .normal, collapseSelection: false, updateCursorImmediate: false)
                    }
                    return true
                }
                
                if mode == .normal {
                    if flags.contains(.maskShift) { // P
                        accessibilityManager.paste(after: false)
                    } else { // p
                        accessibilityManager.paste(after: true)
                    }
                    return true
                }
                
            case 2: // d (Delete)
                 if mode == .visual {
                     if accessibilityManager.isVisualLineMode {
                         accessibilityManager.deleteVisualLine()
                     } else {
                         accessibilityManager.deleteCurrentCharacter()
                     }
                     // Delay switchMode to allow delete event to process
                     DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                         self.switchMode(to: .normal, collapseSelection: false, updateCursorImmediate: false)
                     }
                     return true
                 }
                 return true
                
            case 123, 124, 125, 126, 51, 117:
                return false
                 
            default:
                return true
            }
        }
        
        return false  
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
            // No indicator update needed as switching mode handles it or we return to normal.
        } else {
            motion()
            // No indicator update needed (static position).
        }
    }

    private func switchMode(to newMode: VimMode, collapseSelection: Bool = true, updateCursorImmediate: Bool = true) {
        // Clear any pending operator when switching modes to avoid state leaks
        pendingOperator = nil
        
        let previousMode = mode
        mode = newMode
        print("Switched to \(mode)")
        
        if mode == .normal {
            // Vim Behavior: When entering Normal mode, cursor moves one step left.
            // But only if we were in insert?
            if previousMode == .insert {
                 accessibilityManager.moveCursor(.left)
            }
             accessibilityManager.exitVisualMode(collapseSelection: collapseSelection)
             accessibilityManager.setBlockCursor(true, updateImmediate: updateCursorImmediate)
             
        } else if mode == .visual {
            accessibilityManager.enterVisualMode()
            accessibilityManager.setBlockCursor(true, updateImmediate: true)
            
        } else {
            // Switching to Insert Mode
            accessibilityManager.prepareForInsertMode(collapseSelection: collapseSelection)
        }
        

    }
    

}
