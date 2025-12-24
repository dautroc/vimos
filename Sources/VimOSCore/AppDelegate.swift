import Cocoa

@MainActor
public class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var hook: KeyboardHook?
    var vimEngine: VimEngine?

    var isEnabled = true

    public override init() {
        super.init()
    }

    func log(_ message: String) {
        let logURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("vimos_debug.log")
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "\(timestamp): \(message)\n"
        if let data = entry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: logURL)
            }
        }
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        log("Application Launching...")
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? VimOSVersion
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? VimOSVersion
        log("Version: \(version) (\(build))")
        
        // Setup Status Bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let image = NSImage(named: "AppIcon") {
                log("AppIcon loaded successfully")
                image.size = NSSize(width: 18, height: 18)
                image.isTemplate = false // Ensure full color
                button.image = image
            } else {
                log("AppIcon not found, falling back to text")
                button.title = "VimOS"
            }
        }
        
        let menu = NSMenu()
        // Default state is On
        let enabledItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        enabledItem.state = .on
        menu.addItem(enabledItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        
        // Check Permissions
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        log("Accessibility Enabled: \(accessEnabled)")
        
        if !accessEnabled {
            log("Prompting for permissions")
            print("Please grant Accessibility permissions.")
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Required"
            alert.informativeText = "VimOS needs accessibility permissions to intercept keyboard events.\n\nPlease go to System Settings > Privacy & Security > Accessibility and enable VimOS."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Quit")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Open Accessibility Settings
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            // We might want to quit or loop here, but for now just warn.
            // If they don't grant it, the hook won't work.
        }
        // Start Engine
        vimEngine = VimEngine()

        
        hook = KeyboardHook()
        hook?.delegate = vimEngine
        
        // Add Toggle Shortcut Handler
        hook?.onToggleRequest = { [weak self] in
            // Need to find the menu item to toggle state
            // Or just call the logical toggle.
            guard let self = self else { return }
            
            self.isEnabled.toggle()
            // Update Menu UI
            if let menu = self.statusItem.menu, let item = menu.item(at: 0) {
                item.state = self.isEnabled ? .on : .off
            }
            
            if self.isEnabled {
                self.hook?.start()
                print("VimOS Enabled via Shortcut")
            } else {
                self.hook?.stop()
                print("VimOS Disabled via Shortcut")
            }
        }
        
        hook?.start()
    }
    
    @objc func toggleEnabled(_ sender: NSMenuItem) {
        isEnabled.toggle()
        sender.state = isEnabled ? .on : .off
        
        if isEnabled {
            hook?.start()
            print("VimOS Enabled")
        } else {
            hook?.stop()

            print("VimOS Disabled")
        }
    }
    

}
