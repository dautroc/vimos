import Cocoa

@MainActor
class ModeIndicator {
    private var window: NSWindow!
    private var textField: NSTextField!
    
    init() {
        setupWindow()
    }
    
    private func setupWindow() {
        // Create a borderless, transparent window
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 30, height: 20),
            styleMask: [.borderless, .nonactivatingPanel], // nonactivatingPanel avoids stealing focus
            backing: .buffered,
            defer: false
        )
        
        window.level = .floating // Keep it floating above normal windows
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true // Pass clicks through
        
        // Setup the label
        textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 30, height: 20))
        textField.isBezeled = false
        textField.drawsBackground = true
        textField.isEditable = false
        textField.isSelectable = false
        textField.alignment = .center
        textField.font = NSFont.boldSystemFont(ofSize: 12)
        textField.wantsLayer = true
        textField.layer?.cornerRadius = 4
        textField.layer?.masksToBounds = true
        
        window.contentView?.addSubview(textField)
    }
    
    func show(mode: VimMode) {
        let (text, color) = getModeConfig(mode)
        
        textField.stringValue = text
        textField.backgroundColor = color
        textField.textColor = .white
        
        updatePosition()
        
        // Ensure it's visible
        window.orderFront(nil)
    }
    
    func hide() {
        window.orderOut(nil)
    }
    
    private func updatePosition() {
        guard let screen = NSScreen.main else { return }
        
        // Bottom Left with some padding
        let paddingX: CGFloat = 20
        let paddingY: CGFloat = 20
        
        let screenFrame = screen.visibleFrame
        // let windowSize = window.frame.size
        
        let x = screenFrame.minX + paddingX
        let y = screenFrame.minY + paddingY
        
        let origin = NSPoint(x: x, y: y)
        window.setFrameOrigin(origin)
    }
    
    private func getModeConfig(_ mode: VimMode) -> (String, NSColor) {
        switch mode {
        case .normal:
            return ("n", NSColor.systemGreen.withAlphaComponent(0.9))
        case .insert:
            return ("i", NSColor.systemRed.withAlphaComponent(0.9))
        case .visual:
            return ("v", NSColor.systemPurple.withAlphaComponent(0.9))
        }
    }
}
