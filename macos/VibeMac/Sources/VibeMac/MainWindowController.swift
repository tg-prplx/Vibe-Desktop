import AppKit
import SwiftUI

final class VibeHostingView<Content: View>: NSHostingView<Content> {
    override func layout() {
        super.layout()
        disableTabFocus(in: self)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        disableTabFocus(in: self)
    }

    private func disableTabFocus(in view: NSView) {
        if let button = view as? NSButton {
            button.refusesFirstResponder = true
        }
        view.subviews.forEach(disableTabFocus)
    }
}

final class MainWindowController: NSWindowController, NSWindowDelegate {
    private let chromeHeight: CGFloat = 58
    private let trafficLightBackingIdentifier = NSUserInterfaceItemIdentifier("VibeTrafficLightBacking")
    private let model: AppModel

    init(configuration: CLIConfiguration) {
        self.model = AppModel(configuration: configuration)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1440, height: 860),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = configuration.title
        window.minSize = NSSize(width: 940, height: 640)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = false
        window.isOpaque = true
        window.backgroundColor = VibeTheme.background
        window.contentView = VibeHostingView(rootView: VibeRootView(model: model))
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.center()
        window?.makeKeyAndOrderFront(sender)
        scheduleTrafficLightAlignment()
        model.start()
    }

    func windowDidResize(_ notification: Notification) {
        scheduleTrafficLightAlignment()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        scheduleTrafficLightAlignment()
    }

    func stop() {
        model.stop()
    }

    @objc func restartSession() {
        model.stop()
        model.start()
    }

    @objc func clearLocalView() {
        model.messages.removeAll()
        model.logs.removeAll()
    }

    @objc func chooseWorkingDirectory() {
        let panel = NSOpenPanel()
        panel.title = "Choose Working Directory"
        panel.prompt = "Choose"
        panel.message = "Select the folder Vibe should use for this session."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = model.configuration.workdir

        guard let window else {
            if panel.runModal() == .OK, let url = panel.url {
                model.switchWorkingDirectory(to: url)
            }
            return
        }

        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.model.switchWorkingDirectory(to: url)
            self?.window?.title = url.lastPathComponent.isEmpty ? "Vibe" : "Vibe - \(url.lastPathComponent)"
        }
    }

    @objc func attachFilesToPrompt() {
        let panel = NSOpenPanel()
        panel.title = "Attach Files"
        panel.prompt = "Attach"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.directoryURL = model.configuration.workdir

        guard let window else {
            if panel.runModal() == .OK {
                model.attachFiles(panel.urls)
            }
            return
        }

        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK else { return }
            self?.model.attachFiles(panel.urls)
        }
    }

    private func scheduleTrafficLightAlignment() {
        DispatchQueue.main.async { [weak self] in
            self?.alignTrafficLights()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.alignTrafficLights()
        }
    }

    private func alignTrafficLights() {
        guard let window else { return }
        window.contentView?.layoutSubtreeIfNeeded()
        let buttons = [
            window.standardWindowButton(.closeButton),
            window.standardWindowButton(.miniaturizeButton),
            window.standardWindowButton(.zoomButton),
        ].compactMap { $0 }
        guard buttons.count == 3, let superview = buttons.first?.superview else { return }
        superview.layoutSubtreeIfNeeded()

        let backing = trafficLightBacking(in: superview, below: buttons[0])
        let backingWidth: CGFloat = 72
        let backingHeight: CGFloat = chromeHeight + 12
        let backingY = max(0, superview.bounds.maxY - backingHeight - 16)
        backing.frame = NSRect(x: 0, y: backingY, width: backingWidth, height: backingHeight)

        let left: CGFloat = 14
        let spacing: CGFloat = 20
        let buttonHeight = buttons[0].bounds.height
        let chromeTop = superview.bounds.maxY
        let y = max(0, chromeTop - chromeHeight + (chromeHeight - buttonHeight) / 2)

        for (index, button) in buttons.enumerated() {
            button.isHidden = false
            button.setFrameOrigin(NSPoint(x: left + CGFloat(index) * spacing, y: y))
        }
    }

    private func trafficLightBacking(in superview: NSView, below button: NSView) -> NSView {
        if let existing = superview.subviews.first(where: { $0.identifier == trafficLightBackingIdentifier }) {
            superview.addSubview(existing, positioned: .below, relativeTo: button)
            return existing
        }

        let backing = NSView()
        backing.identifier = trafficLightBackingIdentifier
        backing.wantsLayer = true
        backing.layer?.backgroundColor = VibeTheme.sidebar.cgColor
        backing.layer?.cornerRadius = 0
        backing.layer?.maskedCorners = [.layerMaxXMinYCorner]
        backing.layer?.masksToBounds = true
        superview.addSubview(backing, positioned: .below, relativeTo: button)
        return backing
    }
}
