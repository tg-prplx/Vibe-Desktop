import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let configuration = CLIConfiguration.parse(processArguments: CommandLine.arguments)

        let controller = MainWindowController(configuration: configuration)
        mainWindowController = controller
        installMenu(target: controller)
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        mainWindowController?.stop()
    }

    private func installMenu(target: MainWindowController) {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        addMenuItem(to: appMenu, title: "Restart Session", action: #selector(MainWindowController.restartSession), key: "r", target: target)
        addMenuItem(to: appMenu, title: "Clear Local View", action: #selector(MainWindowController.clearLocalView), key: "k", target: target)
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Vibe", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        addMenuItem(to: fileMenu, title: "Choose Working Directory...", action: #selector(MainWindowController.chooseWorkingDirectory), key: "o", target: target)
        addMenuItem(to: fileMenu, title: "Attach Files...", action: #selector(MainWindowController.attachFilesToPrompt), key: "u", target: target)
        fileMenu.addItem(NSMenuItem.separator())
        addMenuItem(to: fileMenu, title: "Restart Session", action: #selector(MainWindowController.restartSession), key: "r", target: target)
        fileItem.submenu = fileMenu
        mainMenu.addItem(fileItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        addStandardMenuItem(to: editMenu, title: "Undo", action: Selector(("undo:")), key: "z")
        addStandardMenuItem(to: editMenu, title: "Redo", action: Selector(("redo:")), key: "Z", modifiers: [.command, .shift])
        editMenu.addItem(NSMenuItem.separator())
        addStandardMenuItem(to: editMenu, title: "Cut", action: #selector(NSText.cut(_:)), key: "x")
        addStandardMenuItem(to: editMenu, title: "Copy", action: #selector(NSText.copy(_:)), key: "c")
        addStandardMenuItem(to: editMenu, title: "Paste", action: #selector(NSText.paste(_:)), key: "v")
        addStandardMenuItem(to: editMenu, title: "Paste and Match Style", action: #selector(NSTextView.pasteAsPlainText(_:)), key: "v", modifiers: [.command, .option, .shift])
        addStandardMenuItem(to: editMenu, title: "Delete", action: #selector(NSText.delete(_:)), key: "\u{8}", modifiers: [])
        editMenu.addItem(NSMenuItem.separator())
        addStandardMenuItem(to: editMenu, title: "Select All", action: #selector(NSText.selectAll(_:)), key: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        NSApp.mainMenu = mainMenu
    }

    private func addMenuItem(to menu: NSMenu, title: String, action: Selector, key: String, target: AnyObject) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target
        menu.addItem(item)
    }

    private func addStandardMenuItem(
        to menu: NSMenu,
        title: String,
        action: Selector,
        key: String,
        modifiers: NSEvent.ModifierFlags = [.command]
    ) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = nil
        menu.addItem(item)
    }
}
