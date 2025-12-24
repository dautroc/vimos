import Cocoa
import CoreGraphics

public protocol KeyboardHookDelegate: AnyObject {
    func handle(keyEvent: CGEvent) -> Bool // Returns true if key should be suppressed
}

public class KeyboardHook: @unchecked Sendable {
    public weak var delegate: KeyboardHookDelegate?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isHookActive = false

    public var onToggleRequest: (() -> Void)?
    
    private var toggleShortcut: Shortcut? {
        if let str = ConfigManager.shared.config.toggleShortcut {
            return ShortcutUtils.parse(str)
        }
        return nil
    }
    
    // Cache for frontmost application to avoid blocking event tap
    private var currentBundleIdentifier: String?
    private var observer: NSObjectProtocol?

    public init() {
        startObservingApplicationChanges()
    }
    
    deinit {
        if let observer = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
    
    private func startObservingApplicationChanges() {
        // Initial setup
        self.currentBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        
        // Watch for changes
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                self?.currentBundleIdentifier = app.bundleIdentifier
                // print("Active App: \(app.bundleIdentifier ?? "Unknown")")
            }
        }
    }

    public func start() {
        isHookActive = true
        ensureTapEnabled()
    }

    public func stop() {
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
                
                // Handle Disable/Timeout
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    print("Event Tap disabled by timeout. Re-enabling...")
                    CGEvent.tapEnable(tap: hook.eventTap!, enable: true)
                    return Unmanaged.passUnretained(event)
                }
                
                // Check Global Toggle
                if type == .keyDown {
                     let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                     let flags = event.flags
                     
                     if let shortcut = hook.toggleShortcut {
                         let currentModifiers = flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift])
                         let targetModifiers = shortcut.modifiers.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift])

                         if Int(keyCode) == shortcut.keyCode && currentModifiers == targetModifiers {
                             hook.onToggleRequest?()
                             return nil // Swallow
                         }
                     }
                }
                
                if !hook.isHookActive {
                    return Unmanaged.passUnretained(event)
                }
                
                // IGNORE SIMULATED EVENTS (VimOS Magic Number)
                if event.getIntegerValueField(.eventSourceUserData) == 0x555 {
                    return Unmanaged.passUnretained(event)
                }

                // Check Ignored Applications using CACHED value
                if let bundleId = hook.currentBundleIdentifier,
                   ConfigManager.shared.config.ignoredApplications.contains(bundleId) {
                    return Unmanaged.passUnretained(event)
                }
                
                // Process key event through Delegate (VimEngine)
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
