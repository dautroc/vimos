import Cocoa
import CoreGraphics

protocol KeyboardHookDelegate: AnyObject {
    func handle(keyEvent: CGEvent) -> Bool // Returns true if key should be suppressed
}

class KeyboardHook {
    weak var delegate: KeyboardHookDelegate?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isHookActive = false

    var onToggleRequest: (() -> Void)?

    init() {}

    func start() {
        isHookActive = true
        ensureTapEnabled()
    }

    func stop() {
        isHookActive = false
        // Do NOT disable the tap, so we can still listen for toggle shortcut
        // ensureTapEnabled() // Make sure it's running
        print("Keyboard Hook paused (listening for toggle).")
    }
    
    private func ensureTapEnabled() {
        if eventTap != nil {
             return 
        }
        
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let hook = Unmanaged<KeyboardHook>.fromOpaque(refcon).takeUnretainedValue()
                
                // Check Global Toggle: Option + V (KeyCode 9)
                if type == .keyDown {
                     let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                     let flags = event.flags
                     if keyCode == 9 && flags.contains(.maskAlternate) { // Option + V
                         hook.onToggleRequest?()
                         return nil // Swallow
                     }
                }
                
                if !hook.isHookActive {
                    return Unmanaged.passUnretained(event)
                }
                
                if hook.delegate?.handle(keyEvent: event) == true {
                    return nil // Swallow event
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("Failed to create event tap. Check permissions.")
            return
        }

        self.eventTap = eventTap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        print("Keyboard Hook tap created and enabled.")
    }
}
