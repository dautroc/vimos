import Cocoa

public struct Shortcut: Sendable {
    public let keyCode: Int
    public let modifiers: CGEventFlags
}

public struct ShortcutUtils {
    public static func parse(_ input: String) -> Shortcut? {
        let parts = input.lowercased().split(separator: "+").map { String($0).trimmingCharacters(in: .whitespaces) }
        guard let keyString = parts.last else { return nil }
        
        var modifiers: CGEventFlags = []
        
        for part in parts.dropLast() {
            switch part {
            case "cmd", "command":
                modifiers.insert(.maskCommand)
            case "opt", "option", "alt":
                modifiers.insert(.maskAlternate)
            case "ctrl", "control":
                modifiers.insert(.maskControl)
            case "shift":
                modifiers.insert(.maskShift)
            default:
                break
            }
        }
        
        // Use KeyUtils to get keycode
        guard let keyCode = KeyUtils.keyCode(for: keyString) else {
            return nil
        }
        
        return Shortcut(keyCode: keyCode, modifiers: modifiers)
    }
}
