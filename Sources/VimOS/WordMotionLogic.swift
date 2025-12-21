import Foundation

class WordMotionLogic {
    
    static func getNextWordIndex(text: String, currentIndex: Int) -> Int {
        guard currentIndex < text.count else { return currentIndex }
        
        // Vim 'w' logic:
        // 1. If inside a word, scan until end of word + whitespace.
        // 2. If on whitespace, scan until next non-whitespace.
        // 3. Punctuation treats as separate word block.
        
        let nsText = text as NSString
        let range = NSRange(location: currentIndex, length: text.utf16.count - currentIndex)
        
        // Use Scanner or manual loop. Manual loop gives more control matching Vim exactly.
        
        let unicodeScalars = Array(text.unicodeScalars)
        var i = currentIndex
        
        if i >= unicodeScalars.count { return i }
        
        let startChar = unicodeScalars[i]
        let startType = getCharType(startChar)
        
        // 1. Skip current word type
        while i < unicodeScalars.count && getCharType(unicodeScalars[i]) == startType {
            i += 1
        }
        
        // 2. Skip whitespace if we finished a word
        while i < unicodeScalars.count && getCharType(unicodeScalars[i]) == .whitespace {
            i += 1
        }
        
        // Special case: if we started on whitespace, we just consumed it in step 1, 
        // so we are already at next word start (handled by step 1 loop logic effectively).
        // Wait, if we start on whitespace:
        // startType is .whitespace.
        // Step 1 skips all whitespace.
        // Step 2 skips whitespace (redundant but safe).
        // Result: We land on next non-whitespace. Correct.
        
        return i
    }
    
    static func getPrevWordIndex(text: String, currentIndex: Int) -> Int {
        guard currentIndex > 0 else { return 0 }
        
        let unicodeScalars = Array(text.unicodeScalars)
        var i = currentIndex - 1 // Start moving back
        
        // Skip whitespace going back
        while i > 0 && getCharType(unicodeScalars[i]) == .whitespace {
            i -= 1
        }
        
        // Now we are at the end of the previous word.
        // We need to find the START of this word.
        
        let targetType = getCharType(unicodeScalars[i])
        
        while i > 0 && getCharType(unicodeScalars[i - 1]) == targetType {
            i -= 1
        }
        
        return i
    }
    
    // MARK: - Advanced Motions
    
    static func getEndOfWordIndex(text: String, currentIndex: Int) -> Int {
        let unicodeScalars = Array(text.unicodeScalars)
        guard currentIndex + 1 < unicodeScalars.count else { return currentIndex }
        
        var i = currentIndex + 1
        
        // 1. Skip whitespace
        while i < unicodeScalars.count && getCharType(unicodeScalars[i]) == .whitespace {
            i += 1
        }
        
        if i >= unicodeScalars.count { return i - 1 }
        
        let startType = getCharType(unicodeScalars[i])
        
        // 2. Consume word
        while i < unicodeScalars.count && getCharType(unicodeScalars[i]) == startType {
            i += 1
        }
        
        // Return index of last character
        // Vim 'e' lands ON the last character. In caret systems, that usually means
        // after the character if we want to be "at the end".
        // However, technically if we are "on" it, we are before it in terms of "insert".
        // But user specifically requested "This|" (after s).
        return i
    }
    
    static func getLineStartIndex(text: String, currentIndex: Int) -> Int {
        // '0' -> Search backwards for newline
        let unicodeScalars = Array(text.unicodeScalars)
        var i = currentIndex
        
        while i > 0 {
            if unicodeScalars[i - 1] == "\n" {
                return i
            }
            i -= 1
        }
        return 0
    }
    
    static func getLineEndIndex(text: String, currentIndex: Int) -> Int {
        // '$' -> Search forwards for newline
        let unicodeScalars = Array(text.unicodeScalars)
        var i = currentIndex
        
        while i < unicodeScalars.count {
            if unicodeScalars[i] == "\n" {
                return i
            }
            i += 1
        }
        return unicodeScalars.count
    }
    
    static func getVisualLineEndIndex(text: String, currentIndex: Int) -> Int {
        let limit = getLineEndIndex(text: text, currentIndex: currentIndex)
        return max(0, limit - 1)
    }
    
    static func getLineFirstNonWhitespaceIndex(text: String, currentIndex: Int) -> Int {
        // '^' -> Start of line + skip whitespace
        let startOfLine = getLineStartIndex(text: text, currentIndex: currentIndex)
        let unicodeScalars = Array(text.unicodeScalars)
        
        var i = startOfLine
        while i < unicodeScalars.count {
            let char = unicodeScalars[i]
            if char == "\n" { return i } // Empty line
            if getCharType(char) != .whitespace {
                return i
            }
            i += 1
        }
        return i
    }
    
    private enum CharType {
        case alphanumeric
        case punctuation
        case whitespace
    }
    
    private static func getCharType(_ char: UnicodeScalar) -> CharType {
        if CharacterSet.whitespacesAndNewlines.contains(char) {
            return .whitespace
        }
        if CharacterSet.alphanumerics.contains(char) || char == "_" {
            return .alphanumeric
        }
        return .punctuation
    }
}
