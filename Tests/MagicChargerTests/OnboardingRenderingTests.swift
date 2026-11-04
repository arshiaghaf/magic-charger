import XCTest
import AppKit
import SwiftUI
import UserNotifications
@testable import MagicCharger

/// Optional direct view renders, with isolated settings and no hardware access.
/// These do not launch the app, request permission, or capture the user's screen.
@MainActor
final class OnboardingRenderingTests: XCTestCase {
    func testRenderComparisonArtifacts() async throws {
        guard let directory = ProcessInfo.processInfo.environment["MAGIC_CHARGER_RENDER_CONCEPT"] else {
            throw XCTSkip("Set MAGIC_CHARGER_RENDER_CONCEPT to export labeled native-view comparison artifacts")
        }
        _ = NSApplication.shared
        let destination = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let suite = "MagicChargerTests.Render.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let cases: [(String, OnboardingStep, UNAuthorizationStatus, String, NSSize)] = [
            ("01-welcome-light", .welcome, .notDetermined, NSAppearance.Name.aqua.rawValue, NSSize(width: 840, height: 670)),
            ("02-reminders-light", .alerts, .notDetermined, NSAppearance.Name.aqua.rawValue, NSSize(width: 840, height: 670)),
            ("03-ready-light", .ready, .notDetermined, NSAppearance.Name.aqua.rawValue, NSSize(width: 840, height: 670)),
            ("04-reminders-dark", .alerts, .authorized, NSAppearance.Name.darkAqua.rawValue, NSSize(width: 840, height: 670)),
            ("05-permission-denied", .alerts, .denied, NSAppearance.Name.aqua.rawValue, NSSize(width: 840, height: 670)),
            ("06-compact", .alerts, .notDetermined, NSAppearance.Name.aqua.rawValue, NSSize(width: 720, height: 520))
        ]
        for (name, step, authorization, appearance, size) in cases {
            let model = OnboardingModel(defaults: defaults, preferences: .init(), readSettings: { callback in
                callback(NotificationReadiness(authorization: authorization, alerts: .enabled, style: .banner,
                    notificationCenter: .enabled, sound: .enabled, scheduledDelivery: .disabled))
            }, requestPermission: { _ in XCTFail("Render must never request permission") }, openSettings: {},
                savePreferences: { _ in }, finish: {})
            for _ in 0..<step.rawValue { model.advance() }
            model.updateAccessories([], message: nil)
            model.refreshSettings()
            await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
            let view = NSHostingView(rootView: OnboardingView(model: model, quit: {}).environment(\.controlActiveState, .active))
            view.appearance = NSAppearance(named: NSAppearance.Name(rawValue: appearance))
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = view
            view.frame = NSRect(origin: .zero, size: size)
            view.layoutSubtreeIfNeeded()
            view.displayIfNeeded()
            // AppKit/SwiftUI commit their hosted layer tree on the next run-loop turn.
            await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
            view.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            XCTAssertGreaterThan(png.count, 10_000, "A view artifact must contain rendered content")
            try png.write(to: destination.appendingPathComponent(name + ".png"))
            window.close()
        }
    }
}
