
import Foundation
import ApplicationServices
@testable import VimOSCore

class MockAccessibilityManager: AccessibilityManagerProtocol {
    
    // State Tracking
    var isVisualLineMode = false
    var isBlockCursorEnabled = false
    var cursorIndex: Int = 0
    var selectionLength: Int = 0
    var text: String = ""
    
    // Call Logs
    var methodCalls: [String] = []
    
    // Mock Helpers
    func reset() {
        methodCalls = []
        isVisualLineMode = false
        isBlockCursorEnabled = false
        cursorIndex = 0
        selectionLength = 0
    }
    
    var isVisualMode: Bool {
        // Simple heuristic for mock
        return methodCalls.contains("enterVisualMode") && !methodCalls.contains("exitVisualMode")
    }

    // Protocol Conformance
    
    func setBlockCursor(_ enabled: Bool, updateImmediate: Bool = true) {
        isBlockCursorEnabled = enabled
        methodCalls.append("setBlockCursor(\(enabled), updateImmediate: \(updateImmediate))")
    }
    
    func enterVisualMode() {
        methodCalls.append("enterVisualMode")
    }
    
    func exitVisualMode(collapseSelection: Bool = true) {
        isVisualLineMode = false
        methodCalls.append("exitVisualMode(collapseSelection: \(collapseSelection))")
    }
    
    public func prepareForInsertMode(collapseSelection: Bool) {
        methodCalls.append("prepareForInsertMode(collapseSelection: \(collapseSelection))")
        isBlockCursorEnabled = false
        if collapseSelection {
            selectionLength = 0
        }
    }
    
    func moveWordForward() {
        methodCalls.append("moveWordForward")
    }
    
    func moveWordBackward() {
        methodCalls.append("moveWordBackward")
    }
    
    func moveToEndOfWord() {
        methodCalls.append("moveToEndOfWord")
    }
    
    func moveToLineStart() {
        methodCalls.append("moveToLineStart")
    }
    
    func moveToLineEnd() {
        methodCalls.append("moveToLineEnd")
    }
    
    func selectCurrentLineContent(includeNewline: Bool) -> Bool {
        methodCalls.append("selectCurrentLineContent(includeNewline: \(includeNewline))")
        return true // detailed simulation would go here
    }
    
    func moveToLineStartNonWhitespace() {
        methodCalls.append("moveToLineStartNonWhitespace")
    }
    
    func moveToStartOfDocument() {
        methodCalls.append("moveToStartOfDocument")
    }
    
    func moveToEndOfDocument() {
        methodCalls.append("moveToEndOfDocument")
    }
    
    func moveToNextOccurrence(of char: String, stopBefore: Bool) {
        methodCalls.append("moveToNextOccurrence(of: \(char), stopBefore: \(stopBefore))")
    }
    
    func selectInnerObject(char: String) {
        methodCalls.append("selectInnerObject(char: \(char))")
    }
    
    func enterVisualLineMode() {
        isVisualLineMode = true
        methodCalls.append("enterVisualLineMode")
    }
    
    func moveToLineRealEnd() {
        methodCalls.append("moveToLineRealEnd")
    }
    
    func openNewLineBelow() {
        methodCalls.append("openNewLineBelow")
    }
    
    func openNewLineAbove() {
        methodCalls.append("openNewLineAbove")
    }
    
    func deleteVisualLine() {
        methodCalls.append("deleteVisualLine")
    }
    
    func deleteCurrentCharacter() {
        methodCalls.append("deleteCurrentCharacter")
    }
    
    func yank() {
        methodCalls.append("yank")
    }
    
    func yankCurrentLine(includeNewline: Bool) {
        methodCalls.append("yankCurrentLine(includeNewline: \(includeNewline))")
    }
    
    func yankRestOfLine() {
        methodCalls.append("yankRestOfLine")
    }
    
    func undo() {
        methodCalls.append("undo")
    }
    
    func redo() {
        methodCalls.append("redo")
    }
    
    func paste(after: Bool) {
        methodCalls.append("paste(after: \(after))")
    }
    
    func pasteInVisual() {
        methodCalls.append("pasteInVisual")
    }
    
    func replaceCurrentCharacter(with charCode: CGKeyCode, flags: CGEventFlags) {
        methodCalls.append("replaceCurrentCharacter(with: \(charCode))")
    }
    
    func moveCursor(_ direction: Direction) {
        methodCalls.append("moveCursor(\(direction))")
    }
}
