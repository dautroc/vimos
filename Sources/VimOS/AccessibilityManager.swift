import Cocoa
import ApplicationServices

enum Direction {
    case left
    case right
    case up
    case down
}

class AccessibilityManager {
    
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
    
    // MARK: - Word Operations
    
    func moveWordForward() {
        if let text = getText(), let currentRange = getSelectedRange() {
            let currentIndex = currentRange.location
            let newIndex = WordMotionLogic.getNextWordIndex(text: text, currentIndex: currentIndex)
            if newIndex != currentIndex {
                setSelectedRange(CFRange(location: newIndex, length: 0))
                return
            }
        }
        
        // Fallback: Simulate Option+Right Arrow
        simulateKeyPress(keyCode: 124, flags: .maskAlternate)
    }
    
    func moveWordBackward() {
        if let text = getText(), let currentRange = getSelectedRange() {
             let currentIndex = currentRange.location
             let newIndex = WordMotionLogic.getPrevWordIndex(text: text, currentIndex: currentIndex)
             if newIndex != currentIndex {
                 setSelectedRange(CFRange(location: newIndex, length: 0))
                 return
             }
        }
        
        // Fallback: Simulate Option+Left Arrow
        print("AX Failed or Partial: Falling back to Option+Left")
        simulateKeyPress(keyCode: 123, flags: .maskAlternate)
    }
    
    func moveToEndOfWord() {
        if let text = getText(), let currentRange = getSelectedRange() {
            let currentIndex = currentRange.location
            let newIndex = WordMotionLogic.getEndOfWordIndex(text: text, currentIndex: currentIndex)
             if newIndex != currentIndex {
                 setSelectedRange(CFRange(location: newIndex, length: 0))
                 return
             }
        }
        // No good fallback system key for 'e' unfortunately.
    }
    
    func moveToLineStart() { // 0
        if let text = getText(), let currentRange = getSelectedRange() {
             let currentIndex = currentRange.location
             let newIndex = WordMotionLogic.getLineStartIndex(text: text, currentIndex: currentIndex)
             if newIndex != currentIndex {
                 setSelectedRange(CFRange(location: newIndex, length: 0))
                 return
             }
        }
        // Fallback: Cmd+Left
        simulateKeyPress(keyCode: 123, flags: .maskCommand)
    }
    
    func moveToLineEnd() { // $
        if let text = getText(), let currentRange = getSelectedRange() {
             let currentIndex = currentRange.location
             let newIndex = WordMotionLogic.getLineEndIndex(text: text, currentIndex: currentIndex)
             if newIndex != currentIndex {
                 setSelectedRange(CFRange(location: newIndex, length: 0))
                 return
             }
        }
        // Fallback: Cmd+Right
        simulateKeyPress(keyCode: 124, flags: .maskCommand)
    }
    
    func moveToLineStartNonWhitespace() { // ^
        if let text = getText(), let currentRange = getSelectedRange() {
             let currentIndex = currentRange.location
             let newIndex = WordMotionLogic.getLineFirstNonWhitespaceIndex(text: text, currentIndex: currentIndex)
             if newIndex != currentIndex {
                 setSelectedRange(CFRange(location: newIndex, length: 0))
                 return
             }
        }
        // Fallback approximation: Cmd+Left, then Option+Right? Too complex. Just Cmd+Left.
        simulateKeyPress(keyCode: 123, flags: .maskCommand)
    }
    
    func getText() -> String? {
        guard let element = getFocusedElement() else { return nil }
        
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        
        if result == .success, let stringValue = value as? String {
            return stringValue
        }
        // Debug
        var role: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        print("getText failed. Role: \(String(describing: role)). Error: \(result.rawValue)")
        
        return nil
    }
    
    func setText(_ text: String) {
         guard let element = getFocusedElement() else { return }
         
         // Note: AXValue can be read-only.
         // A safer way often is to paste, but let's try AX API first for "Replace"
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
        // Fallback: Simulate Arrow Keys for movement if AX fails or is too complex for simple moves
        let keyCode: CGKeyCode
        switch direction {
        case .left: keyCode = 123
        case .right: keyCode = 124
        case .up: keyCode = 126
        case .down: keyCode = 125
        }
        
        simulateKeyPress(keyCode: keyCode)
    }
    
    private func simulateKeyPress(keyCode: CGKeyCode, flags: CGEventFlags = []) {
        // combinedSessionState is often required for events to be seen by other apps
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            print("Failed to create event source")
            return
        }
        
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = flags
        
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = flags
        
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

