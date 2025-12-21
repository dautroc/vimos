
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
        assertTrue(mockAX.methodCalls.contains("exitVisualMode"))
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
        assertTrue(mockAX.methodCalls.contains("exitVisualMode"))
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
        
        assertTrue(mockAX.methodCalls.contains("selectCurrentLineContent"))
        assertTrue(mockAX.methodCalls.contains("deleteCurrentCharacter"))
        assertTrue(mockAX.methodCalls.contains("prepareForInsertMode(collapseSelection: false)"))
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
        testGlobalMotions()
        testNewLineOps()
        
        print("\n=== Test Summary ===")
        print("Passed: \(passed)")
        print("Failed: \(failed)")
        
        if failed > 0 {
            exit(1)
        }
    }
}
