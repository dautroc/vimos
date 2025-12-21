import Cocoa
import ApplicationServices

enum Direction {
    case left
    case right
    case up
    case down
}

class AccessibilityManager {
    
    private var isBlockCursor = false
    private var visualAnchorIndex: Int? // Anchor point for Visual Mode
    
    func setBlockCursor(_ enabled: Bool) {
        isBlockCursor = enabled
        // Refresh current cursor if possible
        if let currentRange = getSelectedRange() {
            setCursor(at: currentRange.location)
        }
    }
    
    // MARK: - Visual Mode
    
    func enterVisualMode() {
        if let currentRange = getSelectedRange() {
            visualAnchorIndex = currentRange.location
        }
    }
    
    func exitVisualMode() {
        // Collapse selection to cursor
        if let currentRange = getSelectedRange() {
            let activeIndex = getActualCursorIndex(from: currentRange)
            // Clear anchor first so setCursor behaves normally
            visualAnchorIndex = nil
            setCursor(at: activeIndex)
        } else {
            visualAnchorIndex = nil
        }
    }
    
    func prepareForInsertMode(collapseSelection: Bool = true) {
        // Atomic transition to Insert Mode.
        // We want to collapse the selection to the start (standard Vim 'i' behavior).
        // Simulating the Left Arrow is the most robust way to do this in macOS apps
        // as it reliably collapses any selection (Visual or Block) to its start index.
        
        visualAnchorIndex = nil
        isBlockCursor = false
        
        if collapseSelection {
            if let currentRange = getSelectedRange(), currentRange.length > 0 {
                 // Simulate Left Arrow to collapse to start
                 simulateKeyPress(keyCode: 123)
            }
        }
    }
    
    // Helper to set cursor respecting block mode and visual mode
    private func setCursor(at index: Int) {
        if let anchor = visualAnchorIndex {
            // Visual Mode: Select from anchor to index
            let start = min(anchor, index)
            let end = max(anchor, index)
            // Range length is difference + 1 to include the character under cursor (standard visual)
            // But AX ranges are typically [start, length).
            // If anchor=0, index=2. Text: "ABC". We want "ABC" selected? Or "AB"?
            // Vim visual: if I am at A, press v, move to C. Selection covers A,B,C.
            // Length = abs(anchor - index) + 1
            
            // However, we must be careful with bounds.
            var length = (end - start) + 1
            
            // Check text bounds to avoid overflow
             if let text = getText() {
                if start + length > text.count {
                     length = text.count - start
                }
             }
             
            setSelectedRange(CFRange(location: start, length: length))
            
        } else {
            // Normal/Insert Mode
            var length = 0
            if isBlockCursor {
                // Check bounds: don't select newline or OOB
                if let text = getText(), index < text.count {
                   length = 1
                }
            }
            setSelectedRange(CFRange(location: index, length: length))
        }
    }

    // MARK: - Core AX wrappers
    
