import Cocoa

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, VimEngineUIDelegate {
    var statusItem: NSStatusItem!
    var hook: KeyboardHook?
    var vimEngine: VimEngine?
    var modeIndicator: ModeIndicator?
    var isEnabled = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup Status Bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "VimOS"
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
        if !accessEnabled {
            print("Please grant Accessibility permissions.")
        }
        
        // Start Engine
        vimEngine = VimEngine()
        vimEngine?.uiDelegate = self
        
        modeIndicator = ModeIndicator()
        
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
                self.modeIndicator?.hide()
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
            modeIndicator?.hide()
            print("VimOS Disabled")
        }
    }
    
    // MARK: - VimEngineUIDelegate
    
    func didSwitchMode(_ mode: VimMode) {
        modeIndicator?.show(mode: mode)
    }
    
    func didHideOverlay() {
        modeIndicator?.hide()
    }
}
