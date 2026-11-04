import AppKit
import SwiftUI

/// A single hosting boundary preserves the existing AppKit accessory-app
/// lifecycle, window reopening, and absence of a permanent Dock icon.
final class OnboardingWindow: NSWindowController {
    let model: OnboardingModel

    init(model: OnboardingModel, quit: @escaping () -> Void) {
        self.model = model
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 840, height: 670),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Welcome to Magic Charger"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 720, height: 520)
        window.autorecalculatesKeyViewLoop = true
        window.contentView = NSHostingView(rootView: OnboardingView(model: model, quit: quit))
        super.init(window: window)
        window.center()
        if let visible = window.screen?.visibleFrame {
            // Accommodate small displays. Content scrolls; navigation remains fixed.
            let maxHeight = visible.height - 40
            if window.frame.height > maxHeight {
                var frame = window.frame
                frame.size.height = maxHeight
                frame.origin.y = visible.midY - maxHeight / 2
                window.setFrame(frame, display: false)
            }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func present() {
        model.refreshSettings()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
