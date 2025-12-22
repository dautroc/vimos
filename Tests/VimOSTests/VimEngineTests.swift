
import Foundation
import ApplicationServices
import VimOSCore

class VimEngineTests {
    
    var engine: VimEngine!
    var mockAX: MockAccessibilityManager!
    
    var passed = 0
    var failed = 0
    
    func setUp() {
        mockAX = MockAccessibilityManager()
        engine = VimEngine(accessibilityManager: mockAX)
    }
    
    // MARK: - Assertion Helpers
    
    func assert(_ condition: Bool, _ message: String = "", file: String = #file, line: Int = #line) {
        if condition {
            passed += 1
        } else {
            failed += 1
            print("❌ FAILED: \(message) at \(file):\(line)")
        }
    }
    
    func assertEqual<T: Equatable>(_ actual: T?, _ expected: T, _ message: String = "", file: String = #file, line: Int = #line) {
        if actual == expected {
            passed += 1
        } else {
            failed += 1
            print("❌ FAILED: Expected \(expected), got \(String(describing: actual)) - \(message) at \(file):\(line)")
        }
    }
    
    func assertTrue(_ condition: Bool, _ message: String = "", file: String = #file, line: Int = #line) {
        assert(condition, message, file: file, line: line)
    }
    
    func assertFalse(_ condition: Bool, _ message: String = "", file: String = #file, line: Int = #line) {
        assert(!condition, message, file: file, line: line)
    }

    // MARK: - Helpers
    
