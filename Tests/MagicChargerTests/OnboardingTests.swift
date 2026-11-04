import XCTest
import AppKit
@testable import MagicCharger

final class OnboardingStateTests: XCTestCase {
    func testFirstRunStaysPendingAtLoginThenCompletesWithoutChangingPreferences() throws {
        let suite = "MagicChargerTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(false, forKey: "alert.started")
        let state = OnboardingState(defaults: defaults, hasExistingInstallation: false)
        XCTAssertFalse(state.shouldPresentAutomatically(launchedAtLogin: true))
        XCTAssertFalse(state.isComplete)
        // Creating the installation identity during a quiet login launch must
        // not make the next process mistake this for a migrated installation.
        let pendingAfterRestart = OnboardingState(defaults: defaults, hasExistingInstallation: true)
        XCTAssertFalse(pendingAfterRestart.isComplete)
        XCTAssertTrue(state.shouldPresentAutomatically(launchedAtLogin: false))
        state.finish()
        XCTAssertFalse(state.shouldPresentAutomatically(launchedAtLogin: false))
        XCTAssertFalse(defaults.bool(forKey: "alert.started"))
        XCTAssertEqual(defaults.integer(forKey: OnboardingState.completionKey), OnboardingState.currentVersion)
        let reloaded = OnboardingState(defaults: defaults, hasExistingInstallation: true)
        XCTAssertTrue(reloaded.isComplete)
    }

    func testExistingInstallationMigratesQuietlyAndFutureCompletionVersionIsPreserved() throws {
        let suite = "MagicChargerTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertTrue(OnboardingState(defaults: defaults, hasExistingInstallation: true).isComplete)
        defaults.set(99, forKey: OnboardingState.completionKey)
        XCTAssertTrue(OnboardingState(defaults: defaults, hasExistingInstallation: true).isComplete)
        let future = OnboardingState(defaults: defaults, hasExistingInstallation: true)
        future.finish()
        XCTAssertEqual(defaults.integer(forKey: OnboardingState.completionKey), 99)
    }
}

@MainActor
final class OnboardingWindowTests: XCTestCase {
    private func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
    private func button(_ title: String, in controller: OnboardingWindow) throws -> NSButton {
        let content = try XCTUnwrap(controller.window?.contentView)
        return try XCTUnwrap(descendants(content).compactMap { $0 as? NSButton }.first { $0.title == title })
    }

    func testCompactScreensLeaveRoomForWindowChromeAndKeepActionsOutsideScrolling() throws {
        XCTAssertEqual(OnboardingWindow.boundedContentSize(visible: NSSize(width: 550, height: 520)), NSSize(width: 510, height: 460))
        _ = NSApplication.shared
        let controller = OnboardingWindow(readSettings: { _ in }, requestNotifications: {}, onFinish: {})
        let content = try XCTUnwrap(controller.window?.contentView)
        content.layoutSubtreeIfNeeded()
        let scroll = try XCTUnwrap(descendants(content).compactMap { $0 as? NSScrollView }.first)
        let action = try button("Continue", in: controller)
        XCTAssertFalse(action.isDescendant(of: scroll))
        let actionFrame = content.convert(action.bounds, from: action)
        XCTAssertTrue(content.bounds.contains(actionFrame))
        XCTAssertLessThanOrEqual(actionFrame.maxY, scroll.frame.minY)
    }

    func testNavigationAndDismissalNeverRequestPermissionOrFinishTwice() throws {
        _ = NSApplication.shared
        var requests = 0
        var finishes = 0
        var reads = 0
        let controller = OnboardingWindow(readSettings: { _ in reads += 1 }, requestNotifications: { requests += 1 }, onFinish: { finishes += 1 })
        let window = try XCTUnwrap(controller.window)
        XCTAssertFalse(window.isVisible)
        XCTAssertEqual(controller.page, .welcome)
        XCTAssertEqual(reads, 0)
        try button("Continue", in: controller).performClick(nil)
        XCTAssertEqual(controller.page, .notifications)
        XCTAssertEqual(reads, 1)
        controller.updateNotificationStatus("Permission changed")
        controller.updateNotificationStatus("Permission changed")
        XCTAssertEqual(reads, 2, "Repeated telemetry must not poll notification policy")
        XCTAssertEqual(requests, 0)
        try button("Back", in: controller).performClick(nil)
        XCTAssertEqual(controller.page, .welcome)
        try button("Continue", in: controller).performClick(nil)
        try button("Enable Notifications…", in: controller).performClick(nil)
        XCTAssertEqual(requests, 1)
        try button("Not Now", in: controller).performClick(nil)
        XCTAssertEqual(finishes, 1)
        XCTAssertFalse(controller.windowShouldClose(window))
        XCTAssertEqual(finishes, 1)
        XCTAssertEqual(requests, 1)
    }

    func testCloseAndSetUpLaterCompleteWithoutReadingOrRequestingPermission() throws {
        _ = NSApplication.shared
        var finishes = 0
        var reads = 0
        var requests = 0
        let controller = OnboardingWindow(readSettings: { _ in reads += 1 }, requestNotifications: { requests += 1 }, onFinish: { finishes += 1 })
        try button("Set Up Later", in: controller).performClick(nil)
        XCTAssertEqual(finishes, 1)
        XCTAssertEqual(reads, 0)
        XCTAssertEqual(requests, 0)
        let closing = OnboardingWindow(readSettings: { _ in reads += 1 }, requestNotifications: { requests += 1 }, onFinish: { finishes += 1 })
        XCTAssertFalse(closing.windowShouldClose(try XCTUnwrap(closing.window)))
        XCTAssertEqual(finishes, 2)
        XCTAssertEqual(reads, 0)
        XCTAssertEqual(requests, 0)
    }
}
