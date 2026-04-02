import AppKit
import CoreGraphics
import Carbon
import ServiceManagement

// MARK: - Gamma Controller

final class GammaController {
    static let shared = GammaController()

    // Blue reduction: 65%, Green: 15%, Red: 5% at max warmth
    private let redReduction: CGGammaValue = 0.0
    private let greenReduction: CGGammaValue = 0.45
    private let blueReduction: CGGammaValue = 0.80

    // Brightness cap reduces maximum output to 50% at max
    private let maxBrightnessReduction: CGGammaValue = 0.50

    // Contrast reduction raises the black point by up to 20% at max
    private let maxContrastReduction: CGGammaValue = 0.20

    private var originalTables: [CGDirectDisplayID: (red: [CGGammaValue], green: [CGGammaValue], blue: [CGGammaValue])] = [:]
    private let tableSize: UInt32 = 256

    private(set) var warmth: Double = 0.0
    private(set) var brightnessCap: Double = 0.0
    private(set) var contrastReduction: Double = 0.0

    var isActive: Bool { warmth > 0.01 || brightnessCap > 0.01 || contrastReduction > 0.01 }

    private init() {}

    func captureOriginalGamma() {
        let displays = activeDisplays()
        for display in displays {
            captureGamma(for: display)
        }
    }

    private func captureGamma(for display: CGDirectDisplayID) {
        var redTable = [CGGammaValue](repeating: 0, count: Int(tableSize))
        var greenTable = [CGGammaValue](repeating: 0, count: Int(tableSize))
        var blueTable = [CGGammaValue](repeating: 0, count: Int(tableSize))
        var sampleCount: UInt32 = 0

        let err = CGGetDisplayTransferByTable(display, tableSize, &redTable, &greenTable, &blueTable, &sampleCount)
        if err == .success {
            originalTables[display] = (red: redTable, green: greenTable, blue: blueTable)
        }
    }

    func applyFilter(warmth: Double, brightnessCap: Double, contrastReduction: Double) {
        self.warmth = max(0.0, min(1.0, warmth))
        self.brightnessCap = max(0.0, min(1.0, brightnessCap))
        self.contrastReduction = max(0.0, min(1.0, contrastReduction))
        let w = CGGammaValue(self.warmth)
        let b = CGGammaValue(self.brightnessCap)
        let c = CGGammaValue(self.contrastReduction)
        let cap = 1.0 - maxBrightnessReduction * b
        let floor = maxContrastReduction * c
        let displays = activeDisplays()

        for display in displays {
            if originalTables[display] == nil {
                captureGamma(for: display)
            }
            guard let original = originalTables[display] else { continue }

            var filteredRed = [CGGammaValue](repeating: 0, count: Int(tableSize))
            var filteredGreen = [CGGammaValue](repeating: 0, count: Int(tableSize))
            var filteredBlue = [CGGammaValue](repeating: 0, count: Int(tableSize))

            for i in 0..<Int(tableSize) {
                let r = original.red[i] * (1.0 - redReduction * w)
                let g = original.green[i] * (1.0 - greenReduction * w)
                let bl = original.blue[i] * (1.0 - blueReduction * w)

                // Remap from [0, 1] to [floor, cap]
                filteredRed[i] = floor + r * (cap - floor)
                filteredGreen[i] = floor + g * (cap - floor)
                filteredBlue[i] = floor + bl * (cap - floor)
            }

            CGSetDisplayTransferByTable(display, tableSize, filteredRed, filteredGreen, filteredBlue)
        }
    }

    func restoreAll() {
        CGDisplayRestoreColorSyncSettings()
    }

    func refreshDisplayList() {
        let current = activeDisplays()
        let stale = originalTables.keys.filter { !current.contains($0) }
        for id in stale { originalTables.removeValue(forKey: id) }
        for display in current where originalTables[display] == nil {
            captureGamma(for: display)
        }
        if isActive {
            applyFilter(warmth: warmth, brightnessCap: brightnessCap, contrastReduction: contrastReduction)
        }
    }

    private func activeDisplays() -> [CGDirectDisplayID] {
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        CGGetOnlineDisplayList(16, &displayIDs, &count)
        return Array(displayIDs.prefix(Int(count)))
    }
}

// MARK: - Filter Control View (embedded in menu)

final class FilterControlView: NSView {
    private let warmthSlider: NSSlider
    private let brightnessSlider: NSSlider
    private let contrastSlider: NSSlider
    private let titleLabel: NSTextField
    private let warmthLabel: NSTextField
    private let brightnessLabel: NSTextField
    private let contrastLabel: NSTextField

