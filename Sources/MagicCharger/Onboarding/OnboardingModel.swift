import AppKit
import Combine
import UserNotifications

enum OnboardingStep: Int, CaseIterable {
    case welcome, alerts, ready

    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .alerts: return "Your reminders"
        case .ready: return "Ready when you are"
        }
    }

    var detail: String {
        switch self {
        case .welcome: return "A quieter way to charge"
        case .alerts: return "Choose what matters"
        case .ready: return "Keep it in the background"
        }
    }
}

/// Owns setup state only. Hardware collection, notification delivery, and alert
/// deduplication remain in their existing services.
final class OnboardingModel: ObservableObject {
    static let completionKey = "onboarding.quietCurrent.completed.v1"

    @Published private(set) var step: OnboardingStep = .welcome
    @Published private(set) var preferences: NotificationPreferences
    @Published private(set) var readiness: NotificationReadiness?
    @Published private(set) var permissionRequestInFlight = false
    @Published private(set) var permissionError: String?
    @Published private(set) var hasObservation = false
    @Published private(set) var accessoryCount = 0
    @Published private(set) var chargingCount = 0
    @Published private(set) var collectionMessage: String?

    private let defaults: UserDefaults
    private let readSettings: (@escaping (NotificationReadiness) -> Void) -> Void
    private let requestPermission: (@escaping (String?) -> Void) -> Void
    private let openSettings: () -> Void
    private let savePreferences: (NotificationPreferences) -> Void
    private let finish: () -> Void
    private var settingsGeneration = 0

    init(defaults: UserDefaults, preferences: NotificationPreferences,
         readSettings: @escaping (@escaping (NotificationReadiness) -> Void) -> Void,
         requestPermission: @escaping (@escaping (String?) -> Void) -> Void,
         openSettings: @escaping () -> Void,
         savePreferences: @escaping (NotificationPreferences) -> Void,
         finish: @escaping () -> Void) {
        self.defaults = defaults
        self.preferences = preferences
        self.readSettings = readSettings
        self.requestPermission = requestPermission
        self.openSettings = openSettings
        self.savePreferences = savePreferences
        self.finish = finish
    }

    var isComplete: Bool { defaults.bool(forKey: Self.completionKey) }
    var enabledAlertCount: Int { AlertKind.allCases.filter { preferences.allows($0) }.count }
    var canSubmitNotifications: Bool { readiness?.canSubmit == true }

    var permissionTitle: String {
        guard let readiness = readiness else { return "Checking notification settings…" }
        if readiness.needsPermission { return "A small permission. A useful reminder." }
        if readiness.authorization == .denied { return "Notifications are blocked in macOS" }
        if readiness.canSubmit { return "Your notification settings" }
        return "Notification permission is unavailable"
    }

    var permissionDetail: String {
        guard let readiness = readiness else { return "You can continue while macOS checks. Permission is always your choice." }
        if readiness.needsPermission {
            return "Allow local notifications for your selected reminders. macOS will ask you to confirm. You can also decide later."
        }
        return readiness.summary
    }

    var accessoryTitle: String {
        if collectionMessage != nil { return "Accessory information is unavailable" }
        if !hasObservation { return "Checking for your accessories…" }
        if chargingCount > 0 { return chargingCount == 1 ? "1 accessory is charging" : "\(chargingCount) accessories are charging" }
        if accessoryCount > 0 { return accessoryCount == 1 ? "1 accessory detected" : "\(accessoryCount) accessories detected" }
        return "Ready for your first accessory"
    }

    var accessoryDetail: String {
        if collectionMessage != nil { return "Monitoring will keep trying. You can check Technical Details in controls." }
        if chargingCount > 0 { return "Look for its icon in the menu bar. Each charging accessory has its own item." }
        if accessoryCount > 0 { return "The menu bar stays clear until charging is verified. Plug in an accessory when you’re ready." }
        return "Connect a supported Magic Keyboard or Magic Mouse. A menu-bar item appears when charging is verified."
    }

    var reminderTitle: String {
        if enabledAlertCount == 0 { return "Automatic reminders are off" }
        return canSubmitNotifications ? "\(enabledAlertCount) reminder types selected" : "Reminders are waiting for permission"
    }

    var reminderDetail: String {
        if enabledAlertCount == 0 { return "Monitoring continues. You can turn reminders on in controls at any time." }
        if !canSubmitNotifications { return "Allow notifications in controls whenever you’re ready. Monitoring works without them." }
        return "\(readiness?.summary ?? "") Focus and screen sharing can affect when alerts appear."
    }

    func advance() {
        switch step {
        case .welcome: step = .alerts
        case .alerts: step = .ready
        case .ready:
            defaults.set(true, forKey: Self.completionKey)
            finish()
        }
    }

    func back() {
        if let previous = OnboardingStep(rawValue: step.rawValue - 1) { step = previous }
    }

    func restartWalkthrough() {
        guard !permissionRequestInFlight else { return }
        step = .welcome
    }

    func revisit(_ destination: OnboardingStep) {
        // Progress rail allows revisiting completed steps, never bypassing setup.
        if destination.rawValue < step.rawValue { step = destination }
    }

    func setAlert(_ kind: AlertKind, enabled: Bool) {
        var updated = preferences
        switch kind {
        case .started: updated.started = enabled
        case .soon: updated.soon = enabled
        case .target: updated.target = enabled
        case .full: updated.full = enabled
        }
        guard updated != preferences else { return }
        preferences = updated
        savePreferences(updated)
    }

    func synchronizePreferences(_ preferences: NotificationPreferences) {
        if self.preferences != preferences { self.preferences = preferences }
    }

    func updateAccessories(_ readings: [Reading], message: String?, now: Date = Date()) {
        let readings = reconciled(readings)
        hasObservation = true
        accessoryCount = readings.count
        chargingCount = readings.filter { reading in
            reading.state == .charging && reading.fresh(at: now) &&
            reading.percent.map { (0...100).contains($0) } == true
        }.count
        collectionMessage = message
    }

    func refreshSettings() {
        settingsGeneration += 1
        let generation = settingsGeneration
        readSettings { [weak self] readiness in
            DispatchQueue.main.async {
                guard let self = self, self.settingsGeneration == generation else { return }
                self.readiness = readiness
            }
        }
    }

    func permissionAction() {
        guard let readiness = readiness, !permissionRequestInFlight else { return }
        permissionError = nil
        guard readiness.needsPermission else { openSettings(); return }
        permissionRequestInFlight = true
        requestPermission { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.permissionRequestInFlight = false
                self.permissionError = error
                self.refreshSettings()
            }
        }
    }
}
