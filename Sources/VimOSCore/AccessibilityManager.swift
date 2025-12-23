import Cocoa
import ApplicationServices

public enum Direction: Sendable {
    case left
    case right
    case up
    case down
}


public protocol AccessibilityManagerProtocol: AnyObject {
    var isVisualLineMode: Bool { get }
    
    func setBlockCursor(_ enabled: Bool, updateImmediate: Bool)
    func enterVisualMode()
    func exitVisualMode(collapseSelection: Bool)
    func prepareForInsertMode(collapseSelection: Bool)
    
    func moveWordForward()
    func moveWordBackward()
    func moveToEndOfWord()
    func moveToLineStart()
    func moveToLineEnd()
    func selectCurrentLineContent(includeNewline: Bool) -> Bool
    func moveToLineStartNonWhitespace()
    
    func moveToStartOfDocument()
    func moveToEndOfDocument()
    
    func moveToNextOccurrence(of char: String, stopBefore: Bool)
    func selectInnerObject(char: String)
    
    func enterVisualLineMode()
    
    func moveToLineRealEnd()
    func openNewLineBelow()
    func openNewLineAbove()
    
    func deleteVisualLine()
    func deleteCurrentCharacter()

    func yank()
    func yankCurrentLine(includeNewline: Bool)
    func yankRestOfLine()
    func undo()
    func redo()
    func replaceCurrentCharacter(with charCode: CGKeyCode, flags: CGEventFlags)
    
    func paste(after: Bool)
    func pasteInVisual()
    
    func moveCursor(_ direction: Direction)
}

public class AccessibilityManager: AccessibilityManagerProtocol {

    
    private var isBlockCursor = false
    private var visualAnchorIndex: Int? // Anchor point for Visual Mode
    public private(set) var isVisualLineMode = false // For 'V' mode

    public init() {}
    
    public func setBlockCursor(_ enabled: Bool, updateImmediate: Bool = true) {
        isBlockCursor = enabled
        
        if !updateImmediate { return }
        
        // Refresh current cursor if possible
        if let currentRange = getSelectedRange() {
            setCursor(at: currentRange.location)
        }
    }
    
    // MARK: - Visual Mode
    
    public func enterVisualMode() {
        if let currentRange = getSelectedRange() {
            visualAnchorIndex = currentRange.location
        }
    }
    
    public func exitVisualMode(collapseSelection: Bool = true) {
        // Collapse selection to cursor
        if collapseSelection {
            if let currentRange = getSelectedRange() {
                let activeIndex = getActualCursorIndex(from: currentRange)
                // Clear anchor first so setCursor behaves normally
                visualAnchorIndex = nil
                isVisualLineMode = false
                setCursor(at: activeIndex)
                return
            }
        }
        
        // Just clear state
        visualAnchorIndex = nil
        isVisualLineMode = false
    }
    
