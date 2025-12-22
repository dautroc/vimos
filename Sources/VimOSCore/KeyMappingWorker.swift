import Cocoa

public class KeyMappingWorker {
    private var buffer: String = ""
    private var bufferEvents: [CGEvent] = []
    
    public init() {}
    
    // Returns:
    // 1. Handled (Bool): If true, the caller should do nothing more with this event (it was swallowed or processed).
    // 2. EventsToProcess ([CGEvent]?): If non-nil, these events should be fed back into the engine immediately.
    public func process(_ event: CGEvent, mode: VimMode) -> (Bool, [CGEvent]?) {
        guard let char = KeyUtils.char(from: event) else {
            // If modifier or special key not in our "char" map, we might want to flush buffer
            if !buffer.isEmpty {
                return (true, flush() + [event])
            }
            return (false, nil)
        }
        
        let newBuffer = buffer + char
        let mappings = ConfigManager.shared.config.mappings
        let modeStr = modeString(mode)
        
        // 1. Check for Exact Match
        if let match = mappings.first(where: { 
            ($0.modes == nil || $0.modes!.contains(modeStr)) && $0.from == newBuffer 
        }) {
            // Found match!
            clearBuffer()
            
            // Generate target events
            let targets = events(for: match.to)
            return (true, targets)
        }
        
        // 2. Check for Prefix Match
        let possible = mappings.contains { 
            ($0.modes == nil || $0.modes!.contains(modeStr)) && $0.from.hasPrefix(newBuffer) 
        }
        
        if possible {
            // Potential match, buffer and swallow
            buffer = newBuffer
            bufferEvents.append(event)
            return (true, nil)
        }
        
        // 3. No match, flush buffer + current
        if !buffer.isEmpty {
            let flushed = flush()
            // return flushed events + current event
            return (true, flushed + [event])
        }
        
        // Buffer was empty, and no prefix match.
        return (false, nil)
    }
    
    private func flush() -> [CGEvent] {
         let events = bufferEvents
         clearBuffer()
         return events
    }
    
    private func clearBuffer() {
        buffer = ""
        bufferEvents = []
    }
    
    private func modeString(_ mode: VimMode) -> String {
        switch mode {
        case .normal: return "normal"
        case .insert: return "insert"
        case .visual: return "visual"
        }
    }
    
    private func events(for string: String) -> [CGEvent] {
         // This is a simplification. Ideally specific map for common output keys.
         if let code = KeyUtils.keyCode(for: string) {
             let flags = KeyUtils.modifiers(for: string)
             guard let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(code), keyDown: true) else { return [] }
             event.flags = flags
             return [event]
         }
         return []
    }
}
