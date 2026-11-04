import AppKit
import ServiceManagement

private final class ControlsDocumentView: NSView {
    override var isFlipped: Bool { true }
}

enum ControlsSection: Int, CaseIterable {
    case accessories, notifications, general

    var title: String {
        switch self { case .accessories: return "Accessories"; case .notifications: return "Notifications"; case .general: return "General" }
    }
}

private final class ControlsPanelWindow: NSWindow {
    var selectSection: ((ControlsSection) -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if attachedSheet == nil, event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           let key = event.charactersIgnoringModifiers, let number = Int(key),
           let section = ControlsSection(rawValue: number - 1) {
            selectSection?(section)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

final class ControlsWindow: NSWindowController, NSWindowDelegate {
    private let scrollView = NSScrollView()
    private let documentView = ControlsDocumentView()
    private let stack = NSStackView()
    private let navigation = NSSegmentedControl()
    private let compactNavigation = NSPopUpButton()
    private let footer = NSStackView()
    private let footerSpacer = NSView()
    private var pages: [ControlsSection: NSStackView] = [:]
    private let accessorySummary = NSTextField(wrappingLabelWithString: "Monitoring in the background.")
    private(set) var selectedSection: ControlsSection = .accessories
    private let devices: DeviceCards
    private let notifications: NotificationControls
    private let help = HelpControls()
    private let general: GeneralControls
    private let glyphToggle = NSButton(checkboxWithTitle: "Device icon", target: nil, action: nil)
    private let percentToggle = NSButton(checkboxWithTitle: "Percentage", target: nil, action: nil)
    private let emojiToggle = NSButton(checkboxWithTitle: "Status emoji", target: nil, action: nil)
    private let preferenceHint = NSTextField(wrappingLabelWithString: "Keep at least one item visible.")
    private let onPreferencesChange: (MenuBarPreferences) -> Void
    private var diagnostic = ""
    private var detailsWindow: NSWindow?
    private var hasUserResized = false
    private var adjustingLayout = false

    init(target: AnyObject, enable: Selector, test: Selector, updates: Selector, loginSettings: Selector, quit: Selector, preferences: MenuBarPreferences, alerts: NotificationPreferences, onChange: @escaping (MenuBarPreferences) -> Void, onAlertsChange: @escaping (NotificationPreferences) -> Void, onLoginChange: @escaping (Bool) -> Void, notificationSettingsReader: ((@escaping (NotificationReadiness) -> Void) -> Void)? = nil, onDeviceMuteChange: @escaping (String, Bool) -> Void = { _, _ in }) {
        devices = DeviceCards(onMuteChange: onDeviceMuteChange)
        onPreferencesChange = onChange
        notifications = NotificationControls(target: target, enable: enable, test: test, alerts: alerts, onAlertsChange: onAlertsChange, readSettings: notificationSettingsReader)
        general = GeneralControls(target: target, updates: updates, loginSettings: loginSettings, onLoginChange: onLoginChange)
        let window = ControlsPanelWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 560),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Magic Charger"
        window.isReleasedWhenClosed = false
        window.backgroundColor = .windowBackgroundColor
        super.init(window: window)
        help.onLayoutChange = { [weak self] in self?.resizeForContent() }
        notifications.onLayoutChange = { [weak self] in self?.resizeForContent() }
        NotificationCenter.default.addObserver(notifications, selector: #selector(NotificationControls.refreshSettings),
            name: NSWindow.didBecomeKeyNotification, object: window)
        window.selectSection = { [weak self] section in self?.selectSection(section) }
        window.center()
        let content = window.contentView!
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false

        // A native segmented control supports arrow keys and VoiceOver. The same
        // retained pages stay attached, so telemetry never recreates a control.
        navigation.segmentCount = ControlsSection.allCases.count
        navigation.segmentStyle = .rounded
        navigation.trackingMode = .selectOne
        navigation.controlSize = .large
        navigation.selectedSegment = selectedSection.rawValue
        navigation.target = self; navigation.action = #selector(changeSection)
        navigation.setAccessibilityLabel("Controls section")
        navigation.setAccessibilityHelp("Choose Accessories, Notifications or General. Command-1, Command-2 and Command-3 also switch sections.")
        for section in ControlsSection.allCases { navigation.setLabel(section.title, forSegment: section.rawValue) }
        compactNavigation.addItems(withTitles: ControlsSection.allCases.map(\.title))
        compactNavigation.target = self; compactNavigation.action = #selector(changeCompactSection)
        compactNavigation.setAccessibilityLabel("Controls section")
        compactNavigation.isHidden = true
        let navigationContainer = NSStackView(views: [navigation, compactNavigation])
        navigationContainer.translatesAutoresizingMaskIntoConstraints = false
        let topLine = NSBox(); topLine.boxType = .separator; topLine.translatesAutoresizingMaskIntoConstraints = false
        let bottomLine = NSBox(); bottomLine.boxType = .separator; bottomLine.translatesAutoresizingMaskIntoConstraints = false

        let accessoryTitle = sectionTitle("Your accessories")
        accessorySummary.font = .preferredFont(forTextStyle: .body); accessorySummary.textColor = .secondaryLabelColor
        let accessoryNote = secondaryText("Menu-bar items appear only with verified charging evidence. Unknown readings stay hidden from the menu bar.")
        let accessoryPage = page([accessoryTitle, accessorySummary, devices.view, accessoryNote])
        accessoryPage.setCustomSpacing(20, after: accessorySummary)

        glyphToggle.state = preferences.deviceGlyph ? .on : .off
        percentToggle.state = preferences.percentage ? .on : .off
        emojiToggle.state = preferences.statusEmoji ? .on : .off
        for toggle in [glyphToggle, percentToggle, emojiToggle] {
            toggle.target = self; toggle.action = #selector(changePreferences(_:))
            toggle.setAccessibilityHelp("Choose which elements appear for each verified charging accessory in the menu bar.")
        }
        let toggles = NSStackView(views: [glyphToggle, percentToggle, emojiToggle])
        toggles.orientation = .vertical; toggles.alignment = .leading; toggles.spacing = 10
        preferenceHint.font = .preferredFont(forTextStyle: .body); preferenceHint.textColor = .secondaryLabelColor; preferenceHint.isHidden = true
        let menuOptions = page([sectionTitle("Menu Bar"), secondaryText("Choose what appears for each charging accessory."), toggles, preferenceHint])
        let generalPage = page([menuOptions, separator(), general.view, separator(), help.view])
        generalPage.spacing = 20
        pages = [.accessories: accessoryPage, .notifications: page([notifications.view]), .general: generalPage]
        for section in ControlsSection.allCases {
            let sectionPage = pages[section]!
            stack.addArrangedSubview(sectionPage)
            sectionPage.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            sectionPage.isHidden = section != selectedSection
        }

        let details = NSButton(title: "Details…", target: self, action: #selector(showDetails)); details.bezelStyle = .rounded
        details.setAccessibilityLabel("Technical Details")
        details.setAccessibilityHelp("Show selectable technical information about accessory monitoring.")
        let about = NSButton(title: "About", target: self, action: #selector(showAbout)); about.bezelStyle = .rounded
        let quitButton = NSButton(title: "Quit Magic Charger", target: target, action: quit)
        quitButton.bezelStyle = .rounded
        quitButton.keyEquivalent = "q"; quitButton.keyEquivalentModifierMask = .command
        footerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        for view in [details, about, footerSpacer, quitButton] { footer.addArrangedSubview(view) }
        footer.orientation = .horizontal; footer.alignment = .centerY; footer.spacing = 12
        footer.translatesAutoresizingMaskIntoConstraints = false

        scrollView.hasVerticalScroller = true; scrollView.autohidesScrollers = true; scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        documentView.frame = NSRect(x: 0, y: 0, width: 580, height: 440)
        scrollView.documentView = documentView
        documentView.addSubview(stack)
        for view in [navigationContainer, topLine, scrollView, bottomLine, footer] { content.addSubview(view) }
        NSLayoutConstraint.activate([
            navigationContainer.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            navigationContainer.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            navigationContainer.leadingAnchor.constraint(greaterThanOrEqualTo: content.leadingAnchor, constant: 16),
            navigationContainer.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -16),
            topLine.topAnchor.constraint(equalTo: navigationContainer.bottomAnchor, constant: 16),
            topLine.leadingAnchor.constraint(equalTo: content.leadingAnchor), topLine.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor), scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topLine.bottomAnchor), scrollView.bottomAnchor.constraint(equalTo: bottomLine.topAnchor),
            bottomLine.leadingAnchor.constraint(equalTo: content.leadingAnchor), bottomLine.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            bottomLine.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -12),
            footer.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            footer.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            footer.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 24)
        ])
        useReadableFonts(in: stack)
        window.contentMinSize = NSSize(width: 360, height: 300)
        window.autorecalculatesKeyViewLoop = true
        window.delegate = self
    }

    private func sectionTitle(_ title: String) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: title)
        field.font = .systemFont(ofSize: 22, weight: .semibold)
        return field
    }

    private func secondaryText(_ text: String) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = .preferredFont(forTextStyle: .body); field.textColor = .secondaryLabelColor
        return field
    }

    private func separator() -> NSView {
        let line = NSBox(); line.boxType = .separator
        return line
    }

    private func page(_ views: [NSView]) -> NSStackView {
        let page = NSStackView(views: views)
        page.orientation = .vertical; page.alignment = .leading; page.spacing = 10
        for view in views { view.widthAnchor.constraint(equalTo: page.widthAnchor).isActive = true }
        return page
    }

    @objc private func changeSection() {
        guard let section = ControlsSection(rawValue: navigation.selectedSegment) else { return }
        selectSection(section)
    }

    @objc private func changeCompactSection() {
        guard let section = ControlsSection(rawValue: compactNavigation.indexOfSelectedItem) else { return }
        selectSection(section)
    }

    func selectSection(_ section: ControlsSection) {
        guard section != selectedSection else { return }
        let oldPage = pages[selectedSection]
        let movesFocus = oldPage.map { page in (window?.firstResponder as? NSView)?.isDescendant(of: page) == true } ?? false
        selectedSection = section
        navigation.selectedSegment = section.rawValue
        compactNavigation.selectItem(at: section.rawValue)
        for (key, page) in pages { page.isHidden = key != section }
        resizeForContent()
        documentView.scroll(.zero)
        if movesFocus { window?.makeFirstResponder(navigation.isHidden ? compactNavigation : navigation) }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(readings: [Reading], notificationStatus: String, feedback message: String, diagnostic: String, deviceSettings: DeviceSettings? = nil, collectionMessage: String? = nil) {
        self.diagnostic = diagnostic
        devices.update(readings, settings: deviceSettings, collectionMessage: collectionMessage)
        let count = reconciled(readings).count
        let summary: String
        if collectionMessage != nil { summary = "Accessory information is temporarily unavailable." }
        else if count == 0 { summary = "Monitoring in the background." }
        else {
            let charging = reconciled(readings).filter { AccessoryCardPresentation($0).isCharging }.count
            summary = charging == 0
                ? "\(count) \(count == 1 ? "accessory" : "accessories") detected · No verified charging."
                : "\(count) \(count == 1 ? "accessory" : "accessories") detected · \(charging) charging."
        }
        accessorySummary.stringValue = summary
        notifications.update(status: notificationStatus, message: message)
        resizeForContent()
    }

    func updateLogin(status: SMAppService.Status, feedback: String = "") {
        general.updateLogin(status: status, feedback: feedback)
        resizeForContent()
    }

    func updateFeedbackForUpdates(_ message: String) {
        general.updateFeedbackForUpdates(message)
        resizeForContent()
    }

    static func boundedContentHeight(requested: CGFloat, visible: CGFloat, chrome: CGFloat) -> CGFloat {
        min(requested, max(1, visible - chrome - 40))
    }

    func windowWillStartLiveResize(_ notification: Notification) { hasUserResized = true }
    func windowDidResize(_ notification: Notification) {
        if !adjustingLayout { hasUserResized = true }
        resizeForContent()
    }
    func windowDidChangeScreen(_ notification: Notification) { resizeForContent() }

    private func useReadableFonts(in view: NSView) {
        if let field = view as? NSTextField, let font = field.font,
           font.pointSize < NSFont.preferredFont(forTextStyle: .body).pointSize {
            field.font = NSFontManager.shared.convert(font, toSize: NSFont.preferredFont(forTextStyle: .body).pointSize)
        }
        for child in view.subviews { useReadableFonts(in: child) }
    }

    private func resizeForContent() {
        guard !adjustingLayout, let window = window, let content = window.contentView else { return }
        adjustingLayout = true
        defer { adjustingLayout = false }
        let chrome = window.frame.height - window.contentLayoutRect.height
        // With no WindowServer screen, allow the nominal 580 pt content plus
        // the same 20 pt margin on each edge used for real visible frames.
        let visible = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 580 + 40, height: 700)
        let maxWidth = max(1, visible.width - 40)
        let maxHeight = Self.boundedContentHeight(requested: .greatestFiniteMagnitude, visible: visible.height, chrome: chrome)
        window.contentMinSize = NSSize(width: min(360, maxWidth), height: min(300, maxHeight))
        window.contentMaxSize = NSSize(width: maxWidth, height: maxHeight)
        let width = min(window.contentLayoutRect.width, maxWidth)
        if abs(window.contentLayoutRect.width - width) > 1 {
            window.setContentSize(NSSize(width: width, height: min(window.contentLayoutRect.height, maxHeight)))
        }
        let compact = width < 480
        navigation.isHidden = compact
        compactNavigation.isHidden = !compact
        footer.orientation = compact ? .vertical : .horizontal
        footer.alignment = compact ? .leading : .centerY
        footer.spacing = compact ? 4 : 12
        footerSpacer.isHidden = compact
        content.layoutSubtreeIfNeeded()
        documentView.setFrameSize(NSSize(width: max(1, scrollView.contentSize.width), height: documentView.frame.height))
        documentView.layoutSubtreeIfNeeded()
        // Keep a stable panel height while switching sections or polling. Overflow
        // belongs in this section's scroll view rather than moving the window.
        let requested = stack.fittingSize.height + 48
        documentView.setFrameSize(NSSize(width: documentView.frame.width, height: max(scrollView.contentSize.height, requested)))
        let height = min(hasUserResized ? window.contentLayoutRect.height : CGFloat(560), maxHeight)
        var frame = window.frame
        let newHeight = window.frameRect(forContentRect: NSRect(x: 0, y: 0, width: width, height: height)).height
        let top = frame.maxY
        frame.size.height = newHeight
        frame.origin.x = min(max(frame.minX, visible.minX + 20), visible.maxX - frame.width - 20)
        frame.origin.y = min(max(top - newHeight, visible.minY + 20), visible.maxY - newHeight - 20)
        if frame != window.frame { window.setFrame(frame, display: true) }
        window.recalculateKeyViewLoop()
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Magic Charger",
            .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development",
            .credits: NSAttributedString(string: "MIT License · Copyright © 2026 Arshia Ghaf\nLocal accessory charging notifications.")
        ])
    }

    @objc private func changePreferences(_ sender: NSButton) {
        let preferences = MenuBarPreferences(deviceGlyph: glyphToggle.state == .on, percentage: percentToggle.state == .on, statusEmoji: emojiToggle.state == .on)
        guard preferences.isValid else { sender.state = .on; preferenceHint.isHidden = false; resizeForContent(); return }
        preferenceHint.isHidden = true
        resizeForContent()
        onPreferencesChange(preferences)
    }

    @objc private func showDetails() {
        guard let parent = window else { return }
        let sheet = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 360), styleMask: [.titled], backing: .buffered, defer: false)
        sheet.title = "Technical Details"
        let scroll = NSScrollView(frame: NSRect(x: 20, y: 60, width: 540, height: 280)); scroll.hasVerticalScroller = true
        let text = NSTextView(frame: scroll.bounds); text.isEditable = false; text.isSelectable = true; text.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        text.string = diagnostic; text.textContainerInset = NSSize(width: 8, height: 8); scroll.documentView = text
        let done = NSButton(title: "Done", target: self, action: #selector(closeDetails)); done.keyEquivalent = "\r"; done.frame = NSRect(x: 490, y: 18, width: 70, height: 30)
        sheet.contentView!.addSubview(scroll); sheet.contentView!.addSubview(done)
        detailsWindow = sheet; parent.beginSheet(sheet)
    }
    @objc private func closeDetails() {
        if let sheet = detailsWindow { window?.endSheet(sheet); sheet.orderOut(nil); detailsWindow = nil }
    }
}
