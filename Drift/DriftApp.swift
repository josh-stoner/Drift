// DriftApp.swift
// App entry point — menu bar + unified window.
// All windows opened programmatically to guarantee environment is ready.

import SwiftUI
import AppKit
import Carbon
import Sparkle

extension Notification.Name {
    static let driftOpenMainWindow = Notification.Name("driftOpenMainWindow")
}

@main
struct DriftApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }

    init() {
        // Standard macOS menu commands are handled by AppDelegate via NSMenu
    }
}

// MARK: - App delegate

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private(set) var store: DriftStore!
    private(set) var engine: PatternEngine!
    private(set) var settings: DriftSettings!

    private var mainWindow: NSWindow?
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var elapsedTextTimer: Timer?
    private(set) var updaterController: SPUStandardUpdaterController!

    private var isFirstLaunch: Bool {
        !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.appearance = NSAppearance(named: .darkAqua)

        settings = DriftSettings()
        store = DriftStore()
        engine = PatternEngine(store: store, settings: settings)
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

        setupStatusItem()
        setupPopover()
        setupMainMenu()
        setupGlobalHotkey()
        if store.activeSession != nil { engine.sessionDidStart() }

        // Listen for "open main window" from popover buttons
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openMainWindow),
            name: .driftOpenMainWindow,
            object: nil
        )

        // Open window on first launch only
        if isFirstLaunch {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            showOrCreateMainWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        teardown()
    }

    // MARK: - Main menu (P0-7)

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu

        let aboutItem = NSMenuItem(title: "About Drift", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        appMenu.addItem(aboutItem)

        let updateItem = NSMenuItem(title: "Check for Updates…", action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
        updateItem.target = updaterController
        appMenu.addItem(updateItem)

        appMenu.addItem(NSMenuItem.separator())

        let hideItem = NSMenuItem(title: "Hide Drift", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(hideItem)
        let hideOthersItem = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)
        appMenu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Drift", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenu.addItem(quitItem)

        mainMenu.addItem(appMenuItem)

        // Window menu
        let windowMenu = NSMenu(title: "Window")
        let windowMenuItem = NSMenuItem()
        windowMenuItem.submenu = windowMenu

        let openItem = NSMenuItem(title: "Open Drift", action: #selector(openMainWindow), keyEquivalent: ",")
        openItem.target = self
        windowMenu.addItem(openItem)

        let minimizeItem = NSMenuItem(title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(minimizeItem)

        let closeItem = NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(closeItem)

        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
    }

    @objc private func showAbout() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        let alert = NSAlert()
        alert.messageText = "Drift"
        alert.informativeText = "Version \(version) (\(build))\n\nBehavioral pattern awareness for focused work.\n\n\u{00A9} 2026 Josh Stoner"
        alert.alertStyle = .informational
        alert.icon = NSApp.applicationIconImage
        alert.runModal()
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = iconImage(for: .idle)
            button.imagePosition = .imageLeft
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        elapsedTextTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateElapsedText()
        }
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateStatusItemIcon()
            self?.handleAutoOpen()
        }
    }

    private func updateElapsedText() {
        guard let button = statusItem?.button else { return }
        if settings.showElapsedInMenuBar, let session = store.activeSession {
            button.title = " \(TimeInterval.formatElapsed(session.elapsed))"
        } else {
            button.title = ""
        }
    }

    private func updateStatusItemIcon() {
        guard let button = statusItem?.button else { return }
        let img = iconImage(for: engine.menuBarState)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            button.animator().image = img
        }
    }

    private func handleAutoOpen() {
        guard engine.shouldAutoOpenPopover else { return }
        engine.shouldAutoOpenPopover = false
        openPopover()
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { togglePopover(sender); return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover(sender)
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Open Drift", action: #selector(openMainWindow), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        if let session = store.activeSession {
            let info = NSMenuItem(title: session.taskName, action: nil, keyEquivalent: "")
            info.isEnabled = false
            menu.addItem(info)
            let endItem = NSMenuItem(title: "End Session", action: #selector(endCurrentSession), keyEquivalent: "")
            endItem.target = self
            menu.addItem(endItem)
            menu.addItem(NSMenuItem.separator())
        }

        let quitItem = NSMenuItem(title: "Quit Drift", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func endCurrentSession() {
        engine.sessionDidEnd()
        store.endSession()
    }

    private func iconImage(for state: MenuBarState) -> NSImage? {
        let img = NSImage(systemSymbolName: "waveform.path", accessibilityDescription: "Drift")
        guard let img else { return nil }
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let configured = img.withSymbolConfiguration(config) ?? img
        let color = iconColor(for: state)
        let tinted = NSImage(size: configured.size, flipped: false) { rect in
            configured.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        tinted.isTemplate = false
        return tinted
    }

    private func iconColor(for state: MenuBarState) -> NSColor {
        switch state {
        case .idle:         return NSColor(Color.cmTextTertiary)
        case .active:       return NSColor(Color.cmAccent)
        case .nudgePending: return NSColor(Color.cmMauve)
        case .overrun:      return NSColor(Color.cmWarning)
        }
    }

    // MARK: - Popover

    private func setupPopover() {
        let pop = NSPopover()
        pop.contentSize = NSSize(width: 340, height: 260)
        pop.behavior = .transient
        pop.animates = true
        let root = PopoverRoot(engine: engine).environment(store)
        pop.contentViewController = NSHostingController(rootView: root)
        self.popover = pop
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let pop = popover else { return }
        if pop.isShown { pop.performClose(nil) } else { openPopover() }
    }

    private func openPopover() {
        guard let button = statusItem?.button, let pop = popover, !pop.isShown else { return }
        NSApp.activate(ignoringOtherApps: true)
        pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    // MARK: - Main window

    @objc func openMainWindow(_ notification: Notification? = nil) {
        popover?.performClose(nil)

        // Delay window show so the popover fully closes first (transient popover race)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            self.showOrCreateMainWindow()
        }
    }

    private func showOrCreateMainWindow() {
        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let windowSize = NSSize(width: 560, height: 580)
        let content = DriftWindowView(store: store, engine: engine, settings: settings)
        let hc = NSHostingController(rootView: content)
        let window = NSWindow(contentViewController: hc)
        window.title = "Drift"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor(Color.cmBackground)
        window.isOpaque = true
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.setContentSize(windowSize)
        window.minSize = windowSize
        window.maxSize = windowSize
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.mainWindow = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if !NSApp.windows.contains(where: { $0.isVisible }) {
                    NSApp.setActivationPolicy(.accessory)
                }
            }
        }
        self.mainWindow = window
    }

    // MARK: - Global hotkey (P0-2: always registered, checks hotkeyEnabled dynamically)

    private func setupGlobalHotkey() {
        let handler: (NSEvent) -> Void = { [weak self] event in
            guard let self, self.settings.hotkeyEnabled else { return }
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                .subtracting([.function, .capsLock, .numericPad])
            let expectedMods = NSEvent.ModifierFlags(rawValue: self.settings.hotkeyModifiers)
            if mods == expectedMods && event.keyCode == UInt16(self.settings.hotkeyKeyCode) {
                DispatchQueue.main.async { self.togglePopover(nil) }
            }
        }
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: handler)
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handler(event); return event
        }
    }

    // MARK: - Teardown

    private func teardown() {
        elapsedTextTimer?.invalidate()
        if let m = globalKeyMonitor { NSEvent.removeMonitor(m) }
        if let m = localKeyMonitor { NSEvent.removeMonitor(m) }
        if let item = statusItem { NSStatusBar.system.removeStatusItem(item) }
        popover = nil; mainWindow = nil
    }
}
