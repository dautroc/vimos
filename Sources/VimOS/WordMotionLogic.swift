import Foundation

class WordMotionLogic {
    
    // MARK: - Core Motions
    
    enum VerticalDirection {
        case up
        case down
    }
    
    static func getVerticalIndex(text: String, currentIndex: Int, direction: VerticalDirection) -> Int {
        let us = Array(text.utf16)
        if currentIndex >= us.count && currentIndex != 0 { return currentIndex } // Bounds check (allow 0 for empty)
         
        // 1. Calculate current column
        let lineStart = getLineStartIndex(text: text, currentIndex: currentIndex)
        let col = currentIndex - lineStart
        
        let targetLineStart: Int
        
        if direction == .up {
            // Find prev line
            if lineStart == 0 { return 0 } // Already at top
            let prevLineEnd = lineStart - 1
            // Empty line check
             if prevLineEnd < 0 { return 0 }
            
            targetLineStart = getLineStartIndex(text: text, currentIndex: prevLineEnd)
        } else {
            // Find next line
            let lineEnd = getLineEndIndex(text: text, currentIndex: currentIndex)
            if lineEnd >= us.count { return us.count } // End of doc
            targetLineStart = lineEnd + 1
        }
        
        if targetLineStart > us.count { return us.count }
        
        // 2. Find target line length
        let targetLineEnd = getLineEndIndex(text: text, currentIndex: targetLineStart)
        let targetLength = targetLineEnd - targetLineStart
        
        // 3. Apply column (clamped)
        let newCol = min(col, targetLength)
        
        return targetLineStart + newCol
    }
    
    static func getNextWordIndex(text: String, currentIndex: Int) -> Int {
        let us = Array(text.utf16)
        guard currentIndex < us.count else { return currentIndex }
        
        var i = currentIndex
        
        // 1. Skip current word type
        if i < us.count {
            let startType = getCharType(us[i])
            while i < us.count && getCharType(us[i]) == startType {
                i += 1
            }
        }
        
        // 2. Skip whitespace
        while i < us.count && getCharType(us[i]) == .whitespace {
            i += 1
        }
        
        return i
    }
    
    static func getPrevWordIndex(text: String, currentIndex: Int) -> Int {
        let us = Array(text.utf16)
        guard currentIndex > 0 else { return 0 }
        
        var i = currentIndex - 1
        
        // Skip whitespace going back
        while i > 0 && getCharType(us[i]) == .whitespace {
            i -= 1
        }
        
        // Find start of this word block
        let targetType = getCharType(us[i])
        while i > 0 && getCharType(us[i - 1]) == targetType {
            i -= 1
        }
        
        return i
    }
    
    // MARK: - Advanced Motions
    
    static func getEndOfWordIndex(text: String, currentIndex: Int) -> Int {
        let us = Array(text.utf16)
        guard currentIndex + 1 < us.count else { return currentIndex }
        
        var i = currentIndex + 1
        
        // 1. Skip whitespace
        while i < us.count && getCharType(us[i]) == .whitespace {
            i += 1
        }
        
        if i >= us.count { return i - 1 }
        
        let startType = getCharType(us[i])
        
        // 2. Consume word
        while i < us.count && getCharType(us[i]) == startType {
            i += 1
        }
        
        return i
    }
    
    static func getLineStartIndex(text: String, currentIndex: Int) -> Int {
        let us = Array(text.utf16)
        if currentIndex >= us.count { return 0 }
        var i = currentIndex
        let newline: UInt16 = 0x0A // \n
        
        while i > 0 {
            if us[i - 1] == newline {
                return i
            }
            i -= 1
        }
        return 0
    }
    
    static func getLineEndIndex(text: String, currentIndex: Int) -> Int {
        // Returns newline index or count
        let us = Array(text.utf16)
        var i = currentIndex
        let newline: UInt16 = 0x0A // \n
        
        while i < us.count {
            if us[i] == newline {
                return i
            }
            i += 1
        }
        return us.count
    }
    
    static func getVisualLineEndIndex(text: String, currentIndex: Int) -> Int {
        let limit = getLineEndIndex(text: text, currentIndex: currentIndex)
        // If limit is newline, we want the char before it (unless empty line at 0)
        return max(0, limit - 1)
    }
    
     static func getLineFirstNonWhitespaceIndex(text: String, currentIndex: Int) -> Int {
        let startOfLine = getLineStartIndex(text: text, currentIndex: currentIndex)
        let us = Array(text.utf16)
        
        var i = startOfLine
        let newline: UInt16 = 0x0A
        
        while i < us.count {
            let char = us[i]
            if char == newline { return i }
            if getCharType(char) != .whitespace {
                return i
            }
            i += 1
        }
        return i
    }
    
    // MARK: - Character Search
    
    static func getNextOccurrenceIndex(text: String, currentIndex: Int, targetChar: String, stopBefore: Bool) -> Int {
        let us = Array(text.utf16)
        guard let target = targetChar.utf16.first, currentIndex + 1 < us.count else { return currentIndex }
        
        var i = currentIndex + 1
        while i < us.count {
            if us[i] == target {
                 if stopBefore {
                    return max(currentIndex, i - 1)
                } else {
                    return i
                }
            }
            i += 1
        }
        return currentIndex
    }
    
    // MARK: - Text Object Logic (Lookahead Supported)
    
