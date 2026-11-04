import XCTest
import AppKit
import UserNotifications
@testable import MagicCharger

@MainActor
final class OnboardingTests: XCTestCase {
    private func defaults() -> UserDefaults {
        let name = "MagicChargerTests.Onboarding.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    private func readiness(_ status: UNAuthorizationStatus, alerts: UNNotificationSetting = .enabled,
                           style: UNAlertStyle = .banner) -> NotificationReadiness {
        NotificationReadiness(authorization: status, alerts: alerts, style: style,
            notificationCenter: .enabled, sound: .enabled, scheduledDelivery: .disabled)
    }

    private func settle() async {
        await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
    }

    func testSetupRequiresExplicitCompletionAndNeverRequestsPermissionByNavigation() {
        let defaults = defaults()
        var requests = 0
        var finishes = 0
        let model = OnboardingModel(defaults: defaults, preferences: .init(), readSettings: { _ in },
            requestPermission: { _ in requests += 1 }, openSettings: {}, savePreferences: { _ in }, finish: { finishes += 1 })
        XCTAssertEqual(model.step, .welcome)
        XCTAssertFalse(model.isComplete)
        model.revisit(.ready)
        XCTAssertEqual(model.step, .welcome)
        model.back()
        XCTAssertEqual(model.step, .welcome)
        model.advance()
        model.advance()
        XCTAssertEqual(model.step, .ready)
        XCTAssertFalse(model.isComplete)
        XCTAssertEqual(finishes, 0)
        model.back()
        XCTAssertEqual(model.step, .alerts)
        model.advance()
        model.advance()
        XCTAssertTrue(defaults.bool(forKey: OnboardingModel.completionKey))
        XCTAssertEqual(finishes, 1)
        XCTAssertEqual(requests, 0)
        model.restartWalkthrough()
        XCTAssertEqual(model.step, .welcome)
        XCTAssertTrue(model.isComplete, "Replaying setup preserves completion and saved choices")
    }

    func testUnfinishedSetupRemainsIncompleteAcrossModelRecreation() {
        let defaults = defaults()
        func model() -> OnboardingModel {
            OnboardingModel(defaults: defaults, preferences: .init(), readSettings: { _ in },
                requestPermission: { _ in XCTFail("Permission must be explicitly requested") }, openSettings: {},
                savePreferences: { _ in }, finish: {})
        }
        let first = model()
        first.advance()
        XCTAssertFalse(model().isComplete)
        first.advance()
        first.advance()
        XCTAssertTrue(model().isComplete)
    }

    func testAllFourAlertChoicesReachExistingSettingsAndCanAllBeDisabled() {
        var saved: [NotificationPreferences] = []
        let model = OnboardingModel(defaults: defaults(), preferences: .init(), readSettings: { _ in },
            requestPermission: { _ in }, openSettings: {}, savePreferences: { saved.append($0) }, finish: {})
        for kind in AlertKind.allCases { model.setAlert(kind, enabled: false) }
        XCTAssertEqual(saved.count, 4)
        XCTAssertEqual(model.enabledAlertCount, 0)
        XCTAssertTrue(saved.last!.milestones.isEmpty)
        XCTAssertEqual(model.reminderTitle, "Automatic reminders are off")
        for kind in AlertKind.allCases { model.setAlert(kind, enabled: true) }
        XCTAssertEqual(model.preferences, NotificationPreferences())
        model.setAlert(.target, enabled: true)
        XCTAssertEqual(saved.count, 8, "No redundant persistence when a value is unchanged")
        model.synchronizePreferences(.init(started: false, soon: false, target: true, full: false))
        XCTAssertEqual(model.enabledAlertCount, 1)
        XCTAssertEqual(saved.count, 8, "Synchronizing existing controls must not create a feedback loop")
    }

    func testPermissionRequestsAreExplicitCoalescedAndErrorCanBeRetried() async {
        var callbacks: [(String?) -> Void] = []
        let waiting = readiness(.notDetermined)
        let model = OnboardingModel(defaults: defaults(), preferences: .init(), readSettings: { $0(waiting) },
            requestPermission: { callbacks.append($0) }, openSettings: { XCTFail("Not a settings action") },
            savePreferences: { _ in }, finish: {})
        model.permissionAction()
        XCTAssertTrue(callbacks.isEmpty, "An unknown readiness state cannot trigger a prompt")
        model.refreshSettings()
        await settle()
        XCTAssertTrue(callbacks.isEmpty)
        model.permissionAction()
        model.permissionAction()
        XCTAssertEqual(callbacks.count, 1)
        XCTAssertTrue(model.permissionRequestInFlight)
        callbacks[0]("macOS couldn’t complete the request.")
        await settle()
        await settle()
        XCTAssertFalse(model.permissionRequestInFlight)
        XCTAssertNotNil(model.permissionError)
        model.permissionAction()
        XCTAssertEqual(callbacks.count, 2)
        XCTAssertNil(model.permissionError)
        callbacks[1](nil)
        await settle()
        await settle()
        XCTAssertFalse(model.permissionRequestInFlight)
    }

