import Cocoa
import CoreGraphics

protocol KeyboardHookDelegate: AnyObject {
    func handle(keyEvent: CGEvent) -> Bool // Returns true if key should be suppressed
}

class KeyboardHook {
    weak var delegate: KeyboardHookDelegate?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init() {}

    func start() {
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let hook = Unmanaged<KeyboardHook>.fromOpaque(refcon).takeUnretainedValue()
                
                if hook.delegate?.handle(keyEvent: event) == true {
                    return nil // Swallow event
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("Failed to create event tap. Check permissions.")
            exit(1)
        }

        self.eventTap = eventTap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        print("Keyboard Hook started.")
    }

    func stop() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
    }
}