    var onFilterChanged: ((Double, Double, Double) -> Void)?

    private let viewWidth: CGFloat = 290
    private let viewHeight: CGFloat = 185

    override var intrinsicContentSize: NSSize {
        NSSize(width: viewWidth, height: viewHeight)
    }

    init() {
        titleLabel = NSTextField(labelWithString: "NightCoder")
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.alignment = .center

        warmthLabel = NSTextField(labelWithString: "Warmth")
        warmthLabel.font = .systemFont(ofSize: 13, weight: .medium)
        warmthLabel.textColor = .secondaryLabelColor
        warmthLabel.alignment = .center

        brightnessLabel = NSTextField(labelWithString: "Brightness")
        brightnessLabel.font = .systemFont(ofSize: 13, weight: .medium)
        brightnessLabel.textColor = .secondaryLabelColor
        brightnessLabel.alignment = .center

        contrastLabel = NSTextField(labelWithString: "Contrast")
        contrastLabel.font = .systemFont(ofSize: 13, weight: .medium)
        contrastLabel.textColor = .secondaryLabelColor
        contrastLabel.alignment = .center

        warmthSlider = NSSlider(value: 1.0, minValue: 0.0, maxValue: 1.0, target: nil, action: nil)
        warmthSlider.isVertical = true
        warmthSlider.controlSize = .regular

        brightnessSlider = NSSlider(value: 1.0, minValue: 0.0, maxValue: 1.0, target: nil, action: nil)
        brightnessSlider.isVertical = true
        brightnessSlider.controlSize = .regular

        contrastSlider = NSSlider(value: 1.0, minValue: 0.0, maxValue: 1.0, target: nil, action: nil)
        contrastSlider.isVertical = true
        contrastSlider.controlSize = .regular

        super.init(frame: NSRect(x: 0, y: 0, width: viewWidth, height: viewHeight))

        warmthSlider.target = self
        warmthSlider.action = #selector(sliderChanged)
        warmthSlider.isContinuous = true

        brightnessSlider.target = self
        brightnessSlider.action = #selector(sliderChanged)
        brightnessSlider.isContinuous = true

        contrastSlider.target = self
        contrastSlider.action = #selector(sliderChanged)
        contrastSlider.isContinuous = true

        addSubview(titleLabel)
        addSubview(warmthLabel)
        addSubview(brightnessLabel)
        addSubview(contrastLabel)
        addSubview(warmthSlider)
        addSubview(brightnessSlider)
        addSubview(contrastSlider)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        let w = bounds.width
        let padding: CGFloat = 16

        titleLabel.frame = NSRect(x: padding, y: bounds.height - 28, width: w - padding * 2, height: 18)

        let sliderHeight: CGFloat = 90
        let sliderWidth: CGFloat = 26
        let sliderSpacing: CGFloat = 52
        let totalWidth = sliderWidth * 3 + sliderSpacing * 2
        let startX = (w - totalWidth) / 2

        let sliderY: CGFloat = 28
        warmthSlider.frame = NSRect(x: startX, y: sliderY, width: sliderWidth, height: sliderHeight)
        brightnessSlider.frame = NSRect(x: startX + sliderWidth + sliderSpacing, y: sliderY, width: sliderWidth, height: sliderHeight)
        contrastSlider.frame = NSRect(x: startX + (sliderWidth + sliderSpacing) * 2, y: sliderY, width: sliderWidth, height: sliderHeight)

        let labelWidth: CGFloat = 70
        warmthLabel.frame = NSRect(x: startX + sliderWidth / 2 - labelWidth / 2, y: 8, width: labelWidth, height: 14)
        brightnessLabel.frame = NSRect(x: startX + sliderWidth + sliderSpacing + sliderWidth / 2 - labelWidth / 2, y: 8, width: labelWidth, height: 14)
        contrastLabel.frame = NSRect(x: startX + (sliderWidth + sliderSpacing) * 2 + sliderWidth / 2 - labelWidth / 2, y: 8, width: labelWidth, height: 14)
    }

    func setWarmthValue(_ value: Double) {
        warmthSlider.doubleValue = value
    }

    func setBrightnessValue(_ value: Double) {
        brightnessSlider.doubleValue = value
    }

    func setContrastValue(_ value: Double) {
        contrastSlider.doubleValue = value
    }

