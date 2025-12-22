import Cocoa
import Carbon

public struct KeyUtils {
    // Basic US Layout mapping for MVP
    // KeyCode -> String (Lower case)
    // String -> KeyCode
    
    // Reverse map for commonly used keys in mappings
    static let stringToKeyCode: [String: Int] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19,
        "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28,
        "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37, "j": 38,
        "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44, "n": 45, "m": 46, ".": 47,
        " ": 49, "`": 50, "<esc>": 53
    ]
    
    // US Layout Shift Mapping
    static let shiftMap: [String: String] = [
        "~": "`", "!": "1", "@": "2", "#": "3", "$": "4", "%": "5",
        "^": "6", "&": "7", "*": "8", "(": "9", ")": "0", "_": "-",
        "+": "=", "{": "[", "}": "]", "|": "\\", ":": ";", "\"": "'",
        "<": ",", ">": ".", "?": "/"
    ]
    
    static func keyCode(for char: String) -> Int? {
        if char.lowercased() == "<esc>" { return 53 }
        
        // Check Shift Map
        if let base = shiftMap[char] {
            return stringToKeyCode[base]
        }
        
        // Single char lookup
        return stringToKeyCode[char.lowercased()]
    }
    
    static func modifiers(for char: String) -> CGEventFlags {
        var flags: CGEventFlags = []
        
        // Check Shift Map for special chars
        if shiftMap[char] != nil {
             flags.insert(.maskShift)
        }
        
        // Check uppercase for letters
        if char.count == 1, let first = char.first, first.isUppercase {
            flags.insert(.maskShift)
        }
        return flags
    }
    
    // Convert KeyCode + Flags to String (Input)
    // We only care about the keys capable of starting a mapping (usually letters)
    static func char(from event: CGEvent) -> String? {
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        
        // Use .characters to preserve case (e.g. Shift+h -> "H") for case-sensitive mappings
        if let nsEvent = NSEvent(cgEvent: event), let chars = nsEvent.characters {
            return chars
        }
        return nil
    }
}
