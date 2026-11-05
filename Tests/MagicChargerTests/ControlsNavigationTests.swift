import XCTest
import AppKit
@testable import MagicCharger

@MainActor
final class ControlsNavigationTests: XCTestCase {
    private func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
    private func make() -> ControlsWindow {
        let app = NSApplication.shared
        return ControlsWindow(target: app, enable: #selector(NSApplication.terminate(_:)), test: #selector(NSApplication.terminate(_:)),
            updates: #selector(NSApplication.terminate(_:)), loginSettings: #selector(NSApplication.terminate(_:)), quit: #selector(NSApplication.terminate(_:)),
            preferences: MenuBarPreferences(), alerts: NotificationPreferences(), onChange: { _ in }, onAlertsChange: { _ in }, onLoginChange: { _ in },
            notificationSettingsReader: { _ in })
    }

    func testSectionSwitchesRetainControlsAndExcludeHiddenPagesFromKeyboardLoop() throws {
        let controller = make()
        let window = try XCTUnwrap(controller.window), content = try XCTUnwrap(window.contentView)
        defer { window.close() }
        controller.update(readings: [], notificationStatus: "SIMULATED", feedback: "", diagnostic: "SIMULATED")
        let before = descendants(content).compactMap { $0 as? NSButton }
        let icon = try XCTUnwrap(before.first { $0.title == "Device icon" })
        let start = try XCTUnwrap(before.first { $0.title == AlertKind.started.title })
        let initialSize = window.contentLayoutRect.size
        XCTAssertTrue(icon.isHiddenOrHasHiddenAncestor)
        XCTAssertTrue(start.isHiddenOrHasHiddenAncestor)
        controller.selectSection(.general)
        XCTAssertFalse(icon.isHiddenOrHasHiddenAncestor)
        XCTAssertTrue(start.isHiddenOrHasHiddenAncestor)
        controller.selectSection(.notifications)
        XCTAssertTrue(icon.isHiddenOrHasHiddenAncestor)
        XCTAssertFalse(start.isHiddenOrHasHiddenAncestor)
        controller.selectSection(.accessories)
        XCTAssertEqual(window.contentLayoutRect.size, initialSize)
        XCTAssertEqual(before.map(ObjectIdentifier.init), descendants(content).compactMap { $0 as? NSButton }.map(ObjectIdentifier.init))
        let navigation = try XCTUnwrap(descendants(content).compactMap { $0 as? NSSegmentedControl }.first)
        XCTAssertEqual(navigation.selectedSegment, 0)
        let command = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
            timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "2", charactersIgnoringModifiers: "2", isARepeat: false, keyCode: 19))
        XCTAssertTrue(window.performKeyEquivalent(with: command))
        XCTAssertEqual(controller.selectedSection, .notifications)
        XCTAssertEqual(navigation.selectedSegment, 1)
        XCTAssertFalse(window.isVisible)
    }

    func testNarrowWindowUsesNativeSectionMenuWithoutChangingSelection() throws {
        let controller = make()
        let window = try XCTUnwrap(controller.window), content = try XCTUnwrap(window.contentView)
        defer { window.close() }
        controller.selectSection(.general)
        controller.windowWillStartLiveResize(Notification(name: NSWindow.willStartLiveResizeNotification, object: window))
        window.setContentSize(NSSize(width: 360, height: 400))
        controller.update(readings: [], notificationStatus: "SIMULATED", feedback: "", diagnostic: "SIMULATED")
        let navigation = try XCTUnwrap(descendants(content).compactMap { $0 as? NSSegmentedControl }.first)
        let menu = try XCTUnwrap(descendants(content).compactMap { $0 as? NSPopUpButton }.first)
        XCTAssertTrue(navigation.isHiddenOrHasHiddenAncestor)
        XCTAssertFalse(menu.isHiddenOrHasHiddenAncestor)
        XCTAssertEqual(menu.titleOfSelectedItem, "General")
        menu.selectItem(at: 0)
        menu.sendAction(try XCTUnwrap(menu.action), to: menu.target)
        XCTAssertEqual(controller.selectedSection, .accessories)
        XCTAssertEqual(navigation.selectedSegment, 0)
    }

    func testCardPresentationDoesNotColorStaleInvalidOrFullUncertaintyAsCharging() {
        let now = Date()
        func presentation(_ percent: Int?, _ state: Charging = .charging, age: TimeInterval = 0, full: Bool = false) -> AccessoryCardPresentation {
            AccessoryCardPresentation(Reading(id: "SIMULATED", name: "Magic Mouse", symbol: "magicmouse", percent: percent,
                state: state, sampled: now.addingTimeInterval(-age), evidence: "SIMULATED", fullChargeEvidence: full), now: now)
        }
        let live = presentation(79)
        XCTAssertTrue(live.isCharging); XCTAssertEqual(live.fraction, 0.79)
        XCTAssertEqual(live.percentageDescription, "79 percent")
        for value in [presentation(79, age: 90), presentation(79, age: -1), presentation(nil), presentation(101)] {
            XCTAssertFalse(value.isCharging)
            XCTAssertEqual(value.status, "Charging state unknown")
            XCTAssertEqual(value.percentage, "—")
            XCTAssertNil(value.fraction)
        }
        let full = presentation(100, .unknown, full: true)
        XCTAssertFalse(full.isCharging)
        XCTAssertEqual(full.status, "100% reported · charging state unknown")
        XCTAssertEqual(full.percentage, "100%")
    }
}
