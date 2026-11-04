import AppKit

/// Presentation never upgrades a missing, out-of-range or stale observation.
/// This value is shared by the visible level and its accessibility description.
struct AccessoryCardPresentation {
    let status: String
    let percentage: String
    let percentageDescription: String
    let fraction: CGFloat?
    let isCharging: Bool

    init(_ reading: Reading, now: Date = Date()) {
        let fresh = reading.fresh(at: now)
        let validPercent = fresh ? reading.percent.flatMap { (0...100).contains($0) ? $0 : nil } : nil
        isCharging = fresh && reading.state == .charging && validPercent != nil
        if !fresh || (reading.state == .charging && validPercent == nil) { status = "Charging state unknown" }
        else {
            switch reading.state {
            case .charging: status = "Charging"
            case .idle: status = "Not charging"
            case .unknown: status = reading.fullChargeEvidence && validPercent == 100
                ? "100% reported · charging state unknown" : "Charging state unknown"
            }
        }
        percentage = validPercent.map { "\($0)%" } ?? "—"
        percentageDescription = validPercent.map { "\($0) percent" } ?? "Battery level unknown"
        fraction = validPercent.map { CGFloat($0) / 100 }
    }
}

/// A decorative level track. The percentage text is the sole accessible value.
/// Uses semantic colors and redraws only on change; no animation or timer.
final class AccessoryBatteryLevelView: NSView {
    private var fraction: CGFloat?
    private var isCharging = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(false)
        setAccessibilityHidden(true)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(fraction: CGFloat?, isCharging: Bool) {
        guard self.fraction != fraction || self.isCharging != isCharging else { return }
        self.fraction = fraction; self.isCharging = isCharging
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let radius = bounds.height / 2
        NSColor.quaternaryLabelColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).fill()
        guard let fraction = fraction, fraction > 0 else { return }
        let fill = NSRect(x: bounds.minX, y: bounds.minY, width: bounds.width * fraction, height: bounds.height)
        (isCharging ? NSColor.systemGreen : NSColor.tertiaryLabelColor).setFill()
        NSBezierPath(roundedRect: fill, xRadius: radius, yRadius: radius).fill()
    }
}
