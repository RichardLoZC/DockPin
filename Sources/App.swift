import AppKit
import ApplicationServices
import ServiceManagement

final class DockPinApp: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let preferences = UserDefaults.standard
    private let engine = LockEngine()
    private let mover = DockMover()
    private let locator = DockLocator()
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var pendingMove: DispatchWorkItem?
    private var moveGeneration = 0
    private var observers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var sleeping = false
    private var status = "正在检查显示器…"
    private var verified = false
    private var policy = DockPolicy(displays: [], preferredUUID: nil)

    private var enabled: Bool {
        get { preferences.object(forKey: "lockEnabled") as? Bool ?? true }
        set { preferences.set(newValue, forKey: "lockEnabled") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "local.abu.dockpin").count > 1 {
            NSApp.terminate(nil); return
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu(); menu.delegate = self; statusItem.menu = menu
        engine.onUnexpectedDisable = { [weak self] in
            guard let self else { return }
            self.enabled = false; self.engine.stop(); self.cancelMove(); self.refresh()
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in self?.cancelMove(); self?.refresh() })
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.sleeping = true; self?.cancelMove(); self?.engine.stop(); self?.refresh()
        })
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.sleeping = false; self?.refresh()
            })
        }
        workspaceObservers.append(center.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.sleeping = true; self?.cancelMove(); self?.engine.stop()
        })
        timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in self?.refresh() }
        timer?.tolerance = 0.3
        RunLoop.main.add(timer!, forMode: .common)
        refresh()
        if !preferences.bool(forKey: "hasOpened") {
            preferences.set(true, forKey: "hasOpened")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.showHelp() }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showHelp(); return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        cancelMove(); engine.stop(); timer?.invalidate()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
    }

    private func refresh() {
        policy = DockPolicy(displays: DisplayCatalog.read(), preferredUUID: preferences.string(forKey: "targetUUID"))
        engine.policy = policy
        verified = false
        if !enabled { engine.stop(); cancelMove(); status = "已暂停" }
        else if sleeping { engine.stop(); status = "休眠期间已暂停" }
        else if !DisplayCatalog.dockAtBottom { engine.stop(); cancelMove(); status = "请先把 Dock 放在屏幕底部" }
        else if !NSScreen.screensHaveSeparateSpaces { engine.stop(); cancelMove(); status = "系统已限制 Dock 仅在主屏显示" }
        else if policy.displays.count < 2 { engine.stop(); cancelMove(); status = "等待连接第二块屏幕" }
        else if !AXIsProcessTrusted() { engine.stop(); cancelMove(); status = "等待辅助功能授权" }
        else if let target = policy.target, policy.summonPoint(for: target) == nil {
            engine.stop(); cancelMove(); status = "目标屏底边被遮住，请错开屏幕排列"
        }
        else if !engine.start() { status = "鼠标拦截未启动，请检查权限或重开程序" }
        else if mover.isMoving { status = "正在将 Dock 移回目标屏…" }
        else if let target = policy.target {
            verified = locator.display(in: policy)?.id == target.id
            status = verified ? "已固定：\(target.name)" : "拦截已开启，等待 Dock 归位"
        }
        let symbol = verified ? "pin.fill" : (enabled ? "pin" : "pin.slash")
        statusItem?.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "DockPin · \(status)")
        statusItem?.button?.toolTip = "DockPin · \(status)"
    }

    func menuWillOpen(_ menu: NSMenu) {
        refresh(); menu.removeAllItems()
        @discardableResult func item(_ title: String, _ action: Selector? = nil, key: String = "") -> NSMenuItem {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.target = self; menu.addItem(item); return item
        }
        item("DockPin · 免费本地工具")
        item(status)
        if policy.usingFallback { item("首选屏未连接，暂用主显示器") }
        menu.addItem(.separator())
        let lock = item("固定 Dock", #selector(toggleLock)); lock.state = enabled ? .on : .off
        let screens = item("固定到屏幕")
        let submenu = NSMenu()
        let main = NSMenuItem(title: "跟随主显示器", action: #selector(selectScreen(_:)), keyEquivalent: "")
        main.target = self; main.representedObject = ""; main.state = policy.preferredUUID == nil ? .on : .off
        submenu.addItem(main); submenu.addItem(.separator())
        for display in policy.displays {
            let label = "\(display.name)\(display.isMain ? "（主屏）" : "") · \(Int(display.bounds.width)) × \(Int(display.bounds.height))"
            let screen = NSMenuItem(title: label, action: #selector(selectScreen(_:)), keyEquivalent: "")
            screen.target = self; screen.representedObject = display.uuid
            screen.state = policy.preferredUUID == display.uuid ? .on : .off
            submenu.addItem(screen)
        }
        screens.submenu = submenu
        let move = item("现在将 Dock 移回目标屏", #selector(moveDock))
        move.isEnabled = engine.isRunning && !mover.isMoving
        item("按住 Option 可临时放行")
        menu.addItem(.separator())
        let login = item("登录时启动", #selector(toggleLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        if SMAppService.mainApp.status == .requiresApproval { item("登录项等待系统批准", #selector(openLoginSettings)) }
        item("辅助功能权限…", #selector(requestAccessibility))
        item("排列显示器…", #selector(openDisplays))
        item("使用说明…", #selector(showHelp))
        menu.addItem(.separator())
        item("退出 DockPin", #selector(quit), key: "q")
        // Keep runtime-dependent items disabled instead of AppKit validating them.
        menu.autoenablesItems = false
        for entry in menu.items where entry.action == nil && entry.submenu == nil { entry.isEnabled = false }
    }

    @objc private func toggleLock() { cancelMove(); enabled.toggle(); refresh() }

    @objc private func selectScreen(_ sender: NSMenuItem) {
        cancelMove()
        let uuid = sender.representedObject as? String ?? ""
        if uuid.isEmpty { preferences.removeObject(forKey: "targetUUID") }
        else { preferences.set(uuid, forKey: "targetUUID") }
        enabled = true; refresh()
    }

    @objc private func moveDock() {
        // Wait until the menu closes and the selecting mouse button is released.
        cancelMove()
        let generation = moveGeneration
        let work = DispatchWorkItem { [weak self] in
            guard let self, generation == self.moveGeneration else { return }
            self.pendingMove = nil
            self.refresh(); guard self.engine.isRunning else { return }
            self.mover.start(policy: self.policy) { [weak self] message in
                self?.refresh()
                if let message { self?.alert("Dock 归位未完成", message) }
            }
            self.refresh()
        }
        pendingMove = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    private func cancelMove() {
        moveGeneration &+= 1
        pendingMove?.cancel(); pendingMove = nil; mover.cancel()
    }

    @objc private func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc private func openDisplays() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension")!)
    }

    @objc private func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }

    @objc private func toggleLogin() {
        do {
            switch SMAppService.mainApp.status {
            case .enabled, .requiresApproval: try SMAppService.mainApp.unregister()
            default: try SMAppService.mainApp.register()
            }
            if SMAppService.mainApp.status == .requiresApproval { openLoginSettings() }
        } catch { alert("无法设置登录时启动", "请从“应用程序”目录运行 DockPin，然后重试。\n\n\(error.localizedDescription)") }
    }

    @objc private func showHelp() {
        refresh()
        let help = NSAlert()
        help.messageText = "DockPin · 固定底部 Dock"
        help.informativeText = "\(status)\n\n1. 保持 Dock 位于底部，并开启“显示器具有单独的空间”。\n2. 在菜单栏图钉中选择目标屏幕。\n3. 若 Dock 还在另一屏，点击“现在将 Dock 移回目标屏”，或在目标屏底边向下推动鼠标。\n\n按住 Option 临时放行；暂停或退出后立即恢复正常。归位按钮会短暂移动鼠标，移动完成后还原。\n\n程序需要辅助功能权限来拦截副屏底部 4 点范围内的鼠标移动及拖动，不读取键盘输入，也不联网。"
        help.addButton(withTitle: AXIsProcessTrusted() ? "知道了" : "打开辅助功能设置")
        if !AXIsProcessTrusted() { help.addButton(withTitle: "稍后设置") }
        NSApp.activate(ignoringOtherApps: true)
        let trusted = AXIsProcessTrusted()
        if help.runModal() == .alertFirstButtonReturn && !trusted { requestAccessibility() }
    }

    private func alert(_ title: String, _ text: String) {
        let alert = NSAlert(); alert.messageText = title; alert.informativeText = text
        alert.addButton(withTitle: "好"); NSApp.activate(ignoringOtherApps: true); alert.runModal()
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