    @objc private func sliderChanged() {
        let warmth = 1.0 - warmthSlider.doubleValue
        let brightness = 1.0 - brightnessSlider.doubleValue
        let contrast = 1.0 - contrastSlider.doubleValue
        onFilterChanged?(warmth, brightness, contrast)
    }
}

// MARK: - Status Bar Controller

final class ToggleButtonView: NSView {
    let button: NSButton
    private let hintLabel: NSTextField

    var onToggle: (() -> Void)?

    override var intrinsicContentSize: NSSize {
        NSSize(width: 260, height: 36)
    }

    init() {
        button = NSButton(title: "Disable", target: nil, action: nil)
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.font = .systemFont(ofSize: 13, weight: .medium)

        hintLabel = NSTextField(labelWithString: "Hotkey: \u{2303}\u{2325}N")
        hintLabel.font = .systemFont(ofSize: 13)
        hintLabel.textColor = .labelColor
        hintLabel.alignment = .center

        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 36))

        button.target = self
        button.action = #selector(clicked)

        addSubview(button)
        addSubview(hintLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        let padding: CGFloat = 16
        let btnWidth: CGFloat = 80
        let hintWidth: CGFloat = 90
        let spacing: CGFloat = 8

        button.frame = NSRect(x: padding, y: 6, width: btnWidth, height: 24)
        hintLabel.frame = NSRect(x: padding + btnWidth + spacing, y: 9, width: hintWidth, height: 18)
    }

    @objc private func clicked() {
        onToggle?()
    }
}

final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let menu: NSMenu
    private let filterView: FilterControlView
    private let toggleView: ToggleButtonView
    private let loginCheckbox: NSButton
    private var lastThrottleTime: TimeInterval = 0

    var onToggle: (() -> Void)?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        menu = NSMenu()
        filterView = FilterControlView()
        toggleView = ToggleButtonView()
        loginCheckbox = NSButton(checkboxWithTitle: "Launch at Login", target: nil, action: nil)

        super.init()

        setupMenu()
        setupIcon(active: false)

        filterView.onFilterChanged = { [weak self] warmth, brightness, contrast in
            self?.throttledApply(warmth: warmth, brightness: brightness, contrast: contrast)
        }

        toggleView.onToggle = { [weak self] in
            self?.onToggle?()
        }
    }

    private func setupMenu() {
        let controlItem = NSMenuItem()
        controlItem.view = filterView
        menu.addItem(controlItem)
        menu.addItem(.separator())

        let toggleMenuItem = NSMenuItem()
        toggleMenuItem.view = toggleView
        menu.addItem(toggleMenuItem)

        menu.addItem(.separator())

        loginCheckbox.target = self
        loginCheckbox.action = #selector(toggleLoginItem)
        loginCheckbox.state = SMAppService.mainApp.status == .enabled ? .on : .off
        loginCheckbox.font = .systemFont(ofSize: 13)

        let loginView = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 30))
        loginCheckbox.frame = NSRect(x: 16, y: 3, width: 200, height: 24)
        loginView.addSubview(loginCheckbox)

        let loginMenuItem = NSMenuItem()
        loginMenuItem.view = loginView
        menu.addItem(loginMenuItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit NightCoder", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func toggleLoginItem() {
        if loginCheckbox.state == .on {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }

    func setupIcon(active: Bool) {
        if let button = statusItem.button {
            let symbolName = active ? "moon.fill" : "moon"
            if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "NightCoder") {
                let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
                button.image = image.withSymbolConfiguration(config)
            }
            button.toolTip = active ? "NightCoder (Active)" : "NightCoder"
        }
    }

    func setWarmthValue(_ value: Double) {
        filterView.setWarmthValue(value)
    }

    func setBrightnessValue(_ value: Double) {
        filterView.setBrightnessValue(value)
    }

    func setContrastValue(_ value: Double) {
        filterView.setContrastValue(value)
    }

    func updateToggleItem(active: Bool) {
        toggleView.button.title = active ? "Disable" : "Enable"
    }

    private func throttledApply(warmth: Double, brightness: Double, contrast: Double) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastThrottleTime > 0.016 else { return }
        lastThrottleTime = now

        GammaController.shared.applyFilter(warmth: warmth, brightnessCap: brightness, contrastReduction: contrast)
        let active = GammaController.shared.isActive
        setupIcon(active: active)
        updateToggleItem(active: active)

        UserDefaults.standard.set(warmth, forKey: "filterWarmth")
        UserDefaults.standard.set(brightness, forKey: "filterBrightness")
        UserDefaults.standard.set(contrast, forKey: "filterContrast")
    }
}