    func testDeniedQuietAndAuthorizedStatesStayHonestAndNeverRePrompt() async {
        for status in [UNAuthorizationStatus.denied, .provisional, .authorized] {
            var opened = 0
            let settings = readiness(status, alerts: .disabled, style: .none)
            let model = OnboardingModel(defaults: defaults(), preferences: .init(), readSettings: { $0(settings) },
                requestPermission: { _ in XCTFail("Existing authorization must open settings, not request again") },
                openSettings: { opened += 1 }, savePreferences: { _ in }, finish: {})
            model.refreshSettings()
            await settle()
            XCTAssertEqual(model.canSubmitNotifications, status != .denied)
            XCTAssertFalse(model.permissionDetail.contains("Banners enabled"))
            model.permissionAction()
            XCTAssertEqual(opened, 1)
            model.advance()
            model.advance()
            model.advance()
            XCTAssertTrue(model.isComplete, "Permission is optional even when denied")
        }
    }

    func testOlderSettingsReadCannotOverwriteNewerResult() async {
        var callbacks: [(NotificationReadiness) -> Void] = []
        let model = OnboardingModel(defaults: defaults(), preferences: .init(), readSettings: { callbacks.append($0) },
            requestPermission: { _ in }, openSettings: {}, savePreferences: { _ in }, finish: {})
        model.refreshSettings()
        model.refreshSettings()
        callbacks[1](readiness(.denied))
        callbacks[0](readiness(.authorized))
        await settle()
        XCTAssertEqual(model.readiness?.authorization, .denied)
        XCTAssertFalse(model.canSubmitNotifications)
    }

    func testReadySummaryCountsOnlyFreshValidatedChargingAndReconcilesDuplicates() {
        let model = OnboardingModel(defaults: defaults(), preferences: .init(), readSettings: { _ in },
            requestPermission: { _ in }, openSettings: {}, savePreferences: { _ in }, finish: {})
        let now = Date()
        func reading(_ id: String, state: Charging, age: TimeInterval = 0, percent: Int? = 60) -> Reading {
            Reading(id: id, name: "SIMULATED", symbol: "keyboard", percent: percent, state: state,
                sampled: now.addingTimeInterval(-age), evidence: "SIMULATED")
        }
        XCTAssertEqual(model.accessoryTitle, "Checking for your accessories…")
        model.updateAccessories([reading("fresh", state: .charging), reading("stale", state: .charging, age: 90),
            reading("unknown", state: .unknown), reading("invalid", state: .charging, percent: 101),
            reading("conflict", state: .charging), reading("conflict", state: .idle)], message: nil, now: now)
        XCTAssertEqual(model.accessoryCount, 5)
        XCTAssertEqual(model.chargingCount, 1)
        XCTAssertEqual(model.accessoryTitle, "1 accessory is charging")
        model.updateAccessories([], message: "SIMULATED failure", now: now)
        XCTAssertEqual(model.accessoryTitle, "Accessory information is unavailable")
        XCTAssertFalse(model.accessoryDetail.contains("SIMULATED"), "Raw diagnostic copy stays in controls")
        model.updateAccessories([], message: nil, now: now)
        XCTAssertEqual(model.accessoryTitle, "Ready for your first accessory")
        XCTAssertEqual(model.chargingCount, 0)
    }

    func testSetupChoicesSynchronizeTheExistingNativeControlsWithoutCallback() throws {
        let notifications = NotificationControls(target: NSApplication.shared, enable: #selector(NSApplication.terminate(_:)),
            test: #selector(NSApplication.terminate(_:)), alerts: .init(),
            onAlertsChange: { _ in XCTFail("Programmatic synchronization must not trigger a user action") }, readSettings: { _ in })
        notifications.synchronizePreferences(.init(started: false, soon: true, target: false, full: true))
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
        let toggles = descendants(notifications.view).compactMap { $0 as? NSButton }
        for kind in AlertKind.allCases {
            let button = try XCTUnwrap(toggles.first { $0.title == kind.title })
            XCTAssertEqual(button.state, kind == .soon || kind == .full ? .on : .off)
        }
    }

    func testClosingSetupRetainsTheUnfinishedStepWithoutCompletingOrRequestingPermission() throws {
        _ = NSApplication.shared
        let model = OnboardingModel(defaults: defaults(), preferences: .init(), readSettings: { _ in },
            requestPermission: { _ in XCTFail("Closing setup is not permission consent") }, openSettings: {},
            savePreferences: { _ in }, finish: { XCTFail("Closing setup is not completion") })
        let controller = OnboardingWindow(model: model, quit: {})
        let window = try XCTUnwrap(controller.window)
        model.advance()
        window.close()
        XCTAssertFalse(model.isComplete)
        XCTAssertEqual(model.step, .alerts)
        XCTAssertTrue(controller.window === window)
        XCTAssertFalse(window.isReleasedWhenClosed)
        XCTAssertTrue(window.styleMask.contains(.resizable))
        XCTAssertEqual(window.contentMinSize, NSSize(width: 720, height: 520))
    }
}
