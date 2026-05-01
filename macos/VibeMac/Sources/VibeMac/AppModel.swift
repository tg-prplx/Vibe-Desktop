import Foundation
import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum MessageRole: String, Identifiable {
    case user
    case assistant
    case thought
    case tool
    case error

    var id: String { rawValue }
}

enum SidebarSection: String, CaseIterable, Identifiable {
    case chats = "Chats"
    case files = "Files"
    case commands = "Commands"
    case settings = "Settings"
    case logs = "Logs"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .chats: "bubble.left.and.bubble.right"
        case .files: "doc.text"
        case .commands: "command"
        case .settings: "gearshape"
        case .logs: "list.bullet.rectangle"
        }
    }
}

enum InspectorTab: String, CaseIterable, Identifiable {
    case run = "Run"
    case files = "Files"
    case context = "Context"

    var id: String { rawValue }
}

struct ChatMessage: Identifiable, Equatable {
    let id: String
    var role: MessageRole
    var title: String
    var timestamp: Date
    var content: String
    var status: String?
    var kind: String?

    var listID: String {
        "\(role.rawValue):\(id)"
    }
}

struct ProjectFile: Identifiable {
    let id = UUID()
    var path: String
    var kind: String
}

struct CodeFileItem: Identifiable {
    var id: String { path }
    var path: String
    var relativePath: String
    var name: String
    var kind: String
    var size: Int64
}

struct PromptAttachment: Identifiable {
    let id = UUID()
    var url: URL
    var name: String
    var size: Int64
    var mimeType: String
    var embeddedText: String?

    var isEmbedded: Bool { embeddedText != nil }
}

struct TodoItem: Identifiable {
    let id = UUID()
    var text: String
    var completed: Bool
}

struct VibeConfigOption: Identifiable {
    struct Choice: Identifiable {
        let id: String
        let name: String
    }

    let id: String
    let category: String
    var currentValue: String
    var choices: [Choice]
}

struct VibeConfigScalar: Identifiable {
    var id: String { key }
    var key: String
    var description: String
    var value: String
    var valueType: String
    var persisted: Bool

    var boolValue: Bool? {
        switch value.lowercased() {
        case "true": return true
        case "false": return false
        default: return nil
        }
    }
}

struct VibeConfigModel: Identifiable {
    var id: String { alias }
    var alias: String
    var name: String
    var provider: String
    var thinking: String
    var temperature: String
    var threshold: String
    var active: Bool
}

struct VibeConfigProvider: Identifiable {
    var id: String { name }
    var name: String
    var backend: String
    var apiBase: String
    var apiKeyEnv: String
}

struct VibeConfigServer: Identifiable {
    var id: String { name }
    var name: String
    var transport: String
    var target: String
    var disabled: Bool
}

struct VibeEnvVar: Identifiable {
    var id: String { key }
    var key: String
    var set: Bool
    var maskedValue: String
}

struct ChatSessionInfo: Identifiable {
    var id: String { sessionID }
    var sessionID: String
    var title: String
    var cwd: String
    var updatedAt: String

    var displayTitle: String {
        if !title.isEmpty { return title }
        return URL(fileURLWithPath: cwd).lastPathComponent.isEmpty ? "Untitled chat" : URL(fileURLWithPath: cwd).lastPathComponent
    }
}

struct ExecutionLog: Identifiable {
    let id = UUID()
    var date: Date
    var text: String
    var level: LogLevel
}

enum LogLevel {
    case info
    case success
    case warning
    case error
}

struct PermissionRequest: Identifiable {
    struct Option: Identifiable {
        let id: String
        let name: String
    }

    let id: AnyHashable
    let title: String
    let detail: String
    let toolCallID: String?
    let options: [Option]
}

@MainActor
final class AppModel: ObservableObject {
    @Published var selectedSection: SidebarSection = .chats
    @Published var selectedInspectorTab: InspectorTab = .run
    @Published var leftSidebarCollapsed = false
    @Published var inspectorCollapsed = false
    @Published var chatTitle = "New Vibe Session"
    @Published var modelName = "Mistral Vibe"
    @Published var activeModelID = "loading..."
    @Published var status = "Starting"
    @Published var activityText = "Starting ACP backend"
    @Published var duration = "0s"
    @Published var tokenText = "0 / 240k"
    @Published var tokenProgress = 0.0
    @Published var messages: [ChatMessage] = []
    @Published var files: [ProjectFile] = []
    @Published var todos: [TodoItem] = []
    @Published var logs: [ExecutionLog] = []
    @Published var availableCommands: [(name: String, description: String)] = []
    @Published var configOptions: [VibeConfigOption] = []
    @Published var configScalars: [VibeConfigScalar] = []
    @Published var configModels: [VibeConfigModel] = []
    @Published var configProviders: [VibeConfigProvider] = []
    @Published var configMCPServers: [VibeConfigServer] = []
    @Published var configConnectors: [VibeConfigServer] = []
    @Published var configEnvVars: [VibeEnvVar] = []
    @Published var configRawText = ""
    @Published var configPath = ""
    @Published var envPath = ""
    @Published var logPath = ""
    @Published var sessionLogDir = ""
    @Published var activeProvider = ""
    @Published var configSyncStatus = "Config not loaded"
    @Published var pendingPermission: PermissionRequest?
    @Published var attachments: [PromptAttachment] = []
    @Published var input = ""
    @Published var chatSessions: [ChatSessionInfo] = []
    @Published var chatListStatus = "Chats not loaded"
    @Published var activeSessionID = ""
    @Published var codeFiles: [CodeFileItem] = []
    @Published var fileSearch = ""
    @Published var selectedCodeFile: CodeFileItem?
    @Published var editorText = ""
    @Published var savedEditorText = ""
    @Published var editorStatus = "No file open"
    @Published var editorError = ""