// MARK: - Global Hotkey (Carbon)

final class HotkeyManager {
    private var hotkeyRef: EventHotKeyRef?
    var onToggle: (() -> Void)?

    func register() {
        let hotKeyID = EventHotKeyID(signature: OSType(0x4E434F44), id: 1)
        let keyCode: UInt32 = 45 // 'N' key
        let modifiers: UInt32 = UInt32(optionKey | controlKey)

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                       eventKind: UInt32(kEventHotKeyPressed))

        let handlerRef = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { (_, event, userData) -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.onToggle?()
            return noErr
        }, 1, &eventType, handlerRef, nil)

        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotkeyRef)
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController!
    private var hotkeyManager: HotkeyManager!
    private var lastWarmth: Double = 1.0
    private var lastBrightness: Double = 0.5
    private var lastContrast: Double = 0.0

    func applicationDidFinishLaunching(_ notification: Notification) {
        installSignalHandlers()

        GammaController.shared.captureOriginalGamma()

        statusBar = StatusBarController()
        hotkeyManager = HotkeyManager()

        // Restore saved state
        let savedWarmth = UserDefaults.standard.double(forKey: "filterWarmth")
        let savedBrightness = UserDefaults.standard.double(forKey: "filterBrightness")
        let savedContrast = UserDefaults.standard.double(forKey: "filterContrast")
        if savedWarmth > 0.01 || savedBrightness > 0.01 || savedContrast > 0.01 {
            lastWarmth = savedWarmth
            lastBrightness = savedBrightness
            lastContrast = savedContrast
            GammaController.shared.applyFilter(warmth: savedWarmth, brightnessCap: savedBrightness, contrastReduction: savedContrast)
            statusBar.setWarmthValue(1.0 - savedWarmth)
            statusBar.setBrightnessValue(1.0 - savedBrightness)
            statusBar.setContrastValue(1.0 - savedContrast)
            statusBar.setupIcon(active: true)
            statusBar.updateToggleItem(active: true)
        }

        // Wire toggle for both hotkey and disable button
        hotkeyManager.onToggle = { [weak self] in self?.toggleFilter() }
        statusBar.onToggle = { [weak self] in self?.toggleFilter() }
        hotkeyManager.register()

        CGDisplayRegisterReconfigurationCallback({ _, flags, _ in
            if flags.contains(.addFlag) || flags.contains(.removeFlag) {
                DispatchQueue.main.async {
                    GammaController.shared.refreshDisplayList()
                }
            }
        }, nil)
    }

    private func toggleFilter() {
        let gamma = GammaController.shared
        if gamma.isActive {
            lastWarmth = gamma.warmth
            lastBrightness = gamma.brightnessCap
            lastContrast = gamma.contrastReduction
            gamma.applyFilter(warmth: 0, brightnessCap: 0, contrastReduction: 0)
            statusBar.setWarmthValue(1.0)
            statusBar.setBrightnessValue(1.0)
            statusBar.setContrastValue(1.0)
            statusBar.setupIcon(active: false)
            statusBar.updateToggleItem(active: false)
            UserDefaults.standard.set(0.0, forKey: "filterWarmth")
            UserDefaults.standard.set(0.0, forKey: "filterBrightness")
            UserDefaults.standard.set(0.0, forKey: "filterContrast")
        } else {
            gamma.applyFilter(warmth: lastWarmth, brightnessCap: lastBrightness, contrastReduction: lastContrast)
            statusBar.setWarmthValue(1.0 - lastWarmth)
            statusBar.setBrightnessValue(1.0 - lastBrightness)
            statusBar.setContrastValue(1.0 - lastContrast)
            statusBar.setupIcon(active: true)
            statusBar.updateToggleItem(active: true)
            UserDefaults.standard.set(lastWarmth, forKey: "filterWarmth")
            UserDefaults.standard.set(lastBrightness, forKey: "filterBrightness")
            UserDefaults.standard.set(lastContrast, forKey: "filterContrast")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        GammaController.shared.restoreAll()
    }

    private func installSignalHandlers() {
        let signals: [Int32] = [SIGTERM, SIGINT, SIGABRT, SIGSEGV, SIGBUS]
        for sig in signals {
            signal(sig) { _ in
                CGDisplayRestoreColorSyncSettings()
                _exit(1)
            }
        }
        atexit {
            CGDisplayRestoreColorSyncSettings()
        }
    }
}

// MARK: - Entry Point

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