    func simulateKey(_ keyCode: Int, flags: CGEventFlags = []) -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return false }
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: true) else { return false }
        event.flags = flags
        return engine.handle(keyEvent: event)
    }
    
    func simulateFlagsChanged(_ keyCode: Int, flags: CGEventFlags) -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return false }
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: true) else { return false }
        event.type = .flagsChanged
        event.flags = flags
        return engine.handle(keyEvent: event)
    }

    // MARK: - Tests
    
    func testNormalModeNavigation() {
        setUp()
        print("Running testNormalModeNavigation...")
        
        // Default start in Insert Mode, switch to Normal
        _ = simulateKey(53) // ESC
        
        // h
        _ = simulateKey(4)
        assertEqual(mockAX.methodCalls.last, "moveCursor(left)")
        
        // j
        _ = simulateKey(38)
        assertEqual(mockAX.methodCalls.last, "moveCursor(down)")
        
        // k
        _ = simulateKey(40)
        assertEqual(mockAX.methodCalls.last, "moveCursor(up)")

        // l
        _ = simulateKey(37)
        assertEqual(mockAX.methodCalls.last, "moveCursor(right)")
    }
    
    func testWordMotions() {
        setUp()
        print("Running testWordMotions...")
        
        _ = simulateKey(53) // ESC
        
        // w
        _ = simulateKey(13)
        assertEqual(mockAX.methodCalls.last, "moveWordForward")
        
        // b
        _ = simulateKey(11)
        assertEqual(mockAX.methodCalls.last, "moveWordBackward")
        
        // e
        _ = simulateKey(14)
        assertEqual(mockAX.methodCalls.last, "moveToEndOfWord")
    }
    
    func testLineMotions() {
        setUp()
        print("Running testLineMotions...")
        
        _ = simulateKey(53) // ESC
        
        // 0
        _ = simulateKey(29)
        assertEqual(mockAX.methodCalls.last, "moveToLineStart")
        
        // $ (Shift + 4) -> 21
        _ = simulateKey(21, flags: .maskShift)
        assertEqual(mockAX.methodCalls.last, "moveToLineEnd")
        
        // ^ (Shift + 6) -> 22
        _ = simulateKey(22, flags: .maskShift)
        assertEqual(mockAX.methodCalls.last, "moveToLineStartNonWhitespace")
    }
    
    func testModeSwitching() {
        setUp()
        print("Running testModeSwitching...")
        
        // Start Insert
        _ = simulateKey(53) // ESC -> Normal
        assertTrue(mockAX.isBlockCursorEnabled, "Block cursor should be enabled in Normal mode")
        
        // i -> Insert
        _ = simulateKey(34)
        assertFalse(mockAX.isBlockCursorEnabled, "Block cursor should be disabled in Insert mode")
        
        // Back to Normal
        _ = simulateKey(53)
        assertTrue(mockAX.isBlockCursorEnabled)
        // Explicitly check call log if needed, but isBlockCursorEnabled is sufficient for this test mostly.
    }
    
    func testVisualModeToggle() {
        setUp()
        print("Running testVisualModeToggle...")
        
        _ = simulateKey(53) // ESC -> Normal
        
        // v -> Visual
        _ = simulateKey(9)
        assertTrue(mockAX.methodCalls.contains("enterVisualMode"))
        
        // v -> Normal
        _ = simulateKey(9)
        assertTrue(mockAX.methodCalls.contains("exitVisualMode(collapseSelection: true)"))
    }
    
    func testVisualLineModeToggle() {
        setUp()
        print("Running testVisualLineModeToggle...")
        
        _ = simulateKey(53) // ESC -> Normal
        
        // V (Shift + v) -> Visual Line
        _ = simulateKey(9, flags: .maskShift)
        assertEqual(mockAX.methodCalls.last, "enterVisualLineMode")
        
        // Esc -> Normal
        _ = simulateKey(53)
        assertTrue(mockAX.methodCalls.contains("exitVisualMode(collapseSelection: true)"))
    }
    
    func testOperators() {
        setUp()
        print("Running testOperators...")
        
        _ = simulateKey(53) // ESC
        
        // x
        _ = simulateKey(7)
        assertEqual(mockAX.methodCalls.last, "deleteCurrentCharacter")
    }
    
    func testChangeLine() {
        setUp()
        print("Running testChangeLine...")
        
        _ = simulateKey(53) // ESC
        
        // cc
        _ = simulateKey(8) // c
        _ = simulateKey(8) // c
        
        assertTrue(mockAX.methodCalls.contains("selectCurrentLineContent(includeNewline: false)"))
        assertTrue(mockAX.methodCalls.contains("deleteCurrentCharacter"))
        assertTrue(mockAX.methodCalls.contains("prepareForInsertMode(collapseSelection: false)"))
    }
    
    func testChangeRestOfLine() {
        setUp()
        print("Running testChangeRestOfLine...")
        
        _ = simulateKey(53) // ESC
        
        // C (Shift + c)
        _ = simulateKey(8, flags: .maskShift) // C
        
        assertTrue(mockAX.methodCalls.contains("enterVisualMode"))
        assertTrue(mockAX.methodCalls.contains("moveToLineEnd"))
        assertTrue(mockAX.methodCalls.contains("deleteCurrentCharacter"))
        assertTrue(mockAX.methodCalls.contains("prepareForInsertMode(collapseSelection: false)"))
    }
    
    func testYankLine() {
        setUp()
        print("Running testYankLine...")
        
        _ = simulateKey(53) // ESC
        
        // yy
        _ = simulateKey(16) // y
        _ = simulateKey(16) // y
        
        assertTrue(mockAX.methodCalls.contains("yankCurrentLine(includeNewline: true)"))
        // After yy, we stay in normal mode and clear pending operator
        assertFalse(mockAX.methodCalls.contains("prepareForInsertMode")) 
    }
    
    func testYankShift() {
        setUp()
        print("Running testYankShift...")
        
        _ = simulateKey(53) // ESC
        
        // Y (Shift + y)
        _ = simulateKey(16, flags: .maskShift)
        
        assertTrue(mockAX.methodCalls.contains("yankRestOfLine"))
    }
    
    func testGlobalMotions() {
        setUp()
        print("Running testGlobalMotions...")
        
        _ = simulateKey(53) // ESC
        
        // G (Shift + g)
        _ = simulateKey(5, flags: .maskShift)
        assertEqual(mockAX.methodCalls.last, "moveToEndOfDocument")
        
        // gg
        _ = simulateKey(5)
        _ = simulateKey(5)
        assertEqual(mockAX.methodCalls.last, "moveToStartOfDocument")
    }
    
    func testNewLineOps() {
        setUp()
        print("Running testNewLineOps...")
        
        _ = simulateKey(53) // ESC
        
        // o
        _ = simulateKey(31)
        assertTrue(mockAX.methodCalls.contains("openNewLineBelow"))
        
        setUp() // Reset
        _ = simulateKey(53) // ESC
        
        // O
        _ = simulateKey(31, flags: .maskShift)
        assertTrue(mockAX.methodCalls.contains("openNewLineAbove"))
    }
    
    func testKeyMapping() {
        setUp()
        print("Running testKeyMapping...")
        
        // Setup Config
        let config = VimOSConfig(mappings: [
            KeyMapping(from: "gh", to: "^"),
            KeyMapping(from: "gh", to: "^"),
            KeyMapping(from: "gl", to: "$"),
            KeyMapping(from: "jk", to: "<esc>")
        ], ignoredApplications: [])
        ConfigManager.shared.setConfig(config)
        
        // 1. Test "gh" -> "^" in Normal Mode
        _ = simulateKey(53) // ESC -> Normal
        
        // Simulate 'g' (KeyCode 5)
        let handledG = simulateKey(5)
        assertTrue(handledG, "Trigger key 'g' should be swallowed")
        
        // Simulate 'h' (KeyCode 4)
        let handledH = simulateKey(4)
        assertTrue(handledH, "Trigger key 'h' should be handled")
        
        // Should have executed "moveToLineStartNonWhitespace" (Action of ^)
        // Check if "moveToLineStartNonWhitespace" is in methodCalls
        // Note: mockAX.methodCalls is a list. Last one should be relevant?
        // ^ calls moveToLineStartNonWhitespace.
        assertTrue(mockAX.methodCalls.contains("moveToLineStartNonWhitespace"), "gh should trigger ^ action")
        
        // ^ calls moveToLineStartNonWhitespace.
        assertTrue(mockAX.methodCalls.contains("moveToLineStartNonWhitespace"), "gh should trigger ^ action")
        
        // 1b. Test "gl" -> "$" in Normal Mode
        _ = simulateKey(53) // Ensure Normal
        // Simulate 'g' (KeyCode 5)
        _ = simulateKey(5)
        // Simulate 'l' (KeyCode 37)
        _ = simulateKey(37)
        
        // Should have executed "moveToLineEnd" (Action of $)
        // $ is mapped to Shift+4. Logic should produce Shift+4 event -> VimEngine -> handle(Shift+4) -> moveToLineEnd
        assertTrue(mockAX.methodCalls.contains("moveToLineEnd"), "gl should trigger $ action")
        
        // 2. Test "jk" -> "<esc>" in Insert Mode
        setUp() // Reset state (starts in Insert)
        
        // Ensure we are in insert (block cursor false)
        assertFalse(mockAX.isBlockCursorEnabled, "Should start in Insert Mode")
        
        // Simulate 'j' (KeyCode 38)
        let handledJ = simulateKey(38)
        assertTrue(handledJ, "Trigger key 'j' should be swallowed in Insert Mode because of mapping")
        
        // Simulate 'k' (KeyCode 40)
        let handledK = simulateKey(40)
        assertTrue(handledK, "Trigger key 'k' should be handled")
        
        // Should Switch to Normal Mode (Block Cursor True)
        // Also Esc in Insert Mode usually moves cursor left?
        assertTrue(mockAX.isBlockCursorEnabled, "jk should switch to Normal Mode")
        
        // Reset Config
        ConfigManager.shared.setConfig(.defaults)
    }
    
    func testSystemShortcuts() {
        setUp()
        print("Running testSystemShortcuts...")
        _ = simulateKey(53) // Normal Mode
        
        // Simulate Cmd+C (KeyCode 8 + Command)
        let handledCmdC = simulateKey(8, flags: .maskCommand)
        assertFalse(handledCmdC, "Cmd+C should NOT be handled by VimHub (should pass through)")
        
        // Simulate Cmd+V (KeyCode 9 + Command)
        let handledCmdV = simulateKey(9, flags: .maskCommand)
        assertFalse(handledCmdV, "Cmd+V should NOT be handled by VimHub")
        
        // Simulate Option+Left (KeyCode 123 + Option)
        let handledOptionLeft = simulateKey(123, flags: .maskAlternate)
        assertFalse(handledOptionLeft, "Option+Left should pass through")
        
        // Simulate Ctrl+A (KeyCode 0 + Control)
        let handledCtrlA = simulateKey(0, flags: .maskControl)
        assertFalse(handledCtrlA, "Ctrl+A should pass through")
        
        // Exception: Ctrl+R (Redo)
        // Ensure mock has no previous Redo call
        // mockAX.methodCalls.removeAll() // ideally
        
        let handledCtrlR = simulateKey(15, flags: .maskControl)
        assertTrue(handledCtrlR, "Ctrl+R (Redo) SHOULD be handled by VimHub")
        assertTrue(mockAX.methodCalls.contains("redo"), "Ctrl+R should trigger redo")
        
        // Simulate Complex Shortcut (Cmd+Opt+Shift+Ctrl+Space)
        // Space = 49
        let complexFlags: CGEventFlags = [.maskCommand, .maskAlternate, .maskShift, .maskControl]
        let handledComplex = simulateKey(49, flags: complexFlags)
        assertFalse(handledComplex, "Complex shortcut should pass through")
    }
    
    func testPaste() {
        setUp()
        print("Running testPaste...")
        
        _ = simulateKey(53) // Normal Mode
        
        // p
        _ = simulateKey(35)
        assertTrue(mockAX.methodCalls.contains("paste(after: true)"), "p should trigger paste(after: true)")
        
        // P
        _ = simulateKey(35, flags: .maskShift)
        assertTrue(mockAX.methodCalls.contains("paste(after: false)"), "P should trigger paste(after: false)")
    }
    
    func testVisualPaste() {
        setUp()
        print("Running testVisualPaste...")
        
        _ = simulateKey(53) // Normal Mode
        
        // v -> Visual
        _ = simulateKey(9)
        assertTrue(mockAX.methodCalls.contains("enterVisualMode"))
        
        // p
        _ = simulateKey(35)
        assertTrue(mockAX.methodCalls.contains("pasteInVisual"))
        assertTrue(mockAX.methodCalls.contains("exitVisualMode(collapseSelection: false)"), "Should exit visual mode without collapsing")
        // Check for deferred cursor update
        assertTrue(mockAX.methodCalls.contains("setBlockCursor(true, updateImmediate: false)"), "Should defer cursor update to avoid racing with paste")
        
        // Test Visual Line Mode P
        setUp() // Reset
        _ = simulateKey(53)
        // V (Shift+v)
        _ = simulateKey(9, flags: .maskShift)
        assertTrue(mockAX.methodCalls.contains("enterVisualLineMode"))
        
        // P (Shift+p)
        _ = simulateKey(35, flags: .maskShift)
        assertTrue(mockAX.methodCalls.contains("pasteInVisual"))
        assertTrue(mockAX.methodCalls.contains("exitVisualMode(collapseSelection: false)"))
        assertTrue(mockAX.methodCalls.contains("setBlockCursor(true, updateImmediate: false)"))
    }
    
    func testModifierFlagsChanged() {
        setUp()
        print("Running testModifierFlagsChanged...")
        
        // Simulate pressing Shift (Left Shift keycode 56)
        // flagsChanged event
        let handledShift = simulateFlagsChanged(56, flags: .maskShift)
        assertFalse(handledShift, "Shift key press (flagsChanged) should pass through")
        
        // Simulate pressing Control (Left Control keycode 59)
        let handledCtrl = simulateFlagsChanged(59, flags: .maskControl)
        assertFalse(handledCtrl, "Control key press (flagsChanged) should pass through")
    }
    
    func runAll() {
        print("=== Starting VimOS Tests ===")
        testNormalModeNavigation()
        testWordMotions()
        testLineMotions()
        testModeSwitching()
        testVisualModeToggle()
        testVisualLineModeToggle()
        testOperators()
        testChangeLine()
        testChangeRestOfLine()
        testYankLine()
        testYankShift()
        testGlobalMotions()
        testNewLineOps()
        testKeyMapping()
        testSystemShortcuts()
        testPaste()
        testVisualPaste()
        testModifierFlagsChanged()
        
        print("\n=== Test Summary ===")
        print("Passed: \(passed)")
        print("Failed: \(failed)")
        
        if failed > 0 {
            exit(1)
        }
    }
}
