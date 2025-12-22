
import Foundation
@testable import VimOSCore

class WordMotionLogicTests {
    
    var passed = 0
    var failed = 0
    
    func assertEqual<T: Equatable>(_ actual: T?, _ expected: T, _ message: String = "", file: String = #file, line: Int = #line) {
        if actual == expected {
            passed += 1
        } else {
            failed += 1
            print("❌ FAILED: Expected \(expected), got \(String(describing: actual)) - \(message) at \(file):\(line)")
        }
    }
    
    func testGetEndOfWordIndex() {
        print("Running testGetEndOfWordIndex...")
        
        let text = "my name is John"
        // Indices:
        // m: 0
        // y: 1
        //  : 2
        // n: 3
        // a: 4
        // m: 5
        // e: 6
        //  : 7
        
        // 1. Start at 'm' (0) -> Should end at 'y' (1)
        var result = WordMotionLogic.getEndOfWordIndex(text: text, currentIndex: 0)
        assertEqual(result, 1, "From 'm' should go to 'y'")
        
        // 2. Start at 'y' (1) -> Should go to end of next word 'name' -> 'e' (6)
        result = WordMotionLogic.getEndOfWordIndex(text: text, currentIndex: 1)
        assertEqual(result, 6, "From 'y' should go to 'e' (end of next word)")
        
        // 3. Start at 'n' (3) -> Should go to 'e' (6)
        result = WordMotionLogic.getEndOfWordIndex(text: text, currentIndex: 3)
        assertEqual(result, 6, "From 'n' should go to 'e'")
    }
    
    func testGetEndOfWordTrailling() {
        print("Running testGetEndOfWordTrailling...")
        let text = "foo"
        // f:0, o:1, o:2
        
        // From 'f' (0) -> 'o' (2)
        let result = WordMotionLogic.getEndOfWordIndex(text: text, currentIndex: 0)
        assertEqual(result, 2, "From start of single word should go to end")
        
        // From 'o' (2) -> Should stay at 2 (no next word)
        // Wait, current logic:
        // i=3. Loop skip whitespace checks i<count. 3<3 false.
        // Returns i-1 -> 2.
        let result2 = WordMotionLogic.getEndOfWordIndex(text: text, currentIndex: 2)
        assertEqual(result2, 2, "From end of doc should stay put")
    }
    
    func runAll() {
        print("=== Starting WordMotionLogicTests ===")
        testGetEndOfWordIndex()
        testGetEndOfWordTrailling()
        
        print("\n=== Test Summary ===")
        print("Passed: \(passed)")
        print("Failed: \(failed)")
        
        if failed > 0 {
            exit(1)
        }
    }
}
