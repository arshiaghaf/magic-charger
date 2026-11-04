import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: OnboardingModel
    let quit: () -> Void
    @AccessibilityFocusState private var headingFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            progressRail
                .frame(width: 216)
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        page
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 36)
                    .padding(.top, 30)
                    .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(model.step)
                footer
            }
            .frame(maxWidth: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .tint(.accentColor)
        .onAppear { model.refreshSettings() }
        .onChange(of: model.step) { _, _ in headingFocused = true }
    }

    private var progressRail: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(LinearGradient(colors: [Color.teal, Color.teal.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)
                Text("Magic Charger")
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.bottom, 52)

            Text("SETUP")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.8)
                .foregroundStyle(.secondary)
                .padding(.bottom, 20)

            ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                Button { model.revisit(step) } label: {
                    HStack(alignment: .top, spacing: 11) {
                        ZStack {
                            Circle()
                                .fill(step == model.step ? Color.accentColor : Color.secondary.opacity(0.09))
                            if step.rawValue < model.step.rawValue {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("\(step.rawValue + 1)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(step == model.step ? Color.white : Color.secondary)
                            }
                        }
                        .frame(width: 23, height: 23)
                        .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(step.title)
                                .font(.system(size: 12, weight: step == model.step ? .semibold : .medium))
                                .foregroundStyle(step.rawValue <= model.step.rawValue ? .primary : .secondary)
                            if step == model.step {
                                Text(step.detail)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.top, 3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 24)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(step.rawValue > model.step.rawValue)
                .accessibilityLabel("Step \(step.rawValue + 1), \(step.title)")
                .accessibilityValue(step == model.step ? "Current step" : (step.rawValue < model.step.rawValue ? "Completed" : "Upcoming"))
            }
            Spacer(minLength: 30)
            Label {
                Text("No account. No cloud.\nJust your Mac.")
                    .font(.system(size: 11))
                    .lineSpacing(4)
            } icon: {
                Image(systemName: "lock.shield")
                    .font(.system(size: 16, weight: .light))
            }
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 22)
        .padding(.top, 32)
        .padding(.bottom, 28)
        .frame(maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .overlay(alignment: .trailing) { Divider() }
    }

    @ViewBuilder private var page: some View {
        switch model.step {
        case .welcome: welcome
        case .alerts: alerts
        case .ready: ready
        }
    }

    private func heading(_ eyebrow: String, _ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(eyebrow)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.8)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .tracking(-0.8)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($headingFocused)
            Text(detail)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .contain)
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 24) {
            heading("WELCOME", "A little attention,\nright on time.", "Charging reminders for your Magic Keyboard and Magic Mouse, quietly at home on your Mac.")

            AccessoryIllustration()
                .frame(maxWidth: .infinity)
                .frame(height: 145)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 19) {
                feature("menubar.rectangle", title: "There when you’re charging", detail: "An icon and battery level appear only for verified charging. They disappear when charging ends.")
                feature("bell.badge", title: "A nudge at the right moment", detail: "Choose reminders for charging started, 78%, 80%, and 100%. You stay in control of unplugging.")
                feature("hand.raised", title: "Only what’s needed", detail: "Battery information stays on this Mac. Your keystrokes and mouse input are never captured.")
            }
        }
    }

    private func feature(_ symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(Color.accentColor)
                .frame(width: 25, height: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var alerts: some View {
        VStack(alignment: .leading, spacing: 20) {
            heading("MAKE IT YOURS", "Choose your\nreminders.", "Keep the moments you care about. You can change every choice later in controls.")
            VStack(spacing: 0) {
                alertRow(.started, symbol: "bolt", title: "Charging started", detail: "When a new charging session is observed", badge: nil)
                Divider().padding(.leading, 50)
                alertRow(.soon, symbol: "bell", title: "Unplug soon", detail: "An early heads-up before your target", badge: "78%")
                Divider().padding(.leading, 50)
                alertRow(.target, symbol: "bell.badge", title: "Unplug reminder", detail: "A reminder to unplug when you choose", badge: "80%")
                Divider().padding(.leading, 50)
                alertRow(.full, symbol: "battery.100percent", title: "Fully charged", detail: "When a supported full reading is observed", badge: "100%")
            }
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.05)) }
            permissionCard
            Text("Reminders don’t stop charging. Missing or uncertain readings stay quiet.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func alertRow(_ kind: AlertKind, symbol: String, title: String, detail: String, badge: String?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(title).font(.system(size: 12, weight: .semibold))
                    if let badge = badge {
                        Text(badge)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 4))
                    }
                }
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // The switch already exposes this title, percentage, and detail.
            // Avoid reading the same row a second time in VoiceOver.
            .accessibilityHidden(true)
            Spacer(minLength: 4)
            Toggle(title, isOn: Binding(get: { model.preferences.allows(kind) }, set: { model.setAlert(kind, enabled: $0) }))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .accessibilityLabel(kind.title)
                .accessibilityHint(detail)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: model.canSubmitNotifications ? "checkmark.shield" : "bell")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.permissionTitle).font(.system(size: 12, weight: .semibold))
                    Text(model.permissionDetail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let error = model.permissionError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 11))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Permission request failed. \(error)")
            }
            HStack(spacing: 9) {
                Button(model.permissionRequestInFlight ? "Waiting for macOS…" : (model.readiness?.needsPermission == true ? "Allow Notifications…" : "Notification Settings…")) {
                    model.permissionAction()
                }
                .disabled(model.readiness == nil || model.permissionRequestInFlight)
                .controlSize(.small)
                .accessibilityHint(model.readiness?.needsPermission == true ? "Opens the macOS notification permission prompt. Optional." : "Opens System Settings. Changes stay under your control.")
                if model.readiness?.needsPermission == true {
                    Text("Optional")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, 29)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
    }

    private var ready: some View {
        VStack(alignment: .leading, spacing: 24) {
            heading("READY WHEN YOU ARE", "Ready for your\nnext charge.", "Magic Charger watches for supported accessories. You can close the window and get back to what you were doing.")

            VStack(alignment: .leading, spacing: 22) {
                feature(model.chargingCount > 0 ? "bolt.circle" : "keyboard", title: model.accessoryTitle, detail: model.accessoryDetail)
                Divider()
                feature(model.canSubmitNotifications && model.enabledAlertCount > 0 ? "bell.badge" : "bell.slash", title: model.reminderTitle, detail: model.reminderDetail)
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 16) {
                feature("magnifyingglass", title: "Need controls again?", detail: "Reopen Magic Charger from Spotlight or Finder. There’s no permanent Dock icon, and the menu bar stays clear when nothing is charging.")
                feature("power", title: "Your Mac, your choice", detail: "Closing this window keeps monitoring. Quit is always available in controls. Launch at Login stays off unless you enable it.")
            }
            Text("Detection depends on supported accessory and macOS evidence. A reminder is an invitation to unplug; Magic Charger cannot stop charging.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                Button("Quit", action: quit)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .keyboardShortcut("q", modifiers: .command)
                    .accessibilityLabel("Quit Magic Charger")
                Spacer()
                if model.step != .welcome {
                    Button("Back") { model.back() }
                        .keyboardShortcut(.leftArrow, modifiers: .command)
                }
                Button(model.step == .ready ? "Open Controls" : (model.step == .welcome ? "Get Started" : "Continue")) {
                    model.advance()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(model.permissionRequestInFlight)
            }
            .controlSize(.large)
            .padding(.horizontal, 30)
            .padding(.vertical, 19)
        }
    }
}

/// Decorative runtime SF Symbols: no sample device, percentage, or charging
/// observation is fed into the live app for illustration.
private struct AccessoryIllustration: View {
    var body: some View {
        ZStack {
            Ellipse()
                .fill(RadialGradient(colors: [Color.teal.opacity(0.11), .clear], center: .center, startRadius: 10, endRadius: 170))
                .frame(width: 350, height: 145)
            HStack(alignment: .center, spacing: 19) {
                Image(systemName: "keyboard")
                    .font(.system(size: 65, weight: .ultraLight))
                    .rotationEffect(.degrees(-6))
                Image(systemName: "magicmouse")
                    .font(.system(size: 68, weight: .ultraLight))
                    .rotationEffect(.degrees(9))
            }
            .foregroundStyle(.primary.opacity(0.72))
            Image(systemName: "bolt.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.teal)
                .frame(width: 34, height: 34)
                .background(.background, in: Circle())
                .overlay { Circle().strokeBorder(Color.teal.opacity(0.16)) }
                .offset(x: 116, y: 38)
        }
    }
}
