import AppKit

/// A quiet, replayable introduction. Reading permission is safe; requesting it
/// is possible only through the separate, explicitly labeled button.
private final class OnboardingDocumentView: NSView {
    override var isFlipped: Bool { true }
}

final class OnboardingWindow: NSWindowController, NSWindowDelegate {
    enum Page: Int { case welcome, notifications }
    private(set) var page = Page.welcome
    private let pages = OnboardingDocumentView()
    private let scrollView = NSScrollView()
    private let stepLabel = NSTextField(labelWithString: "")
    private let primaryButton = NSButton()
    private let secondaryButton = NSButton()
    private let backButton = NSButton()
    private let permissionButton = NSButton()
    private let permissionStatus = NSTextField(wrappingLabelWithString: "Checking notification permission…")
    private let readSettings: (@escaping (NotificationReadiness) -> Void) -> Void
    private let requestNotifications: () -> Void
    private let onFinish: () -> Void
    private var settingsGeneration = 0
    private var lastNotificationStatus: String?
    private var finished = false

    init(readSettings: @escaping (@escaping (NotificationReadiness) -> Void) -> Void,
         requestNotifications: @escaping () -> Void, onFinish: @escaping () -> Void) {
        self.readSettings = readSettings
        self.requestNotifications = requestNotifications
        self.onFinish = onFinish
        let visible = NSScreen.main?.visibleFrame.size ?? NSSize(width: 660, height: 660)
        let size = Self.boundedContentSize(visible: visible)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Welcome to Magic Charger"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        super.init(window: window)
        window.delegate = self
        window.center()
        window.autorecalculatesKeyViewLoop = true
        buildChrome()
        showPage(.welcome)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func present() {
        finished = false
        showPage(.welcome)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func boundedContentSize(visible: NSSize) -> NSSize {
        NSSize(width: min(620, max(1, visible.width - 40)), height: min(560, max(1, visible.height - 60)))
    }

    private func buildChrome() {
        guard let content = window?.contentView else { return }
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = pages
        content.addSubview(scrollView)
        stepLabel.font = .systemFont(ofSize: 11, weight: .medium)
        stepLabel.textColor = .secondaryLabelColor
        stepLabel.setAccessibilityLabel("Setup progress")
        backButton.title = "Back"
        backButton.bezelStyle = .rounded
        backButton.target = self; backButton.action = #selector(back)
        secondaryButton.bezelStyle = .rounded
        secondaryButton.target = self; secondaryButton.action = #selector(finish)
        secondaryButton.keyEquivalent = "\u{1b}"
        primaryButton.bezelStyle = .rounded
        primaryButton.controlSize = .large
        primaryButton.keyEquivalent = "\r"
        primaryButton.target = self; primaryButton.action = #selector(advance)
        primaryButton.setContentHuggingPriority(.required, for: .horizontal)
        let spacer = NSView()
        let actions = NSStackView(views: [backButton, spacer, secondaryButton, primaryButton])
        actions.spacing = 12; actions.orientation = .horizontal
        let footer = NSStackView(views: [stepLabel, actions])
        footer.orientation = .vertical; footer.alignment = .leading; footer.spacing = 16
        footer.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(footer)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 42),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -42),
            scrollView.topAnchor.constraint(equalTo: content.topAnchor, constant: 22),
            scrollView.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -20),
            footer.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 32),
            footer.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -32),
            footer.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -26),
            actions.widthAnchor.constraint(equalTo: footer.widthAnchor)
        ])
    }

    private func showPage(_ next: Page) {
        page = next
        pages.subviews.forEach { $0.removeFromSuperview() }
        let body = next == .welcome ? welcomePage() : notificationsPage()
        body.translatesAutoresizingMaskIntoConstraints = false
        pages.addSubview(body)
        NSLayoutConstraint.activate([
            body.leadingAnchor.constraint(equalTo: pages.leadingAnchor),
            body.trailingAnchor.constraint(equalTo: pages.trailingAnchor),
            body.topAnchor.constraint(equalTo: pages.topAnchor)
        ])
        backButton.isHidden = next == .welcome
        stepLabel.stringValue = next == .welcome ? "1 of 2 · Overview" : "2 of 2 · Optional notifications"
        primaryButton.title = next == .welcome ? "Continue" : "Open Magic Charger"
        secondaryButton.title = next == .welcome ? "Set Up Later" : "Not Now"
        layoutPage(resetScroll: true)
        window?.defaultButtonCell = primaryButton.cell as? NSButtonCell
        window?.recalculateKeyViewLoop()
        window?.makeFirstResponder(primaryButton)
        if next == .notifications { refreshNotificationReadiness() }
    }

    private func layoutPage(resetScroll: Bool = false) {
        guard let body = pages.subviews.first else { return }
        window?.contentView?.layoutSubtreeIfNeeded()
        pages.setFrameSize(NSSize(width: scrollView.contentSize.width, height: scrollView.contentSize.height))
        pages.layoutSubtreeIfNeeded()
        pages.setFrameSize(NSSize(width: pages.frame.width, height: max(scrollView.contentSize.height, body.fittingSize.height)))
        if resetScroll { pages.scroll(.zero) }
    }

    private func welcomePage() -> NSStackView {
        let icon = NSImageView()
        icon.image = NSApp.applicationIconImage
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.setAccessibilityElement(false)
        NSLayoutConstraint.activate([icon.widthAnchor.constraint(equalToConstant: 76), icon.heightAnchor.constraint(equalToConstant: 76)])
        let heading = title("Welcome to\nMagic Charger")
        let introduction = text("Charging reminders for your Magic Keyboard and Magic Mouse.", size: 15)
        introduction.alignment = .center
        let hero = NSStackView(views: [icon, heading, introduction])
        hero.orientation = .vertical; hero.alignment = .centerX; hero.spacing = 10
        let features = NSStackView(views: [
            feature(symbol: "menubar.rectangle", title: "Charging in the menu bar", detail: "A menu-bar item appears only with verified charging evidence. Otherwise, it disappears."),
            feature(symbol: "app.badge", title: "Reopen controls", detail: "Reopen Magic Charger from Finder or Spotlight for controls and Quit. Closing the window keeps monitoring."),
            feature(symbol: "lock.shield", title: "On-device privacy", detail: "Accessory battery information stays on your Mac. No account, analytics, or input capture.")
        ])
        features.orientation = .vertical; features.alignment = .leading; features.spacing = 19
        for row in features.arrangedSubviews { row.widthAnchor.constraint(equalTo: features.widthAnchor).isActive = true }
        let stack = NSStackView(views: [hero, features])
        stack.orientation = .vertical; stack.alignment = .centerX; stack.spacing = 28
        for view in [hero, features] { view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
        introduction.widthAnchor.constraint(equalTo: hero.widthAnchor).isActive = true
        return stack
    }

    private func notificationsPage() -> NSStackView {
        let bell = NSImageView(image: NSImage(systemSymbolName: "bell.badge", accessibilityDescription: nil) ?? NSImage())
        bell.contentTintColor = .controlAccentColor
        bell.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 44, weight: .regular)
        bell.setAccessibilityElement(false)
        bell.heightAnchor.constraint(equalToConstant: 64).isActive = true
        let heading = title("Charging notifications")
        let introduction = text("Enable notifications to receive charging reminders.", size: 15)
        introduction.alignment = .center
        let hero = NSStackView(views: [bell, heading, introduction])
        hero.orientation = .vertical; hero.alignment = .centerX; hero.spacing = 12
        introduction.widthAnchor.constraint(equalTo: hero.widthAnchor).isActive = true
        let reminders = feature(symbol: "battery.75percent", title: "Reminders at 78% and 80%", detail: "Choose charging-start and fully-charged alerts in Notifications. Magic Charger cannot stop charging.")
        permissionButton.title = "Enable Notifications…"
        permissionButton.bezelStyle = .rounded
        permissionButton.controlSize = .large
        permissionButton.target = self; permissionButton.action = #selector(enableNotifications)
        permissionButton.setAccessibilityHelp("Only this button requests notification permission, or opens macOS notification settings if permission has already been decided.")
        permissionStatus.font = .systemFont(ofSize: 12)
        permissionStatus.textColor = .secondaryLabelColor
        permissionStatus.alignment = .center
        let permission = NSStackView(views: [permissionButton, permissionStatus])
        permission.orientation = .vertical; permission.alignment = .centerX; permission.spacing = 10
        permissionStatus.widthAnchor.constraint(equalTo: permission.widthAnchor).isActive = true
        let note = text("You can enable notifications later. Focus and screen sharing may silence banners.", size: 12)
        note.alignment = .center
        let stack = NSStackView(views: [hero, reminders, permission, note])
        stack.orientation = .vertical; stack.alignment = .centerX; stack.spacing = 25
        for view in [hero, reminders, permission, note] { view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
        return stack
    }

    private func title(_ value: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: value)
        label.font = .systemFont(ofSize: 29, weight: .bold)
        label.alignment = .center
        return label
    }

    private func text(_ value: String, size: CGFloat) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: value)
        label.font = .systemFont(ofSize: size)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func feature(symbol: String, title: String, detail: String) -> NSView {
        let image = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage())
        image.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 23, weight: .regular)
        image.contentTintColor = .controlAccentColor
        image.setAccessibilityElement(false)
        image.widthAnchor.constraint(equalToConstant: 30).isActive = true
        image.heightAnchor.constraint(equalToConstant: 30).isActive = true
        let name = NSTextField(labelWithString: title)
        name.font = .systemFont(ofSize: 13, weight: .semibold)
        let explanation = text(detail, size: 13)
        let labels = NSStackView(views: [name, explanation])
        labels.orientation = .vertical; labels.alignment = .leading; labels.spacing = 4
        explanation.widthAnchor.constraint(equalTo: labels.widthAnchor).isActive = true
        let row = NSStackView(views: [image, labels])
        row.orientation = .horizontal; row.alignment = .top; row.spacing = 15
        return row
    }

    // Telemetry renders may repeat. Re-read permission only when the existing
    // notification coordinator reports a change, or this window gains focus.
    func updateNotificationStatus(_ status: String) {
        guard status != lastNotificationStatus else { return }
        lastNotificationStatus = status
        refreshNotificationReadiness()
    }

    func refreshNotificationReadiness() {
        guard page == .notifications else { return }
        settingsGeneration += 1
        let generation = settingsGeneration
        readSettings { [weak self] readiness in
            DispatchQueue.main.async {
                guard let self = self, self.page == .notifications, generation == self.settingsGeneration else { return }
                self.permissionStatus.stringValue = readiness.summary
                self.permissionButton.title = readiness.needsPermission ? "Enable Notifications…" : "Notification Settings…"
                self.layoutPage()
            }
        }
    }

    func windowDidBecomeKey(_ notification: Notification) { refreshNotificationReadiness() }
    func windowShouldClose(_ sender: NSWindow) -> Bool { finish(); return false }
    @objc private func enableNotifications() { requestNotifications() }
    @objc private func back() { showPage(.welcome) }
    @objc private func advance() { page == .welcome ? showPage(.notifications) : finish() }
    @objc private func finish() {
        guard !finished else { return }
        finished = true
        settingsGeneration += 1
        window?.orderOut(nil)
        onFinish()
    }
}