    private func getFocusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        let result = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        if result == .success {
            return (focusedElement as! AXUIElement)
        }
        return nil
    }
    
    func getSelectedRange() -> CFRange? {
        guard let element = getFocusedElement() else { return nil }
        
        var rangeValue: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue)
        
        if result == .success, CFGetTypeID(rangeValue) == AXValueGetTypeID() {
            let axValue = rangeValue as! AXValue
            var range = CFRange()
            if AXValueGetValue(axValue, .cfRange, &range) {
                return range
            }
        }
        return nil
    }
    
    // MARK: - Word Operations
    
    // Helper to determine the "active" cursor end in Visual Mode
    private func getActualCursorIndex(from range: CFRange) -> Int {
        if let anchor = visualAnchorIndex {
            // If the selection starts at the anchor, the cursor is at the end.
            if range.location == anchor {
                // Forward selection: Cursor is on the last character of the selection.
                // Range [2, 1] means char at 2 is selected. Cursor is at 2.
                // Range [2, 0] means cursor at 2.
                return range.length > 0 ? range.location + range.length - 1 : range.location
            }
            // If the selection ends at (or near) the anchor, the cursor is at the start (range.location).
            // E.g. Anchor=10, Range(5, 5) -> Ends at 10. Cursor is 5.
            return range.location
        }
        return range.location
    }
    
    func moveWordForward() {
        if let text = getText(), let currentRange = getSelectedRange() {
            let currentIndex = getActualCursorIndex(from: currentRange)
            let newIndex = WordMotionLogic.getNextWordIndex(text: text, currentIndex: currentIndex)
            if newIndex != currentIndex {
                setCursor(at: newIndex)
                return
            }
        }
        
        // Fallback: Simulate Option+Right Arrow
        simulateKeyPress(keyCode: 124, flags: .maskAlternate)
    }
    
    func moveWordBackward() {
        if let text = getText(), let currentRange = getSelectedRange() {
             let currentIndex = getActualCursorIndex(from: currentRange)
             let newIndex = WordMotionLogic.getPrevWordIndex(text: text, currentIndex: currentIndex)
             if newIndex != currentIndex {
                 setCursor(at: newIndex)
                 return
             }
        }
        
        // Fallback: Simulate Option+Left Arrow
        simulateKeyPress(keyCode: 123, flags: .maskAlternate)
    }
    
    func moveToEndOfWord() {
        if let text = getText(), let currentRange = getSelectedRange() {
            let currentIndex = getActualCursorIndex(from: currentRange)
            let newIndex = WordMotionLogic.getEndOfWordIndex(text: text, currentIndex: currentIndex)
             if newIndex != currentIndex {
                 setCursor(at: newIndex)
                 return
             }
        }
        // No good fallback system key for 'e' unfortunately.
    }
    
    // MARK: - Line Operations
    
    func moveToLineStart() { // 0
        if let text = getText(), let currentRange = getSelectedRange() {
             let currentIndex = getActualCursorIndex(from: currentRange)
             let newIndex = WordMotionLogic.getLineStartIndex(text: text, currentIndex: currentIndex)
             if newIndex != currentIndex {
                 setCursor(at: newIndex)
                 return
             }
        }
        // Fallback: Cmd+Left
        simulateKeyPress(keyCode: 123, flags: .maskCommand)
    }
    
    func moveToLineEnd() { // $
        if let text = getText(), let currentRange = getSelectedRange() {
             let currentIndex = getActualCursorIndex(from: currentRange)
             // Use Visual Line End (Last character) instead of Newline index
             let newIndex = WordMotionLogic.getVisualLineEndIndex(text: text, currentIndex: currentIndex)
             if newIndex != currentIndex {
                 setCursor(at: newIndex)
                 return
             }
        }
        // Fallback: Cmd+Right
        simulateKeyPress(keyCode: 124, flags: .maskCommand)
    }
    
    /// Selects the content of the current line (excluding newline).
    /// Returns true if content was selected (length > 0), false if line is empty (length 0).
    func selectCurrentLineContent() -> Bool {
        guard let text = getText(), let currentRange = getSelectedRange() else { return false }
        let currentIndex = getActualCursorIndex(from: currentRange)
        
        let start = WordMotionLogic.getLineStartIndex(text: text, currentIndex: currentIndex)
        let end = WordMotionLogic.getLineEndIndex(text: text, currentIndex: currentIndex)
        
        // Select [start, end)
        let length = max(0, end - start)
        
        if length > 0 {
             setSelectedRange(CFRange(location: start, length: length))
             return true
        }
        return false
    }
    
    func moveToLineStartNonWhitespace() { // ^
        if let text = getText(), let currentRange = getSelectedRange() {
             let currentIndex = getActualCursorIndex(from: currentRange)
             let newIndex = WordMotionLogic.getLineFirstNonWhitespaceIndex(text: text, currentIndex: currentIndex)
             if newIndex != currentIndex {
                 setCursor(at: newIndex)
                 return
             }
        }
        // Fallback approximation: Cmd+Left
        simulateKeyPress(keyCode: 123, flags: .maskCommand)
    }
    
    // MARK: - Document Motions
    
    func moveToStartOfDocument() { // gg
        // Using AX for whole document is excessive/hard (getting full text range).
        // Standard macOS is Cmd+Up Arrow.
        simulateKeyPress(keyCode: 126, flags: .maskCommand)
    }
    
    func moveToEndOfDocument() { // G
        // Standard macOS is Cmd+Down Arrow.
        simulateKeyPress(keyCode: 125, flags: .maskCommand)
    }
    
    // MARK: - Edit Operations
    
    func deleteCurrentCharacter() { // x
        // Try AX Selection Delete first?
        // Actually, simulating Forward Delete (117) is usually safe if we are not at EOL.
        // But to be robust against "Char Before" issues (Backspace), we stick to 117.
        simulateKeyPress(keyCode: 117)
    }
    
    func undo() { // u
        // Cmd+Z
        simulateKeyPress(keyCode: 6, flags: .maskCommand)
    }
    
    func redo() { // Ctrl-r (Vim) -> Cmd+Shift+Z (macOS Standard)
        simulateKeyPress(keyCode: 6, flags: [.maskCommand, .maskShift])
    }
    
    func replaceCurrentCharacter(with charCode: CGKeyCode, flags: CGEventFlags) { // r + char
        // Attempt AX replacement first (Cleanest)
        // 1. Convert charCode to string? (Hard without mapping, so let's skip pure AX text injection for now unless we have the char)
        // Since we only have keycode, we depend on simulation for input.
        
        // Strategy:
        // 1. Select the character (Block Mode guarantees this if working).
        // 2. Simulate User Input (Let the OS handler replacement).
        //    If we handle the keypress simulation correctly, it enters text.
        //    If we have a selection, enterting text REPLACES the selection.
        
        // So:
        // 1. Selection is already [i, 1] (Block Cursor).
        // 2. Simulate Key Press (New Char).
        //    -> This replaces the selection with New Char.
        //    -> Cursor automatically moves to after New Char.
        // 3. Move Left (to stay on the char).
        
        // We do NOT need to delete explicitly if we have a selection!
        // But if Fallback (No Selection / AX Fail):
        // Caret is A|B.
        // We need to delete B, then insert.
        // So Forward Delete (117) is required.
        
        if let range = getSelectedRange(), range.length > 0 {
            // We have a selection (Block Cursor working).
            // Just typing replaces it.
            simulateKeyPress(keyCode: charCode, flags: flags)
        } else {
            // Fallback: No selection. We are A|B.
            // 1. Forward Delete (remove B).
            simulateKeyPress(keyCode: 117)
            // 2. Insert New Char.
            simulateKeyPress(keyCode: charCode, flags: flags)
        }
        
        // 3. Move cursor back left to stay on the new char
        moveCursor(.left)
    }
    
    // MARK: - Text Access
    
    func getText() -> String? {
        guard let element = getFocusedElement() else { return nil }
        
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        
        if result == .success, let stringValue = value as? String {
            return stringValue
        }
        return nil
    }
    
    func setText(_ text: String) {
         guard let element = getFocusedElement() else { return }
         AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as AnyObject)
    }

    func setSelectedRange(_ range: CFRange) {
        guard let element = getFocusedElement() else { return }
        
        var rangeV = range // Mutable copy for pointer
        guard let axValue = AXValueCreate(.cfRange, &rangeV) else { return }
        
        AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, axValue)
    }
    
    // MARK: - Movement simulation (Fallback)
    
    func moveCursor(_ direction: Direction) {
        // Try AX for Left/Right to preserve block cursor
        // AND ensure we calculate from the *active* cursor end in Visual Mode
        if direction == .left || direction == .right {
            if let text = getText(), let range = getSelectedRange() {
                 var newIndex = getActualCursorIndex(from: range)
                 if direction == .left {
                     newIndex = max(0, newIndex - 1)
                 } else { // Right
                      newIndex = min(text.count, newIndex + 1)
                 }
                 setCursor(at: newIndex)
                 return
            }
        }
        
        // Fallback: Simulate Arrow Keys
        let keyCode: CGKeyCode
        switch direction {
        case .left: keyCode = 123
        case .right: keyCode = 124
        case .up: keyCode = 126
        case .down: keyCode = 125
        }
        
        // In Visual Mode, we must simulate Shift + Arrow to extend selection for Up/Down
        // (Left/Right are handled above via AX usually, but if those fail (nil text), fallback handles them too)
        var flags: CGEventFlags = []
        if visualAnchorIndex != nil {
            flags.insert(.maskShift)
        }
        
        simulateKeyPress(keyCode: keyCode, flags: flags)
    }
    
    private func simulateKeyPress(keyCode: CGKeyCode, flags: CGEventFlags = []) {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            print("Failed to create event source")
            return
        }
        
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = flags
        keyDown?.setIntegerValueField(.eventSourceUserData, value: 0x555) // Magic number for VimOS simulation
        
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = flags
        keyUp?.setIntegerValueField(.eventSourceUserData, value: 0x555)
        
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