    public func prepareForInsertMode(collapseSelection: Bool = true) {
        // Atomic transition to Insert Mode.
        // We want to collapse the selection to the start (standard Vim 'i' behavior).
        // Simulating the Left Arrow is the most robust way to do this in macOS apps
        // as it reliably collapses any selection (Visual or Block) to its start index.
        
        visualAnchorIndex = nil
        isVisualLineMode = false
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
            if isVisualLineMode {
                // Visual Line Mode: Select full lines from anchor to index
                guard let text = getText() else { return }
                
                // Determine range of lines
                let idx1 = min(anchor, index)
                let idx2 = max(anchor, index)
                
                // Start is LineStart of idx1
                let start = WordMotionLogic.getLineStartIndex(text: text, currentIndex: idx1)
                
                // End is LineEnd of idx2
                let end = WordMotionLogic.getLineEndIndex(text: text, currentIndex: idx2)
                
                // Selection logic (matches previous verify): Exclude trailing newline for display but handle empty lines
                // If the line is empty (start == end), we select the newline character itself so it's visible.
                var length = end - start
                
                 if length == 0 && start < text.count {
                     length = 1
                 }
                
                setSelectedRange(CFRange(location: start, length: length))
                
            } else {
                // Visual Character Mode: Select from anchor to index
                let start = min(anchor, index)
                let end = max(anchor, index)
                
                var length = (end - start) + 1
                
                if let text = getText() {
                   if start + length > text.count {
                        length = text.count - start
                   }
                }
                
               setSelectedRange(CFRange(location: start, length: length))
            }
            
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
            // Verify it holds a CFRange to avoid warnings/errors
            if AXValueGetType(axValue) == .cfRange {
                var range = CFRange()
                if AXValueGetValue(axValue, .cfRange, &range) {
                    return range
                }
            }
        }
        return nil
    }
    
    func getCursorBounds() -> CGRect? {
        guard let element = getFocusedElement() else { return nil }
        guard let range = getSelectedRange() else { return nil }
        
        // Get the character under cursor (Block Cursor style)
        let cursorIndex = getActualCursorIndex(from: range)
        
        // Handle end of document/line case delicately
        // If we really want the "insertion point" bounds, requesting length 0 might work on some apps,
        // but for Block Cursor visualization we usually want the character bounds.
        // We'll try to get bounds of the character at `cursorIndex`.
        
        let length = 1
        if let text = getText() {
            if cursorIndex >= text.count {
                // We are at the very end. 
                // Fallback: Get bounds of the *previous* character and shift right? 
                // Or just the previous character.
                if text.count > 0 {
                    let prevIndex = text.count - 1
                    let prevRange = CFRange(location: prevIndex, length: 1)
                     if let rect = getBoundsFor(range: prevRange, element: element) {
                         // Shift it to the right approximately (width of char)
                         // This is a heuristic.
                         return CGRect(x: rect.origin.x + rect.width, y: rect.origin.y, width: rect.width, height: rect.height)
                     }
                }
                return nil
            }
        }
        
        let targetRange = CFRange(location: cursorIndex, length: length)
        return getBoundsFor(range: targetRange, element: element)
    }
    
    private func getBoundsFor(range: CFRange, element: AXUIElement) -> CGRect? {
        var rangeV = range
        guard let axRange = AXValueCreate(.cfRange, &rangeV) else { return nil }
        
        var boundsValue: AnyObject?
        let result = AXUIElementCopyParameterizedAttributeValue(element, "AXBoundsForRange" as CFString, axRange, &boundsValue)
        
        if result == .success, CFGetTypeID(boundsValue) == AXValueGetTypeID() {
             let axBounds = boundsValue as! AXValue
             if AXValueGetType(axBounds) == .cgRect {
                 var rect = CGRect.zero
                 if AXValueGetValue(axBounds, .cgRect, &rect) {
                     return rect
                 }
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
    
    public func moveWordForward() {
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
    
    public func moveWordBackward() {
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
    
    public func moveToEndOfWord() {
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
    
    public func moveToLineStart() { // 0
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
    
    public func moveToLineEnd() { // $
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
    
    /// Selects the content of the current line.
    /// - Parameter includeNewline: If true, includes the trailing newline character in the selection.
    /// Returns true if selection was attempted.
    public func selectCurrentLineContent(includeNewline: Bool = false) -> Bool {
        guard let text = getText(), let currentRange = getSelectedRange() else { return false }
        let currentIndex = getActualCursorIndex(from: currentRange)
        
        let start = WordMotionLogic.getLineStartIndex(text: text, currentIndex: currentIndex)
        var end = WordMotionLogic.getLineEndIndex(text: text, currentIndex: currentIndex)
        
        if includeNewline {
            let us = Array(text.utf16)
            if end < us.count {
                end += 1 // Include the newline character itself
            }
        }
        
        let length = max(0, end - start)
        
        // Always set the range even if length 0, to ensure we are yanking the correct line
        setSelectedRange(CFRange(location: start, length: length))
        return true
    }
    
    public func moveToLineStartNonWhitespace() { // ^
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
    
    public func moveToStartOfDocument() { // gg
        // Using AX for whole document is excessive/hard (getting full text range).
        // Standard macOS is Cmd+Up Arrow.
        simulateKeyPress(keyCode: 126, flags: .maskCommand)
    }
    
    public func moveToEndOfDocument() { // G
        // Standard macOS is Cmd+Down Arrow.
        simulateKeyPress(keyCode: 125, flags: .maskCommand)
    }
    
    // MARK: - Character Search Motions
    
    public func moveToNextOccurrence(of char: String, stopBefore: Bool) {
        if let text = getText(), let currentRange = getSelectedRange() {
            let currentIndex = getActualCursorIndex(from: currentRange)
            let newIndex = WordMotionLogic.getNextOccurrenceIndex(text: text, currentIndex: currentIndex, targetChar: char, stopBefore: stopBefore)
            
            if newIndex != currentIndex {
                setCursor(at: newIndex)
            }
        }
    }
    
    public func selectInnerObject(char: String) {
        if let text = getText(), let currentRange = getSelectedRange() {
            let currentIndex = getActualCursorIndex(from: currentRange)
            
            if let (start, end) = WordMotionLogic.getInnerObjectRange(text: text, currentIndex: currentIndex, targetChar: char) {
                // Determine length. Inclusive indices: start=1, end=3 -> length 3 (1,2,3)
                // Range(location: start, length: end - start + 1)
                let length = (end - start) + 1
                if length >= 0 {
                    setSelectedRange(CFRange(location: start, length: length))
                }
            }
        }
    }
    
    // MARK: - Visual Line Mode
    
    public func enterVisualLineMode() {
        guard let text = getText(), let currentRange = getSelectedRange() else { return }
        let currentIndex = getActualCursorIndex(from: currentRange)
        
        let start = WordMotionLogic.getLineStartIndex(text: text, currentIndex: currentIndex)
        let end = WordMotionLogic.getLineEndIndex(text: text, currentIndex: currentIndex) // Index of newline or count
        
        // Select full line CONTENT (excluding newline) to match user expectation of cursor position.
        // [start, end) where end is newline index.
        
        let length = end - start
        
        visualAnchorIndex = start
        isVisualLineMode = true
        isBlockCursor = true
        
        setSelectedRange(CFRange(location: start, length: length))
    }
    

    // MARK: - New Motions (A, o, O)
    
    public func moveToLineRealEnd() {
        // Disable block cursor for 'A' and 'o' to ensure we have a caret at the end, not a selection of the last char/newline
        isBlockCursor = false
        
        if let text = getText(), let currentRange = getSelectedRange() {
             let currentIndex = getActualCursorIndex(from: currentRange)
             let newIndex = WordMotionLogic.getLineEndIndex(text: text, currentIndex: currentIndex)
             // Move to newline (or end). This effectively is after the last character.
             // Force setCursor even if index is same, to ensure block cursor is cleared if needed?
             // But setCursor will use isBlockCursor=false.
             setCursor(at: newIndex)
        }
    }
    
    public func openNewLineBelow() {
        // 'o'
        isBlockCursor = false
        // Move to end of line
        moveToLineRealEnd()
        // Simulate Return with Shift to avoid submitting forms (Soft Return)
        simulateKeyPress(keyCode: 36, flags: .maskShift)
    }
    
    public func openNewLineAbove() {
        // 'O'
        isBlockCursor = false
        // Move to start of line
        moveToLineStart()
        // Simulate Return with Shift (Soft Return)
        simulateKeyPress(keyCode: 36, flags: .maskShift)
        // Move Left to get to the newly created empty line above
        // Return at start of line: Pushes content down. Cursor at Start of Content.
        // Left goes to the empty line created before it.
        moveCursor(.left)
    }
    
    // MARK: - Edit Operations
    
    public func deleteVisualLine() {
        // For 'd' in Visual Line mode: We want to delete the whole line INCLUDING newline.
        // The current selection (visual) excludes newline for display purposes.
        // We must extend it.
        
        guard let text = getText(), let currentRange = getSelectedRange() else {
             simulateKeyPress(keyCode: 117)
             return
        }
        
        // Check if we need to expand
        // If selection ends at the newline index, we should include +1
        // Actually, we can just calculate from range.
        
        let end = currentRange.location + currentRange.length
        
        // If end < text.count, it means there is more text (likely a newline at 'end')
        if end < text.count {
            // Extend selection by 1 to swallow the newline
            setSelectedRange(CFRange(location: currentRange.location, length: currentRange.length + 1))
        }
        
        simulateKeyPress(keyCode: 117)
    }
    
    public func deleteCurrentCharacter() { // x
        // Try AX Selection Delete first?
        // Actually, simulating Forward Delete (117) is usually safe if we are not at EOL.
        // But to be robust against "Char Before" issues (Backspace), we stick to 117.
        simulateKeyPress(keyCode: 117)
    }
    
    public func yank() {
        // Yank the current selection to the system clipboard
        guard let element = getFocusedElement() else { return }
        
        var textToYank: String?
        
        // Method 1: AXSelectedTextAttribute (Best if app supports it)
        var selectedTextValue: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedTextValue)
        
        if result == .success, let text = selectedTextValue as? String {
            textToYank = text
        } else {
            // Method 2: Fallback to getting text from full value via selected range
            // Useful for apps that don't correctly report kAXSelectedTextAttribute but do report Range
            if let range = getSelectedRange(), let fullText = getText() {
                let us = Array(fullText.utf16)
                if range.location >= 0 && range.location + range.length <= us.count {
                    let sub = us[range.location..<(range.location + range.length)]
                    textToYank = String(utf16CodeUnits: Array(sub), count: sub.count)
                }
            }
        }
        
        if let text = textToYank {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        } else {
            // Method 3: Final fallback: Simulate Cmd+C
            simulateKeyPress(keyCode: 8, flags: .maskCommand) // Cmd+C
        }
    }
    
    public func yankCurrentLine(includeNewline: Bool) {
        guard let text = getText(), let currentRange = getSelectedRange() else { return }
        let currentIndex = getActualCursorIndex(from: currentRange)
        
        let start = WordMotionLogic.getLineStartIndex(text: text, currentIndex: currentIndex)
        var end = WordMotionLogic.getLineEndIndex(text: text, currentIndex: currentIndex)
        
        if includeNewline {
            let us = Array(text.utf16)
            if end < us.count {
                end += 1 // Include newline
            }
        }
        
        let length = max(0, end - start)
        
        if length > 0 {
            let us = Array(text.utf16)
            if start + length <= us.count {
                let sub = us[start..<(start + length)]
                let textToYank = String(utf16CodeUnits: Array(sub), count: sub.count)
                
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(textToYank, forType: .string)
                // Do NOT print debug info
            }
        }
        // If length is 0 (empty line and no newline), we yank nothing or a newline? Standard yy on completely empty buffer does nothing maybe?
        // But usually there's a newline.
    }
    
    public func yankRestOfLine() {
         guard let text = getText(), let currentRange = getSelectedRange() else { return }
         let currentIndex = getActualCursorIndex(from: currentRange)
         
         let start = currentIndex
         let end = WordMotionLogic.getLineEndIndex(text: text, currentIndex: currentIndex)
         
         let length = max(0, end - start)
         
         if length > 0 {
             let us = Array(text.utf16)
             if start + length <= us.count {
                 let sub = us[start..<(start + length)]
                 let textToYank = String(utf16CodeUnits: Array(sub), count: sub.count)
                 
                 let pasteboard = NSPasteboard.general
                 pasteboard.clearContents()
                 pasteboard.setString(textToYank, forType: .string)
             }
         }
    }
    
    public func undo() { // u
        // Cmd+Z
        simulateKeyPress(keyCode: 6, flags: .maskCommand)
    }
    
    public func redo() { // Ctrl-r (Vim) -> Cmd+Shift+Z (macOS Standard)
        simulateKeyPress(keyCode: 6, flags: [.maskCommand, .maskShift])
    }
    
    public func paste(after: Bool) {
        // Read from Clipboard
        guard let text = NSPasteboard.general.string(forType: .string) else { return }
        
        let isLinewise = text.hasSuffix("\n")
        
        if isLinewise {
             // Linewise Paste
             if after { // p
                 // Paste AFTER the current line.
                 // Move to end of line, open new line (simulated), paste.
                 // OR: Move to next line start, paste?
                 // Standard Vim p for linewise: Pastes BELOW the current line.
                 
                 // Move to End of Line
                 moveToLineRealEnd()
                 // Simulate Return to create new line below
                 simulateKeyPress(keyCode: 36)
                 
                 // Now we are on a new empty line. Paste.
                 // Using Cmd+V
                 simulateKeyPress(keyCode: 9, flags: .maskCommand)
                 
                 // Vim usually leaves cursor at start of pasted text?
                 // TODO: Refine cursor position if needed.
             } else { // P
                 // Paste BEFORE current line.
                 // Move to Start of Line
                 moveToLineStart()
                 
                 // Paste (inserts text and pushes current line down implicitly if it has newline)
                 // But wait, if text has newline at end, we paste "Line\n" at start of "Current".
                 // Result: "Line\nCurrent" -> Correct.
                 simulateKeyPress(keyCode: 9, flags: .maskCommand)
                 
                 // However, we need to ensure we split the line if we are not at start?
                 // moveToLineStart ensures we are at start.
             }
        } else {
            // Characterwise Paste
            if after { // p
                // Paste AFTER cursor.
                // Move Right 1 char (unless at end of line?)
                // If block cursor is on char 'A', pasting 'B' after means 'AB'.
                // If we are at 'A', and press 'p', we want 'A' then 'B'.
                // So we move cursor to the right of A, then paste.
                 
                moveCursor(.right)
                simulateKeyPress(keyCode: 9, flags: .maskCommand)
            } else { // P
                // Paste BEFORE cursor.
                // Just paste.
                simulateKeyPress(keyCode: 9, flags: .maskCommand)
            }
        }
    }
    
    public func pasteInVisual() {
        // In Visual Mode, "Paste" replaces the selection.
        // Standard macOS behavior for Cmd+V over selection is exactly what we want.
        simulateKeyPress(keyCode: 9, flags: .maskCommand)
    }
    
    public func replaceCurrentCharacter(with charCode: CGKeyCode, flags: CGEventFlags) { // r + char
        // Ensure the selection matches the expected block cursor position
        setBlockCursor(true, updateImmediate: true)

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
        // Use simulation to ensure it happens AFTER the typed character in the event queue (Race Condition Fix)
        simulateKeyPress(keyCode: 123)
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
    
    public func moveCursor(_ direction: Direction) {
        // Try AX for Left/Right to preserve block cursor
        // AND ensure we calculate from the *active* cursor end in Visual Mode
        
        // Standard Left/Right using AX
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
        
        // Standard Up/Down using AX (Vertical Motion Logic)
        if direction == .up || direction == .down {
             if let text = getText(), let range = getSelectedRange() {
                 let activeIndex = getActualCursorIndex(from: range)
                 let vDir: WordMotionLogic.VerticalDirection = (direction == .up) ? .up : .down
                 
                 let newIndex = WordMotionLogic.getVerticalIndex(text: text, currentIndex: activeIndex, direction: vDir)
                 
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

extension AccessibilityManager: @unchecked Sendable {}
