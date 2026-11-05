import Foundation

/// The tour stores only a completion version, independently of notification choices.
struct OnboardingState {
    static let currentVersion = 1
    static let completionKey = "onboarding.completedVersion"
    private let defaults: UserDefaults

    init(defaults: UserDefaults, hasExistingInstallation: Bool) {
        self.defaults = defaults
        // Existing installations already know the app. An update should not
        // interrupt them with a new welcome window or erase their preferences.
        if defaults.object(forKey: Self.completionKey) == nil {
            defaults.set(hasExistingInstallation ? Self.currentVersion : 0, forKey: Self.completionKey)
        }
    }

    var isComplete: Bool { defaults.integer(forKey: Self.completionKey) >= Self.currentVersion }

    func shouldPresentAutomatically(launchedAtLogin: Bool) -> Bool {
        !launchedAtLogin && !isComplete
    }

    func finish() { defaults.set(max(Self.currentVersion, defaults.integer(forKey: Self.completionKey)), forKey: Self.completionKey) }
}