    static func getInnerObjectRange(text: String, currentIndex: Int, targetChar: String) -> (Int, Int)? {
        let us = Array(text.utf16)
        guard currentIndex < us.count, let target = targetChar.utf16.first else { return nil }
        
        // Map target to pair
        var open: UInt16?
        var close: UInt16?
        
        // Simple mapping, can extend
        switch target {
        case 0x22: // " (Straight)
            return getQuoteRange(us: us, index: currentIndex, markers: [0x22, 0x201C, 0x201D])
        case 0x201C, 0x201D: // “ ” (Smart Double)
            return getQuoteRange(us: us, index: currentIndex, markers: [0x22, 0x201C, 0x201D])
        case 0x27: // ' (Straight)
            return getQuoteRange(us: us, index: currentIndex, markers: [0x27, 0x2018, 0x2019])
        case 0x2018, 0x2019: // ‘ ’ (Smart Single)
            return getQuoteRange(us: us, index: currentIndex, markers: [0x27, 0x2018, 0x2019])
        case 0x60: // `
            return getQuoteRange(us: us, index: currentIndex, markers: [0x60])
        case 0x28, 0x29, 0x62: // ( ) b
             open = 0x28; close = 0x29
        case 0x7B, 0x7D, 0x42: // { } B
             open = 0x7B; close = 0x7D
        case 0x5B, 0x5D: // [ ]
             open = 0x5B; close = 0x5D
        case 0x3C, 0x3E: // < >
             open = 0x3C; close = 0x3E
        default:
             return nil
        }
        
        if let o = open, let c = close {
            return getBracketRange(us: us, index: currentIndex, open: o, close: c)
        }
        return nil
    }
    
    private static func getQuoteRange(us: [UInt16], index: Int, markers: Set<UInt16>) -> (Int, Int)? {
        // Line-based scanning is most reliable for quotes
        var ls = index
        let newline: UInt16 = 0x0A
        while ls > 0 && us[ls - 1] != newline { ls -= 1 }
        
        var le = index
        while le < us.count && us[le] != newline { le += 1 }
        
        // Find all quote markers on this line
        var quotes: [Int] = []
        for j in ls..<le {
            if markers.contains(us[j]) {
                quotes.append(j)
            }
        }
        
        // Match pairs: [0,1], [2,3]...
        for i in stride(from: 0, to: quotes.count - 1, by: 2) {
            let startQ = quotes[i]
            let endQ = quotes[i+1]
            
            // If cursor is within this pair (including on the quotes)
            if index >= startQ && index <= endQ {
                 return (startQ + 1, endQ - 1)
            }
        }
        
        // Fallback: Lookahead for next pair (even if not on this line? Vim usually stays on line)
        // Search forwards for next pair
        for i in stride(from: 0, to: quotes.count - 1, by: 2) {
             let startQ = quotes[i]
             if startQ > index {
                 let endQ = quotes[i+1]
                 return (startQ + 1, endQ - 1)
             }
        }
        
        return nil
    }
    
    private static func getBracketRange(us: [UInt16], index: Int, open: UInt16, close: UInt16) -> (Int, Int)? {
        // 1. Try Surrounding (Backwards then Forwards)
        var start = -1
        var nesting = 0
        var i = index
        
        // Search back
        while i >= 0 {
            if us[i] == close {
                nesting += 1
            } else if us[i] == open {
                if nesting > 0 {
                    nesting -= 1
                } else {
                    start = i
                    break
                }
            }
            i -= 1
        }
        
        // Search forward from valid start, or try to recover?
        // If we found a start, we MUST find a matching end to be "surrounded".
        if start != -1 {
            var end = -1
            nesting = 0
            i = index // Resume scan from cursor roughly?
            // Actually strictly scan from start+1 to ensure correct pairing
            i = start + 1
            while i < us.count {
                if us[i] == open {
                    nesting += 1
                } else if us[i] == close {
                    if nesting > 0 {
                         nesting -= 1
                    } else if i >= index { // Ensure end is after cursor
                        end = i
                        break
                    }
                }
                i += 1
            }
            
            if end != -1 {
                return (start + 1, end - 1)
            }
        }
        
        // 2. Lookahead
        i = index
        while i < us.count {
            if us[i] == open {
                let newStart = i
                // Find matching close
                var j = newStart + 1
                var innerNesting = 0
                while j < us.count {
                    if us[j] == open {
                        innerNesting += 1
                    } else if us[j] == close {
                        if innerNesting > 0 {
                            innerNesting -= 1
                        } else {
                            return (newStart + 1, j - 1)
                        }
                    }
                    j += 1
                }
                // If lookahead start found but no end, we stop usually or keep searching? 
                // Typically we want the *first* complete pair.
                // But simplified: break if start object found but unmatched.
                break
            }
            i += 1
        }
        
        return nil
    }
    
    // MARK: - Helpers
    
    private enum CharType {
        case alphanumeric
        case punctuation
        case whitespace
    }
    
    private static func getCharType(_ code: UInt16) -> CharType {
        // Basic ASCII check for performance
        if code == 32 || code == 9 || code == 10 || code == 13 { return .whitespace }
        
        // Alphanumeric: 0-9, A-Z, a-z, _
        if (code >= 48 && code <= 57) || 
           (code >= 65 && code <= 90) || 
           (code >= 97 && code <= 122) || code == 95 {
            return .alphanumeric
        }
        
        // Heuristic: If it's not whitespace, we can call it punctuation/symbol for word motion,
        // or refine further. For now assume anything else is symbol.
        return .punctuation
    }
}
