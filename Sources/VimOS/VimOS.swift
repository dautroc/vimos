import Cocoa

@main
struct VimOS {
    static func main() {
        print("VimOS Starting...")
        
        // Request Accessibility Permissions
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessEnabled {
            print("Please grant Accessibility permissions in System Settings.")
            // Don't exit immediately, macOS might show the prompt.
            // But usually we need to restart the app after granting.
        }

        let vimEngine = VimEngine()
        let hook = KeyboardHook()
        hook.delegate = vimEngine
        hook.start()
        
        // Run Loop
        RunLoop.main.run()
    }
}


