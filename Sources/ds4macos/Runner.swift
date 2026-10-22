#if os(macOS)
import Foundation
import DualSenseCore
import DS4Mac

/// Wires DeviceManager -> TouchGestureEngine -> MappingEngine -> EventInjector / OutputScheduler.
/// Everything runs on the main run loop.
final class Runner {
    let profile: Profile
    let mode: ProfileMode
    private let manager: DeviceManager
    private let injector = EventInjector()
    private let engine: MappingEngine
    private var gestures: TouchGestureEngine
    private var passThrough = false
    private var reportsSinceStatus = 0
    private var lastStatus = ProcessInfo.processInfo.systemUptime

    init(profile: Profile) {
        self.profile = profile
        self.mode = profile.mode
        manager = DeviceManager(seize: profile.mode != .augment, reassert: profile.mode == .augment)
        engine = MappingEngine(profile: profile)
        gestures = Runner.makeGestures(profile)
    }

    private static func makeGestures(_ profile: Profile) -> TouchGestureEngine {
        return TouchGestureEngine(config: TouchGestureConfig(zones: profile.touchpad.layout))
    }

    /// Starts device access. The Bluetooth enable sequence runs inside `DeviceManager` before input flows.
    func start() {
        manager.onState = { [weak self] state in self?.handle(state) }
        manager.onConnect = { [weak self] info in self?.connected(info) }
        manager.onDisconnect = { [weak self] in
            self?.releaseEverything()
            print("controller disconnected; all keys released")
        }
        manager.onOpenError = { name, result in
            printErr("cannot open \(name): 0x\(String(UInt32(bitPattern: result), radix: 16))")
        }
        manager.start()
        applyInitialFeedback()
        every(5) { [weak self] in self?.printStatus() }
        print("running '\(profile.name)' in \(mode.rawValue) mode; p toggles pass-through, Ctrl-C quits")
    }

    /// Releases everything held. Used on disconnect, pass-through and every exit path.
    func releaseEverything() {
        for action in engine.releaseAll() { injector.perform(action) }
        injector.releaseAll()
        gestures = Runner.makeGestures(profile)
    }

    /// Releases everything, stops the device manager. Called before the process exits.
    func shutdown() {
        releaseEverything()
        manager.stop()
        releaseEverything()
    }

    /// Switches pass-through on or off.
    func togglePassThrough() {
        if passThrough {
            passThrough = false
            manager.reopen(seize: mode != .augment)
            manager.scheduler.setReassert(mode == .augment)
            applyInitialFeedback()
            print("pass-through off: back in \(mode.rawValue) mode")
        } else {
            passThrough = true
            releaseEverything()
            manager.scheduler.setReassert(false)
            manager.reopen(seize: false)
            print("pass-through on: keys released, device not seized, nothing injected")
        }
    }

    private func connected(_ info: ConnectionInfo) {
        let fw = info.updateVersion.map { String($0, radix: 16) } ?? "unknown"
        print("connected: \(info.name) [\(info.transport)] firmware 0x\(fw)")
        releaseEverything()
        if !passThrough { applyInitialFeedback() }
    }

    private func applyInitialFeedback() {
        apply(engine.initialFeedback())
    }

    private func handle(_ state: ControllerState) {
        reportsSinceStatus += 1
        guard !passThrough else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let events = gestures.update(touches: state.touches,
                                     padClicked: state.buttons.contains(.touchpad), at: now)
        let output = engine.update(state: state, gestures: events, at: now)
        for action in output.actions { injector.perform(action) }
        apply(output.feedback)
    }

    private func apply(_ feedback: [FeedbackAction]) {
        let scheduler = manager.scheduler
        for item in feedback {
            switch item {
            case .rumble(let strong, let weak, let durationMs):
                scheduler.setRumble(strong: strong, weak: weak, duration: Double(durationMs) / 1000.0)
            case .lightbar(let color):
                scheduler.setLightbar(color)
            case .trigger(let side, let effect):
                switch side {
                case .left: scheduler.setLeftTrigger(effect)
                case .right: scheduler.setRightTrigger(effect)
                }
            case .playerLEDs(let mask):
                scheduler.setPlayerLEDs(mask)
            }
        }
    }

    private func printStatus() {
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = max(0.001, now - lastStatus)
        let rate = Double(reportsSinceStatus) / elapsed
        lastStatus = now
        reportsSinceStatus = 0
        let state = passThrough ? "pass-through" : mode.rawValue
        guard let info = manager.currentInfo else {
            print("[status] \(state) | waiting for a controller | held \(injector.heldCount)")
            return
        }
        let fw = info.updateVersion.map { "0x" + String($0, radix: 16) } ?? "?"
        print("[status] \(state) | \(info.transport) | fw \(fw) | \(Int(rate.rounded())) reports/s"
            + " | dropped \(manager.droppedReports) | held \(injector.heldCount)")
    }
}
#endif
