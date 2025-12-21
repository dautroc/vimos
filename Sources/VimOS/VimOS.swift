import Cocoa
import VimOSCore

import Cocoa

@main
class VimOS {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}