    @Published private(set) var configuration: CLIConfiguration
    private var client: ACPClient?
    private var sessionID: String?
    private var startDate = Date()
    private var timer: Timer?
    private static let maxEditableFileSize: Int64 = 1_000_000

    init(configuration: CLIConfiguration) {
        self.configuration = configuration
        self.chatTitle = configuration.workdir.lastPathComponent.isEmpty
            ? "Vibe Session"
            : configuration.workdir.lastPathComponent
    }

    func start() {
        stop()
        status = "Starting"
        activityText = "Starting ACP backend"
        activeModelID = "loading..."
        messages.removeAll()
        files.removeAll()
        todos.removeAll()
        attachments.removeAll()
        pendingPermission = nil
        refreshCodeFiles()
        appendLog("Starting ACP backend...", level: .info)
        startDate = Date()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickDuration() }
        }
        let client = ACPClient(configuration: configuration, model: self)
        self.client = client
        client.start()
    }

    func switchWorkingDirectory(to url: URL) {
        let directory = url.standardizedFileURL
        guard directory.path != configuration.workdir.path else { return }
        stop()
        configuration.workdir = directory
        chatTitle = directory.lastPathComponent.isEmpty ? "Vibe Session" : directory.lastPathComponent
        selectedSection = .chats
        selectedInspectorTab = .run
        logs.removeAll()
        availableCommands.removeAll()
        configOptions.removeAll()
        chatSessions.removeAll()
        activeSessionID = ""
        codeFiles.removeAll()
        selectedCodeFile = nil
        editorText = ""
        savedEditorText = ""
        editorStatus = "No file open"
        editorError = ""
        attachments.removeAll()
        appendLog("Working directory changed to \(directory.path)", level: .info)
        start()
    }

    func stop() {
        timer?.invalidate()
        client?.stop()
        client = nil
    }

    func selectSection(_ section: SidebarSection) {
        selectedSection = section
        if section == .chats {
            listChatSessions()
        } else if section == .files {
            refreshCodeFiles()
        }
        switch section {
        case .chats:
            selectedInspectorTab = .run
        case .files:
            selectedInspectorTab = .files
        case .commands:
            selectedInspectorTab = .context
        case .settings:
            selectedInspectorTab = .context
        case .logs:
            selectedInspectorTab = .run
        }
    }

    func sendPrompt() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !attachments.isEmpty else { return }
        if attachments.isEmpty, handleClientCommand(trimmed) {
            input = ""
            return
        }
        let promptAttachments = attachments
        guard let client else {
            appendLog("Prompt not sent: backend is not running", level: .error)
            status = "Not ready"
            return
        }
        guard client.sendPrompt(trimmed, attachments: promptAttachments) else {
            appendLog("Prompt not sent: session is not ready", level: .error)
            status = "Not ready"
            return
        }
        input = ""
        attachments.removeAll()
        appendUserMessage(trimmed, attachments: promptAttachments)
        status = "Running"
        activityText = promptAttachments.isEmpty ? "Sending prompt" : "Sending prompt with \(promptAttachments.count) file(s)"
        appendLog(promptAttachments.isEmpty ? "Prompt sent" : "Prompt sent with \(promptAttachments.count) file(s)", level: .info)
        promptAttachments.forEach { addProjectFile($0.url.path) }
    }

    func sendSlashCommand(_ command: String) {
        let slashCommand = command.hasPrefix("/") ? command : "/\(command)"
        if handleClientCommand(slashCommand) {
            return
        }
        selectedSection = .chats
        input = slashCommand
        sendPrompt()
    }

    var commandSuggestions: [(name: String, description: String)] {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/"), !trimmed.contains(" ") else { return [] }
        let query = trimmed.lowercased()
        return availableCommands
            .filter { $0.name.lowercased().hasPrefix(query) || query == "/" }
            .prefix(8)
            .map { $0 }
    }

    var inlineCommandSuggestion: (name: String, description: String)? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/"), !trimmed.contains(" ") else { return nil }
        return commandSuggestions.first { $0.name.lowercased() != trimmed.lowercased() }
    }

    var inlineCommandCompletionTail: String {
        guard let suggestion = inlineCommandSuggestion else { return "" }
        let typed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard suggestion.name.lowercased().hasPrefix(typed.lowercased()) else { return "" }
        return String(suggestion.name.dropFirst(typed.count)) + " "
    }

    func completeCommand(_ command: String) {
        input = "\(command) "
    }

    func acceptInlineCommandSuggestion() -> Bool {
        guard let suggestion = inlineCommandSuggestion else { return false }
        completeCommand(suggestion.name)
        return true
    }

    func submitComposer() {
        if acceptInlineCommandSuggestion() {
            return
        }
        sendPrompt()
    }

    func newChat() {
        guard status != "Running" else { return }
        resetConversationForSession(title: configuration.workdir.lastPathComponent.isEmpty ? "New Vibe Session" : configuration.workdir.lastPathComponent)
        status = "Starting"
        activityText = "Creating new chat"
        client?.createNewSession()
    }

    func listChatSessions() {
        guard status != "Starting" else {
            chatListStatus = "Waiting for backend"
            return
        }
        chatListStatus = "Loading chats..."
        client?.listSessions(cwd: configuration.workdir.path)
    }

    func loadChatSession(_ session: ChatSessionInfo) {
        guard status != "Running" else { return }
        resetConversationForSession(title: session.displayTitle)
        status = "Starting"
        activityText = "Loading chat"
        activeSessionID = session.sessionID
        client?.loadSession(sessionID: session.sessionID, cwd: configuration.workdir.path)
    }

    func clearConversationView() {
        messages.removeAll()
        todos.removeAll()
        pendingPermission = nil
        appendLog("Conversation view cleared", level: .success)
    }

    func copyLastAssistantResponse() {
        let content = messages.last(where: { $0.role == .assistant })?.content ?? ""
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            appendLog("No assistant message to copy", level: .warning)
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        appendLog("Last assistant message copied", level: .success)
    }

    func copyTranscript() {
        let transcript = transcriptMarkdown()
        guard !transcript.isEmpty else {
            appendLog("No transcript to copy", level: .warning)
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(transcript, forType: .string)
        appendLog("Transcript copied", level: .success)
    }

    func exportTranscript() {
        let transcript = transcriptMarkdown()
        guard !transcript.isEmpty else {
            appendLog("No transcript to export", level: .warning)
            return
        }
        let panel = NSSavePanel()
        panel.title = "Export Chat"
        panel.prompt = "Export"
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(chatTitle.replacingOccurrences(of: "/", with: "-")) transcript.md"
        panel.directoryURL = configuration.workdir
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try transcript.write(to: url, atomically: true, encoding: .utf8)
            appendLog("Transcript exported to \(url.path)", level: .success)
        } catch {
            appendLog("Failed to export transcript: \(error)", level: .error)
        }
    }

    func openWorkingDirectory() {
        NSWorkspace.shared.open(configuration.workdir)
    }

    func openVibeHome() {
        NSWorkspace.shared.open(configuration.vibeHome)
    }

    func openConfigFile() {
        let path = configPath.isEmpty
            ? configuration.vibeHome.appendingPathComponent("config.toml").path
            : configPath
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    var editorDirty: Bool {
        editorText != savedEditorText
    }

    var filteredCodeFiles: [CodeFileItem] {
        let query = fileSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return codeFiles }
        return codeFiles.filter {
            $0.relativePath.lowercased().contains(query)
                || $0.name.lowercased().contains(query)
        }
    }

    func refreshCodeFiles() {
        codeFiles = Self.scanCodeFiles(in: configuration.workdir)
        editorStatus = selectedCodeFile == nil ? "\(codeFiles.count) editable files indexed" : editorStatus
    }

    func openCodeFile(_ file: CodeFileItem) {
        let url = URL(fileURLWithPath: file.path)
        guard file.size <= Self.maxEditableFileSize else {
            selectedCodeFile = file
            editorText = ""
            savedEditorText = ""
            editorError = "File is too large to edit safely (\(Self.formatBytes(file.size)))"
            editorStatus = "Too large"
            return
        }
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            selectedCodeFile = file
            editorText = text
            savedEditorText = text
            editorError = ""
            editorStatus = "Opened \(file.relativePath)"
            addProjectFile(file.path)
        } catch {
            selectedCodeFile = file
            editorText = ""
            savedEditorText = ""
            editorError = "Could not open file as UTF-8 text: \(error.localizedDescription)"
            editorStatus = "Open failed"
        }
    }

    func saveCodeFile() {
        guard let file = selectedCodeFile else { return }
        do {
            try editorText.write(to: URL(fileURLWithPath: file.path), atomically: true, encoding: .utf8)
            savedEditorText = editorText
            editorStatus = "Saved \(file.relativePath)"
            editorError = ""
            addProjectFile(file.path)
            refreshCodeFiles()
        } catch {
            editorError = "Could not save file: \(error.localizedDescription)"
            editorStatus = "Save failed"
        }
    }

    func revertCodeFile() {
        editorText = savedEditorText
        editorStatus = selectedCodeFile.map { "Reverted \($0.relativePath)" } ?? "No file open"
    }

    func revealCodeFile() {
        guard let file = selectedCodeFile else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: file.path)])
    }

    func attachCodeFile() {
        guard let file = selectedCodeFile else { return }
        attachFiles([URL(fileURLWithPath: file.path)])
    }

    func openFileInEditor(path: String) {
        let url = URL(fileURLWithPath: path)
        let relative = Self.relativePath(for: url, base: configuration.workdir)
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        let item = CodeFileItem(
            path: url.path,
            relativePath: relative,
            name: url.lastPathComponent,
            kind: url.pathExtension,
            size: Int64(values?.fileSize ?? 0)
        )
        selectedSection = .files
        selectedInspectorTab = .files
        openCodeFile(item)
    }

    func attachFiles(_ urls: [URL]) {
        let newAttachments = urls.compactMap { makeAttachment(from: $0) }
        attachments.append(contentsOf: newAttachments)
        newAttachments.forEach { addProjectFile($0.url.path) }
        if !newAttachments.isEmpty {
            appendLog("Attached \(newAttachments.count) file(s)", level: .info)
        }
    }

    func removeAttachment(_ attachment: PromptAttachment) {
        attachments.removeAll { $0.id == attachment.id }
    }

    func cancelPrompt() {
        client?.cancelPrompt()
        status = "Cancelling"
        activityText = "Cancelling current run"
        appendLog("Cancellation requested", level: .warning)
    }

    func approvePendingPermission(optionID: String) {
        guard let pendingPermission else { return }
        appendLog("Permission response: \(optionID)", level: optionID.contains("reject") ? .warning : .success)
        activityText = optionID.contains("reject") ? "Permission rejected" : "Permission approved"
        client?.respondPermission(id: pendingPermission.id, optionID: optionID)
        self.pendingPermission = nil
    }

    func setConfigOption(_ optionID: String, value: String) {
        switch optionID {
        case "mode":
            client?.setSessionMode(value)
        case "model":
            client?.setSessionModel(value)
        default:
            client?.setConfigOption(optionID, value: value)
        }
        if let index = configOptions.firstIndex(where: { $0.id == optionID }) {
            configOptions[index].currentValue = value
        }
        if optionID == "model" {
            activeModelID = value
        }
        appendLog("Set \(optionID) to \(value)", level: .info)
        refreshVibeConfig()
    }

    func openConfigInspector() {
        selectedSection = .commands
        selectedInspectorTab = .context
    }

    func openSettings() {
        selectedSection = .settings
        selectedInspectorTab = .context
        refreshVibeConfig()
    }

    func refreshVibeConfig() {
        configSyncStatus = "Loading config..."
        client?.requestVibeConfig()
    }

    func reloadVibeConfig() {
        configSyncStatus = "Reloading config..."
        client?.reloadVibeConfig()
    }

    func saveRawVibeConfig() {
        configSyncStatus = "Saving config.toml..."
        client?.saveVibeConfigRaw(configRawText)
    }

    func setVibeConfigValue(key: String, value: Any) {
        configSyncStatus = "Saving \(key)..."
        client?.setVibeConfigValue(key: key, value: value)
    }

    func setVibeEnv(key: String, value: String) {
        configSyncStatus = value.isEmpty ? "Removing \(key)..." : "Saving \(key)..."
        client?.setVibeEnv(key: key, value: value)
    }

    func handleInitialized(_ result: [String: Any]) {
        if let info = result["agent_info"] as? [String: Any] {
            modelName = info["title"] as? String ?? modelName
        }
        appendLog("ACP initialized", level: .success)
    }

    func handleNewSession(_ result: [String: Any]) {
        if let id = result["session_id"] as? String ?? result["sessionId"] as? String {
            sessionID = id
            activeSessionID = id
        }
        if let models = result["models"] as? [String: Any] {
            activeModelID = models["current_model_id"] as? String
                ?? models["currentModelId"] as? String
                ?? activeModelID
        }
        updateConfigOptions(from: result["config_options"] as? [[String: Any]]
            ?? result["configOptions"] as? [[String: Any]]
            ?? [])
        status = "Ready"
        activityText = "Ready"
        appendLog("Session started", level: .success)
        refreshVibeConfig()
        listChatSessions()
    }

    func handleRPCResponse(id: Any?, method: String?, result: Any?, error: [String: Any]?) {
        if let error {
            let message = error["message"] as? String ?? "JSON-RPC error"
            status = "Error"
            activityText = message
            if method?.hasPrefix("_vibe/config") == true || method?.hasPrefix("_vibe/env") == true {
                configSyncStatus = message
            }
            appendLog("\(method ?? "request") failed: \(message)", level: .error)
            return
        }

        if status == "Running" || status == "Cancelling" {
            status = "Ready"
            activityText = "Ready"
        }
        if let method {
            appendLog("\(method) completed", level: .success)
        }
        if let result = result as? [String: Any],
           let configOptions = result["config_options"] as? [[String: Any]]
            ?? result["configOptions"] as? [[String: Any]] {
            updateConfigOptions(from: configOptions)
        }
        if method == "session/list", let result = result as? [String: Any] {
            updateChatSessions(from: result)
            chatListStatus = chatSessions.isEmpty ? "No saved chats" : "\(chatSessions.count) chats"
        }
        if (method == "session/new" || method == "session/load"), let result = result as? [String: Any] {
            handleNewSession(result)
        }
        if let method,
           method.hasPrefix("_vibe/config") || method.hasPrefix("_vibe/env"),
           let result = result as? [String: Any] {
            updateVibeConfigSnapshot(from: result)
            configSyncStatus = "Config synced"
            appendLog("Vibe config synced", level: .success)
        }
    }

    func handleACPUpdate(_ update: [String: Any]) {
        guard let updateType = update["session_update"] as? String
            ?? update["sessionUpdate"] as? String else { return }
        switch updateType {
        case "available_commands_update":
            let commands = update["commands"] as? [[String: Any]]
                ?? update["availableCommands"] as? [[String: Any]]
                ?? []
            availableCommands = commands.compactMap {
                guard let name = $0["name"] as? String else { return nil }
                return ("/\(name)", $0["description"] as? String ?? "")
            }
        case "agent_message_chunk":
            activityText = "Streaming response"
            appendChunk(role: .assistant, update: update)
        case "agent_thought_chunk":
            activityText = "Thinking"
            appendChunk(role: .thought, update: update)
        case "user_message_chunk":
            appendChunk(role: .user, update: update)
        case "tool_call":
            handleToolCall(update)
        case "tool_call_update":
            handleToolUpdate(update)
        case "usage_update":
            let used = (update["used"] as? NSNumber)?.doubleValue ?? 0
            let size = (update["size"] as? NSNumber)?.doubleValue ?? 240_000
            tokenProgress = size > 0 ? min(1, used / size) : 0
            tokenText = "\(Self.formatNumber(Int(used))) / \(Self.formatNumber(Int(size)))"
        case "plan":
            handlePlan(update)
        case "config_option_update":
            updateConfigOptions(from: update["config_options"] as? [[String: Any]]
                ?? update["configOptions"] as? [[String: Any]]
                ?? [])
        case "current_mode_update":
            let modeID = update["current_mode_id"] as? String
                ?? update["currentModeId"] as? String
            if let modeID {
                updateConfigOption(id: "mode", value: modeID)
            }
        default:
            appendLog(updateType, level: .info)
        }
    }

    func handleBackendRequest(_ request: [String: Any]) {
        guard let method = request["method"] as? String else { return }
        switch method {
        case "session/request_permission":
            let params = request["params"] as? [String: Any] ?? [:]
            let toolCall = params["tool_call"] as? [String: Any]
                ?? params["toolCall"] as? [String: Any]
                ?? [:]
            let toolCallID = toolCall["tool_call_id"] as? String
                ?? toolCall["toolCallId"] as? String
            let matchingToolMessage = toolCallID.flatMap { id in
                messages.first { $0.id == id && $0.role == .tool }
            }
            let title = toolCall["title"] as? String
                ?? toolCall["name"] as? String
                ?? matchingToolMessage?.title
                ?? "Tool permission"
            let detail = permissionDetail(
                rawInput: toolCall["raw_input"] as? String ?? toolCall["rawInput"] as? String,
                title: title,
                toolCallID: toolCallID,
                matchingMessage: matchingToolMessage
            )
            let options: [PermissionRequest.Option] = (
                params["options"] as? [[String: Any]] ?? []
            ).compactMap { option -> PermissionRequest.Option? in
                let optionID = option["option_id"] as? String
                    ?? option["optionId"] as? String
                    ?? option["id"] as? String
                guard let id = optionID else { return nil }
                return PermissionRequest.Option(
                    id: id,
                    name: Self.friendlyPermissionName(option["name"] as? String ?? id)
                )
            }
            pendingPermission = PermissionRequest(
                id: ACPClient.messageID(from: request["id"]),
                title: title,
                detail: detail,
                toolCallID: toolCallID,
                options: options.isEmpty
                    ? [
                        PermissionRequest.Option(id: "allow_once", name: "Allow once"),
                        PermissionRequest.Option(id: "allow_always", name: "Allow for this session"),
                        PermissionRequest.Option(id: "reject_once", name: "Reject once"),
                    ]
                    : options
            )
            activityText = "Waiting for permission: \(title)"
            appendLog("Permission requested: \(title)", level: .warning)
        case "fs/read_text_file":
            client?.respondReadTextFile(request)
        case "fs/write_text_file":
            client?.respondWriteTextFile(request)
        case "terminal/create":
            client?.respondCreateTerminal(request)
        case "terminal/output":
            client?.respondTerminalOutput(request)
        case "terminal/wait_for_exit":
            client?.respondWaitForTerminalExit(request)
        case "terminal/kill":
            client?.respondKillTerminal(request)
        case "terminal/release":
            client?.respondReleaseTerminal(request)
        default:
            client?.respondMethodNotFound(request)
        }
    }

    private func permissionDetail(
        rawInput: String?,
        title: String,
        toolCallID: String?,
        matchingMessage: ChatMessage?
    ) -> String {
        if let rawInput, !rawInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return rawInput
        }

        var lines = ["Vibe wants permission to run `\(title)`."]
        if let toolCallID {
            lines.append("Tool call: \(toolCallID)")
        }
        if let matchingMessage {
            let summary = matchingMessage.content
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map(String.init)
                .filter { line in
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    return !trimmed.isEmpty && !trimmed.lowercased().hasPrefix("running ")
                }
                .prefix(4)
                .joined(separator: "\n")
            if !summary.isEmpty {
                lines.append(summary)
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func friendlyPermissionName(_ value: String) -> String {
        switch value {
        case "allow_once": return "Allow once"
        case "allow_always", "allow_for_session", "allow_session": return "Allow for this session"
        case "reject_once": return "Reject once"
        default:
            return value
                .replacingOccurrences(of: "_", with: " ")
                .split(separator: " ")
                .map { word in
                    word.prefix(1).uppercased() + word.dropFirst()
                }
                .joined(separator: " ")
        }
    }

    private func handleClientCommand(_ rawCommand: String) -> Bool {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return false }
        let parts = trimmed.split(maxSplits: 1, whereSeparator: { $0.isWhitespace })
        guard let commandPart = parts.first else { return false }
        let command = String(commandPart).lowercased()
        let argument = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines) : ""
        switch command {
        case "/config":
            openSettings()
            appendLog("Opened native config controls", level: .info)
            return true
        case "/model":
            if argument.isEmpty {
                openSettings()
                appendLog("Opened native model controls", level: .info)
            } else {
                setConfigOption("model", value: argument)
            }
            return true
        case "/thinking":
            if argument.isEmpty {
                openSettings()
                appendLog("Opened native thinking controls", level: .info)
            } else {
                setConfigOption("thinking", value: argument)
            }
            return true
        case "/mode":
            if argument.isEmpty {
                openSettings()
                appendLog("Opened native mode controls", level: .info)
            } else {
                setConfigOption("mode", value: argument)
            }
            return true
        case "/clear":
            clearConversationView()
            return true
        case "/copy":
            copyLastAssistantResponse()
            return true
        case "/export":
            exportTranscript()
            return true
        case "/debug":
            selectedSection = .logs
            selectedInspectorTab = .run
            return true
        case "/exit":
            NSApp.terminate(nil)
            return true
        case "/status":
            let statusText = """
            Status: \(status)
            Model: \(activeModelID)
            Duration: \(duration)
            Tokens: \(tokenText)
            Messages: \(messages.count)
            Files: \(files.count)
            Commands: \(availableCommands.count)
            """
            messages.append(ChatMessage(
                id: UUID().uuidString,
                role: .assistant,
                title: "Status",
                timestamp: Date(),
                content: statusText,
                status: nil,
                kind: nil
            ))
            return true
        default:
            return false
        }
    }

    private func resetConversationForSession(title: String) {
        messages.removeAll()
        files.removeAll()
        todos.removeAll()
        attachments.removeAll()
        pendingPermission = nil
        tokenProgress = 0
        tokenText = "0 / 240k"
        chatTitle = title
    }

    private func transcriptMarkdown() -> String {
        let rendered = messages
            .filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { message in
                let role = switch message.role {
                case .user: "You"
                case .assistant: "Vibe"
                case .thought: "Thought"
                case .tool: "Tool: \(message.title)"
                case .error: "Error"
                }
                return "## \(role)\n\n\(message.content.trimmingCharacters(in: .whitespacesAndNewlines))"
            }
            .joined(separator: "\n\n")
        guard !rendered.isEmpty else { return "" }
        return "# \(chatTitle)\n\n\(rendered)\n"
    }

    private func appendUserMessage(_ text: String, attachments: [PromptAttachment]) {
        let attachmentText = attachments.map { attachment in
            let mode = attachment.isEmbedded ? "embedded" : "linked"
            return "- \(attachment.name) (\(Self.formatBytes(attachment.size)), \(mode))"
        }.joined(separator: "\n")
        let content: String
        if text.isEmpty {
            content = attachmentText.isEmpty ? " " : "Attached files:\n\(attachmentText)"
        } else if attachmentText.isEmpty {
            content = text
        } else {
            content = "\(text)\n\nAttached files:\n\(attachmentText)"
        }
        messages.append(ChatMessage(
            id: UUID().uuidString,
            role: .user,
            title: "You",
            timestamp: Date(),
            content: content,
            status: nil,
            kind: nil
        ))
    }

    private func makeAttachment(from url: URL) -> PromptAttachment? {
        guard !attachments.contains(where: { $0.url.path == url.path }) else { return nil }
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey, .contentTypeKey])
        guard values?.isDirectory != true else { return nil }
        let size = Int64(values?.fileSize ?? 0)
        let mimeType = values?.contentType?.preferredMIMEType ?? "application/octet-stream"
        let embeddedText = Self.readEmbeddableText(from: url, size: size, mimeType: mimeType)
        return PromptAttachment(
            url: url,
            name: url.lastPathComponent,
            size: size,
            mimeType: mimeType,
            embeddedText: embeddedText
        )
    }

    private func addProjectFile(_ path: String) {
        guard !files.contains(where: { $0.path == path }) else { return }
        files.append(ProjectFile(path: path, kind: URL(fileURLWithPath: path).pathExtension))
    }

    private static func scanCodeFiles(in root: URL) -> [CodeFileItem] {
        let fileManager = FileManager.default
        let skipDirectories = Set([".git", ".venv", "node_modules", ".build", "dist", "build", ".next", "DerivedData"])
        let textExtensions = Set([
            "swift", "py", "js", "jsx", "ts", "tsx", "css", "scss", "html", "json", "md", "txt",
            "toml", "yaml", "yml", "xml", "sh", "zsh", "fish", "c", "h", "cpp", "hpp", "rs",
            "go", "java", "kt", "rb", "php", "sql", "env"
        ])
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else { return [] }

        var result: [CodeFileItem] = []
        for case let url as URL in enumerator {
            if result.count >= 700 { break }
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .isRegularFileKey])
            if values?.isDirectory == true {
                if skipDirectories.contains(url.lastPathComponent) {
                    enumerator.skipDescendants()
                }
                continue
            }
            guard values?.isRegularFile == true else { continue }
            let ext = url.pathExtension.lowercased()
            let hasTextName = url.lastPathComponent.hasPrefix(".env") || url.lastPathComponent == "Dockerfile" || url.lastPathComponent == "Makefile"
            guard textExtensions.contains(ext) || hasTextName else { continue }
            let size = Int64(values?.fileSize ?? 0)
            guard size <= 5_000_000 else { continue }
            result.append(CodeFileItem(
                path: url.path,
                relativePath: relativePath(for: url, base: root),
                name: url.lastPathComponent,
                kind: ext.isEmpty ? "text" : ext,
                size: size
            ))
        }
        return result.sorted { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
    }

    private static func relativePath(for url: URL, base: URL) -> String {
        let basePath = base.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        if path.hasPrefix(basePath + "/") {
            return String(path.dropFirst(basePath.count + 1))
        }
        return url.lastPathComponent
    }

    private func appendChunk(role: MessageRole, update: [String: Any]) {
        let messageID = update["message_id"] as? String
            ?? update["messageId"] as? String
            ?? UUID().uuidString
        let content = textContent(from: update)
        if role == .assistant && content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return
        }
        if let index = messages.firstIndex(where: { $0.id == messageID && $0.role == role }) {
            messages[index].content += content
            if !content.isEmpty {
                messages[index].status = nil
            }
        } else {
            messages.append(ChatMessage(
                id: messageID,
                role: role,
                title: role == .user ? "You" : role == .thought ? "Thought" : "Vibe",
                timestamp: Date(),
                content: content,
                status: role == .assistant && content.isEmpty ? "streaming" : nil,
                kind: nil
            ))
        }
    }

    private func handleToolCall(_ update: [String: Any]) {
        let id = update["tool_call_id"] as? String
            ?? update["toolCallId"] as? String
            ?? UUID().uuidString
        let title = update["title"] as? String ?? "Tool call"
        let kind = update["kind"] as? String
        let raw = update["raw_input"] as? String
            ?? update["rawInput"] as? String
            ?? ""
        let display = toolStartDisplay(title: title, raw: raw)
        if let index = messages.firstIndex(where: { $0.id == id && $0.role == .tool }) {
            messages[index].title = title
            messages[index].kind = kind
            messages[index].status = "running"
            if !display.isEmpty {
                messages[index].content = display
            }
            messages[index].timestamp = Date()
            activityText = "Running \(title)"
            appendLog(title, level: .info)
            updateFiles(from: update)
            return
        }
        messages.append(ChatMessage(
            id: id,
            role: .tool,
            title: title,
            timestamp: Date(),
            content: display,
            status: "running",
            kind: kind
        ))
        activityText = "Running \(title)"
        appendLog(title, level: .info)
        updateFiles(from: update)
    }

    private func handleToolUpdate(_ update: [String: Any]) {
        let id = update["tool_call_id"] as? String
            ?? update["toolCallId"] as? String
            ?? UUID().uuidString
        let status = update["status"] as? String ?? "running"
        let raw = update["raw_output"] as? String
            ?? update["rawOutput"] as? String
            ?? textContent(from: update)
        let display = toolUpdateDisplay(status: status, raw: raw)
        if let index = messages.firstIndex(where: { $0.id == id && $0.role == .tool }) {
            messages[index].status = status
            if !display.isEmpty {
                messages[index].content = display
            }
            messages[index].timestamp = Date()
        } else {
            messages.append(ChatMessage(
                id: id,
                role: .tool,
                title: update["title"] as? String ?? "Tool update",
                timestamp: Date(),
                content: display,
                status: status,
                kind: update["kind"] as? String
            ))
        }
        activityText = status == "failed" ? "Tool failed" : "Completed tool step"
        appendLog(raw.isEmpty ? "Tool \(status)" : raw, level: status == "failed" ? .error : .success)
        updateFiles(from: update)
    }

    private func handlePlan(_ update: [String: Any]) {
        let raw = update["raw_output"] as? String
            ?? update["rawOutput"] as? String
            ?? textContent(from: update)
        todos = raw
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { line in
                let completed = line.hasPrefix("[x]") || line.hasPrefix("✓")
                return TodoItem(text: line.replacingOccurrences(of: "[ ]", with: "").replacingOccurrences(of: "[x]", with: ""), completed: completed)
            }
    }

    private func updateFiles(from update: [String: Any]) {
        let locations = update["locations"] as? [[String: Any]]
            ?? update["fileLocations"] as? [[String: Any]]
            ?? []
        for location in locations {
            guard let path = location["path"] as? String else { continue }
            addProjectFile(path)
        }

        let raw = update["raw_input"] as? String
            ?? update["rawInput"] as? String
            ?? update["raw_output"] as? String
            ?? update["rawOutput"] as? String
            ?? textContent(from: update)
        for path in Self.extractPaths(from: raw) {
            addProjectFile(path)
        }
    }

    private func toolStartDisplay(title: String, raw: String) -> String {
        let paths = Self.extractPaths(from: raw)
        var lines = ["Running \(title)"]
        if !paths.isEmpty {
            lines.append(contentsOf: paths.map { "File: \($0)" })
        }
        if !raw.isEmpty && paths.isEmpty {
            lines.append(raw)
        }
        return lines.joined(separator: "\n")
    }

    private func toolUpdateDisplay(status: String, raw: String) -> String {
        var lines: [String] = []
        switch status {
        case "completed":
            lines.append("Done.")
        case "failed":
            lines.append("Failed.")
        default:
            lines.append(status.capitalized)
        }
        if !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append(raw)
        }
        return lines.joined(separator: "\n")
    }

    private func textContent(from update: [String: Any]) -> String {
        if let content = update["content"] as? [String: Any] {
            return content["text"] as? String ?? ""
        }
        if let contents = update["content"] as? [[String: Any]] {
            return contents.compactMap { item in
                if let content = item["content"] as? [String: Any] {
                    return content["text"] as? String
                }
                return item["text"] as? String
            }.joined(separator: "\n")
        }
        return ""
    }

    private func appendLog(_ text: String, level: LogLevel) {
        logs.append(ExecutionLog(date: Date(), text: text, level: level))
        if logs.count > 300 {
            logs.removeFirst(logs.count - 300)
        }
    }

    private func updateConfigOptions(from rawOptions: [[String: Any]]) {
        configOptions = rawOptions.compactMap { raw in
            guard let id = raw["id"] as? String else { return nil }
            let options = raw["options"] as? [[String: Any]] ?? []
            let currentValue = "\(raw["current_value"] ?? raw["currentValue"] ?? "")"
            let choices: [VibeConfigOption.Choice]
            if options.isEmpty, raw["type"] as? String == "boolean" {
                choices = [
                    VibeConfigOption.Choice(id: "true", name: "On"),
                    VibeConfigOption.Choice(id: "false", name: "Off"),
                ]
            } else {
                choices = options.compactMap { option in
                    guard let value = option["value"] as? String else { return nil }
                    return VibeConfigOption.Choice(
                        id: value,
                        name: option["name"] as? String ?? value
                    )
                }
            }
            return VibeConfigOption(
                id: id,
                category: raw["category"] as? String ?? id,
                currentValue: currentValue,
                choices: choices
            )
        }
    }

    private func updateConfigOption(id: String, value: String) {
        guard let index = configOptions.firstIndex(where: { $0.id == id }) else { return }
        configOptions[index].currentValue = value
    }

    private func updateChatSessions(from result: [String: Any]) {
        let rawSessions = result["sessions"] as? [[String: Any]] ?? []
        chatSessions = rawSessions.compactMap { raw in
            let id = raw["session_id"] as? String
                ?? raw["sessionId"] as? String
                ?? raw["id"] as? String
            guard let id else { return nil }
            return ChatSessionInfo(
                sessionID: id,
                title: raw["title"] as? String ?? "",
                cwd: raw["cwd"] as? String ?? "",
                updatedAt: raw["updated_at"] as? String
                    ?? raw["updatedAt"] as? String
                    ?? ""
            )
        }
    }

    private func updateVibeConfigSnapshot(from result: [String: Any]) {
        configPath = result["config_path"] as? String ?? configPath
        envPath = result["env_path"] as? String ?? envPath
        logPath = result["log_path"] as? String ?? logPath
        sessionLogDir = result["session_log_dir"] as? String ?? sessionLogDir
        activeProvider = result["active_provider"] as? String ?? activeProvider
        configRawText = result["raw_toml"] as? String ?? configRawText

        let scalars = result["scalars"] as? [[String: Any]] ?? []
        configScalars = scalars.compactMap { raw in
            guard let key = raw["key"] as? String else { return nil }
            let value = raw["value"]
            return VibeConfigScalar(
                key: key,
                description: raw["description"] as? String ?? "",
                value: Self.displayString(value),
                valueType: raw["value_type"] as? String ?? "",
                persisted: (raw["persisted"] as? NSNumber)?.boolValue ?? raw["persisted"] as? Bool ?? false
            )
        }

        let models = result["models"] as? [[String: Any]] ?? []
        configModels = models.compactMap { raw in
            guard let alias = raw["alias"] as? String else { return nil }
            return VibeConfigModel(
                alias: alias,
                name: raw["name"] as? String ?? "",
                provider: raw["provider"] as? String ?? "",
                thinking: raw["thinking"] as? String ?? "",
                temperature: Self.displayString(raw["temperature"]),
                threshold: Self.displayString(raw["auto_compact_threshold"]),
                active: (raw["active"] as? NSNumber)?.boolValue ?? raw["active"] as? Bool ?? false
            )
        }
        if let active = configModels.first(where: { $0.active }) {
            activeModelID = active.alias
        }

        let providers = result["providers"] as? [[String: Any]] ?? []
        configProviders = providers.compactMap { raw in
            guard let name = raw["name"] as? String else { return nil }
            return VibeConfigProvider(
                name: name,
                backend: raw["backend"] as? String ?? "",
                apiBase: raw["api_base"] as? String ?? "",
                apiKeyEnv: raw["api_key_env_var"] as? String ?? ""
            )
        }

        configMCPServers = Self.parseServers(result["mcp_servers"] as? [[String: Any]] ?? [])
        configConnectors = (result["connectors"] as? [[String: Any]] ?? []).compactMap { raw in
            guard let name = raw["name"] as? String else { return nil }
            return VibeConfigServer(
                name: name,
                transport: "connector",
                target: "\(raw["disabled_tools"] as? [String] ?? [])",
                disabled: (raw["disabled"] as? NSNumber)?.boolValue ?? raw["disabled"] as? Bool ?? false
            )
        }

        configEnvVars = (result["env_vars"] as? [[String: Any]] ?? []).compactMap { raw in
            guard let key = raw["key"] as? String else { return nil }
            return VibeEnvVar(
                key: key,
                set: (raw["set"] as? NSNumber)?.boolValue ?? raw["set"] as? Bool ?? false,
                maskedValue: raw["masked_value"] as? String ?? ""
            )
        }
    }

    private static func parseServers(_ rawServers: [[String: Any]]) -> [VibeConfigServer] {
        rawServers.compactMap { raw in
            let name = raw["name"] as? String ?? raw["url"] as? String ?? raw["command"] as? String ?? "server"
            let transport = raw["transport"] as? String ?? ""
            let target = raw["url"] as? String
                ?? raw["command"] as? String
                ?? (raw["args"] as? [String])?.joined(separator: " ")
                ?? ""
            return VibeConfigServer(
                name: name,
                transport: transport,
                target: target,
                disabled: (raw["disabled"] as? NSNumber)?.boolValue ?? raw["disabled"] as? Bool ?? false
            )
        }
    }

    private static func displayString(_ value: Any?) -> String {
        if value == nil || value is NSNull { return "" }
        if let bool = value as? Bool { return bool ? "true" : "false" }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "true" : "false"
            }
            return "\(number)"
        }
        if let string = value as? String { return string }
        return String(describing: value!)
    }

    private func tickDuration() {
        duration = Self.formatDuration(Date().timeIntervalSince(startDate))
    }

    private static func formatDuration(_ interval: TimeInterval) -> String {
        let seconds = Int(interval)
        if seconds < 60 { return "\(seconds)s" }
        return "\(seconds / 60)m \(seconds % 60)s"
    }

    private static func formatNumber(_ number: Int) -> String {
        if number >= 1000 {
            let value = Double(number) / 1000.0
            if number % 1000 == 0 {
                return "\(Int(value))k"
            }
            return String(format: "%.1fk", value)
        }
        return "\(number)"
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        if bytes >= 1_048_576 {
            return String(format: "%.1f MB", Double(bytes) / 1_048_576.0)
        }
        if bytes >= 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        }
        return "\(bytes) B"
    }

    private static func extractPaths(from raw: String) -> [String] {
        guard !raw.isEmpty else { return [] }
        var paths: [String] = []
        if let data = raw.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["path", "file_path", "filePath", "file"] {
                if let path = object[key] as? String {
                    paths.append(path)
                }
            }
        }

        let pattern = #"((?:/|~/|\./|\.\./)[A-Za-z0-9_\-./~ ]+\.(?:html|css|js|ts|tsx|jsx|py|swift|md|txt|json|toml|yaml|yml|rs|go|java|kt|c|h|cpp|hpp|sh|zsh))"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(raw.startIndex..<raw.endIndex, in: raw)
            regex.matches(in: raw, range: range).forEach { match in
                guard let range = Range(match.range(at: 1), in: raw) else { return }
                paths.append(Self.cleanedPath(String(raw[range])))
            }
        }

        var unique: [String] = []
        for path in paths.map(Self.cleanedPath) where Self.isPlausiblePath(path) && !unique.contains(path) {
            unique.append(path)
        }
        return unique
    }

    private static func cleanedPath(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'`,.;:)("))
    }

    private static func isPlausiblePath(_ path: String) -> Bool {
        guard !path.isEmpty else { return false }
        return path.hasPrefix("/")
            || path.hasPrefix("~/")
            || path.hasPrefix("./")
            || path.hasPrefix("../")
    }

    private static func readEmbeddableText(from url: URL, size: Int64, mimeType: String) -> String? {
        guard size <= 512 * 1024 else { return nil }
        let textualMime = mimeType.hasPrefix("text/")
            || ["application/json", "application/xml", "application/x-yaml", "application/toml"].contains(mimeType)
        let textualExtension = ["md", "txt", "json", "yaml", "yml", "toml", "swift", "py", "js", "ts", "tsx", "jsx", "html", "css", "rs", "go", "java", "kt", "c", "h", "cpp", "hpp", "sh", "zsh", "rb", "php", "sql"].contains(url.pathExtension.lowercased())
        guard textualMime || textualExtension else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
