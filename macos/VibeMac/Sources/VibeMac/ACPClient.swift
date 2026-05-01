import Foundation

final class ACPClient {
    private final class TerminalRecord {
        let id: String
        let process: Process
        let outputLimit: Int?
        var output = Data()
        var truncated = false
        var exitCode: Int32?
        var waiters: [AnyHashable] = []

        init(id: String, process: Process, outputLimit: Int?) {
            self.id = id
            self.process = process
            self.outputLimit = outputLimit
        }
    }

    private let configuration: CLIConfiguration
    private weak var model: AppModel?
    private let process = Process()
    private let stdin = Pipe()
    private let stdout = Pipe()
    private let stderr = Pipe()
    private let sendQueue = DispatchQueue(label: "vibe.acp.send")
    private let terminalQueue = DispatchQueue(label: "vibe.acp.terminals")
    private var nextID = 1
    private var sessionID: String?
    private var lineBuffer = Data()
    private var terminals: [String: TerminalRecord] = [:]
    private var pendingMethods: [Int: String] = [:]

    init(configuration: CLIConfiguration, model: AppModel) {
        self.configuration = configuration
        self.model = model
    }

    func start() {
        configureBackendProcess()
        process.currentDirectoryURL = configuration.repoRoot
        var environment = ProcessInfo.processInfo.environment
        environment["VIBE_MACOS_FRONTEND"] = "swift-native"
        environment["VIBE_HOME"] = configuration.vibeHome.path
        environment["VIBE_CONFIG_SOURCE"] = "user"
        environment["PYTHONPATH"] = pythonPath(with: environment["PYTHONPATH"])
        environment["PATH"] = backendPath(with: environment["PATH"])
        process.environment = environment
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            self?.consume(handle.availableData)
        }
        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let text = String(data: handle.availableData, encoding: .utf8), !text.isEmpty else { return }
            Task { @MainActor in self?.model?.logs.append(ExecutionLog(date: Date(), text: text.trimmingCharacters(in: .whitespacesAndNewlines), level: .warning)) }
        }
        process.terminationHandler = { [weak self] process in
            Task { @MainActor in
                self?.model?.logs.append(ExecutionLog(date: Date(), text: "ACP backend exited with status \(process.terminationStatus)", level: process.terminationStatus == 0 ? .info : .error))
                if self?.model?.status == "Running" || self?.model?.status == "Starting" {
                    self?.model?.status = "Backend exited"
                }
            }
        }

        do {
            try process.run()
            initialize()
        } catch {
            Task { @MainActor in
                self.model?.status = "Backend failed"
                self.model?.logs.append(ExecutionLog(date: Date(), text: "Failed to start ACP backend: \(error)", level: .error))
            }
        }
    }

    func stop() {
        stdout.fileHandleForReading.readabilityHandler = nil
        stderr.fileHandleForReading.readabilityHandler = nil
        terminalQueue.sync {
            for terminal in terminals.values where terminal.process.isRunning {
                terminal.process.terminate()
            }
            terminals.removeAll()
        }
        if process.isRunning {
            process.terminate()
        }
    }

    func sendPrompt(_ text: String, attachments: [PromptAttachment] = []) -> Bool {
        guard let sessionID else {
            Task { @MainActor in
                self.model?.logs.append(ExecutionLog(date: Date(), text: "Prompt not sent: ACP session is not ready", level: .error))
                self.model?.status = "Not ready"
            }
            return false
        }
        var promptBlocks: [[String: Any]] = []
        if !text.isEmpty {
            promptBlocks.append([
                "type": "text",
                "text": text,
                "annotations": NSNull(),
                "field_meta": NSNull(),
            ])
        }
        promptBlocks.append(contentsOf: attachments.map(promptBlock(for:)))
        send(method: "session/prompt", params: [
            "session_id": sessionID,
            "prompt": promptBlocks,
            "field_meta": NSNull(),
            "message_id": NSNull(),
        ])
        return true
    }

    func cancelPrompt() {
        guard let sessionID else { return }
        sendNotification(method: "session/cancel", params: [
            "session_id": sessionID,
        ])
    }

    func setConfigOption(_ optionID: String, value: String) {
        guard let sessionID else { return }
        send(method: "session/set_config_option", params: [
            "sessionId": sessionID,
            "configId": optionID,
            "value": value,
            "type": "select",
        ])
    }

    func setSessionMode(_ modeID: String) {
        guard let sessionID else { return }
        send(method: "session/set_mode", params: [
            "sessionId": sessionID,
            "modeId": modeID,
        ])
    }

    func setSessionModel(_ modelID: String) {
        guard let sessionID else { return }
        send(method: "session/set_model", params: [
            "sessionId": sessionID,
            "modelId": modelID,
        ])
    }

    func requestVibeConfig() {
        send(method: "_vibe/config/inspect", params: extensionParams())
    }

    func setVibeConfigValue(key: String, value: Any) {
        var params = extensionParams()
        params["key"] = key
        params["value"] = value
        send(method: "_vibe/config/set", params: params)
    }

    func saveVibeConfigRaw(_ toml: String) {
        var params = extensionParams()
        params["toml"] = toml
        send(method: "_vibe/config/save_raw", params: params)
    }

    func reloadVibeConfig() {
        send(method: "_vibe/config/reload", params: extensionParams())
    }

    func setVibeEnv(key: String, value: String) {
        var params = extensionParams()
        params["key"] = key
        params["value"] = value
        send(method: "_vibe/env/set", params: params)
    }

    func createNewSession() {
        newSession()
    }

    func listSessions(cwd: String) {
        send(method: "session/list", params: [
            "cwd": cwd,
            "cursor": NSNull(),
            "field_meta": NSNull(),
        ])
    }

    func loadSession(sessionID: String, cwd: String) {
        self.sessionID = sessionID
        send(method: "session/load", params: [
            "cwd": cwd,
            "sessionId": sessionID,
            "mcp_servers": [],
            "field_meta": NSNull(),
        ])
    }

    func respondPermission(id: AnyHashable, optionID: String) {
        sendResponse(id: id, result: [
            "outcome": [
                "outcome": "selected",
                "option_id": optionID,
                "optionId": optionID,
            ]
        ])
    }

    func respondReadTextFile(_ request: [String: Any]) {
        let id = Self.messageID(from: request["id"])
        let params = request["params"] as? [String: Any] ?? [:]
        let path = params["path"] as? String ?? ""
        let line = (params["line"] as? NSNumber)?.intValue
        let limit = (params["limit"] as? NSNumber)?.intValue
        do {
            let url = URL(fileURLWithPath: path)
            var lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            if let line, line > 0 {
                lines = Array(lines.dropFirst(line - 1))
            }
            if let limit {
                lines = Array(lines.prefix(limit))
            }
            sendResponse(id: id, result: ["content": lines.joined(separator: "\n")])
        } catch {
            sendError(id: id, code: -32001, message: "Could not read \(path): \(error)")
        }
    }

    func respondWriteTextFile(_ request: [String: Any]) {
        let id = Self.messageID(from: request["id"])
        let params = request["params"] as? [String: Any] ?? [:]
        let path = params["path"] as? String ?? ""
        let content = params["content"] as? String ?? ""
        do {
            let url = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try content.write(to: url, atomically: true, encoding: .utf8)
            sendResponse(id: id, result: [:])
        } catch {
            sendError(id: id, code: -32002, message: "Could not write \(path): \(error)")
        }
    }

    func respondCreateTerminal(_ request: [String: Any]) {
        let id = Self.messageID(from: request["id"])
        let params = request["params"] as? [String: Any] ?? [:]
        guard let command = params["command"] as? String, !command.isEmpty else {
            sendError(id: id, code: -32602, message: "terminal/create requires a command")
            return
        }

        let terminalID = UUID().uuidString
        let outputLimit = (params["outputByteLimit"] as? NSNumber)?.intValue
            ?? (params["output_byte_limit"] as? NSNumber)?.intValue
        let outputPipe = Pipe()
        let terminalProcess = Process()
        let commandArgs = params["args"] as? [String] ?? []
        if commandArgs.isEmpty {
            terminalProcess.executableURL = URL(fileURLWithPath: "/bin/zsh")
            terminalProcess.arguments = ["-lc", command]
        } else {
            terminalProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            terminalProcess.arguments = [command] + commandArgs
        }
        terminalProcess.currentDirectoryURL = URL(
            fileURLWithPath: params["cwd"] as? String ?? configuration.workdir.path
        )
        terminalProcess.environment = terminalEnvironment(from: params["env"] as? [[String: Any]])
        terminalProcess.standardOutput = outputPipe
        terminalProcess.standardError = outputPipe

        let record = TerminalRecord(id: terminalID, process: terminalProcess, outputLimit: outputLimit)
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self, weak record] handle in
            let data = handle.availableData
            guard !data.isEmpty, let record else { return }
            self?.appendTerminalOutput(data, to: record)
        }
        terminalProcess.terminationHandler = { [weak self, weak record] process in
            guard let self, let record else { return }
            self.terminalQueue.async {
                record.exitCode = process.terminationStatus
                let waiters = record.waiters
                record.waiters.removeAll()
                waiters.forEach {
                    self.sendResponse(id: $0, result: [
                        "exitCode": max(0, Int(process.terminationStatus)),
                        "signal": NSNull(),
                    ])
                }
            }
        }

        do {
            terminalQueue.sync {
                terminals[terminalID] = record
            }
            try terminalProcess.run()
            sendResponse(id: id, result: ["terminalId": terminalID])
            Task { @MainActor in
                self.model?.logs.append(ExecutionLog(date: Date(), text: "Terminal started: \(command)", level: .info))
            }
        } catch {
            _ = terminalQueue.sync {
                terminals.removeValue(forKey: terminalID)
            }
            sendError(id: id, code: -32010, message: "Could not create terminal: \(error)")
        }
    }

    func respondTerminalOutput(_ request: [String: Any]) {
        let id = Self.messageID(from: request["id"])
        let terminalID = terminalID(from: request)
        terminalQueue.async {
            guard let record = self.terminals[terminalID] else {
                self.sendError(id: id, code: -32011, message: "Unknown terminal: \(terminalID)")
                return
            }
            let output = String(decoding: record.output, as: UTF8.self)
            let exitStatus: Any = record.exitCode.map {
                ["exitCode": max(0, Int($0)), "signal": NSNull()]
            } ?? NSNull()
            self.sendResponse(id: id, result: [
                "output": output,
                "truncated": record.truncated,
                "exitStatus": exitStatus,
            ])
        }
    }

    func respondWaitForTerminalExit(_ request: [String: Any]) {
        let id = Self.messageID(from: request["id"])
        let terminalID = terminalID(from: request)
        terminalQueue.async {
            guard let record = self.terminals[terminalID] else {
                self.sendError(id: id, code: -32011, message: "Unknown terminal: \(terminalID)")
                return
            }
            if let exitCode = record.exitCode {
                self.sendResponse(id: id, result: [
                    "exitCode": max(0, Int(exitCode)),
                    "signal": NSNull(),
                ])
            } else {
                record.waiters.append(id)
            }
        }
    }

    func respondKillTerminal(_ request: [String: Any]) {
        let id = Self.messageID(from: request["id"])
        let terminalID = terminalID(from: request)
        terminalQueue.async {
            guard let record = self.terminals[terminalID] else {
                self.sendError(id: id, code: -32011, message: "Unknown terminal: \(terminalID)")
                return
            }
            if record.process.isRunning {
                record.process.terminate()
            }
            self.sendResponse(id: id, result: [:])
        }
    }

    func respondReleaseTerminal(_ request: [String: Any]) {
        let id = Self.messageID(from: request["id"])
        let terminalID = terminalID(from: request)
        terminalQueue.async {
            guard let record = self.terminals.removeValue(forKey: terminalID) else {
                self.sendResponse(id: id, result: [:])
                return
            }
            if record.process.isRunning {
                record.process.terminate()
            }
            self.sendResponse(id: id, result: [:])
        }
    }

    func respondMethodNotFound(_ request: [String: Any]) {
        sendError(id: Self.messageID(from: request["id"]), code: -32601, message: "Method not found")
    }

    private func configureBackendProcess() {
        let bundledStandalonePython = configuration.repoRoot.appendingPathComponent("Python/bin/python3.12")
        if FileManager.default.isExecutableFile(atPath: bundledStandalonePython.path) {
            process.executableURL = bundledStandalonePython
            process.arguments = ["-m", "vibe.acp.entrypoint"]
            return
        }

        let bundledPython = configuration.repoRoot.appendingPathComponent(".venv/bin/python")
        if FileManager.default.isExecutableFile(atPath: bundledPython.path) {
            process.executableURL = bundledPython
            process.arguments = ["-m", "vibe.acp.entrypoint"]
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["uv", "run", "python", "-m", "vibe.acp.entrypoint"]
        }
    }

    private func pythonPath(with existingValue: String?) -> String {
        let sitePackages = configuration.repoRoot.appendingPathComponent(".venv/lib/python3.12/site-packages")
        let localPaths = FileManager.default.fileExists(atPath: sitePackages.path)
            ? [configuration.repoRoot.path, sitePackages.path]
            : [configuration.repoRoot.path]
        if let existingValue, !existingValue.isEmpty {
            return (localPaths + [existingValue]).joined(separator: ":")
        }
        return localPaths.joined(separator: ":")
    }

    private func backendPath(with existingValue: String?) -> String {
        let paths = [
            configuration.repoRoot.appendingPathComponent(".venv/bin").path,
            configuration.repoRoot.appendingPathComponent("Python/bin").path,
        ].filter { FileManager.default.fileExists(atPath: $0) }
        guard !paths.isEmpty else { return existingValue ?? "" }
        if let existingValue, !existingValue.isEmpty {
            return (paths + [existingValue]).joined(separator: ":")
        }
        return paths.joined(separator: ":")
    }

    static func messageID(from value: Any?) -> AnyHashable {
        if let int = value as? Int { return AnyHashable(int) }
        if let number = value as? NSNumber { return AnyHashable(number.intValue) }
        if let string = value as? String { return AnyHashable(string) }
        return AnyHashable(UUID().uuidString)
    }

    private func initialize() {
        send(method: "initialize", params: [
            "protocol_version": 1,
            "client_capabilities": [
                "terminal": true,
                "auth": ["terminal": false],
                "fs": [
                    "read_text_file": true,
                    "write_text_file": true,
                    "field_meta": NSNull(),
                ],
                "field_meta": NSNull(),
            ],
            "client_info": [
                "name": "vibe-mac",
                "title": "Vibe Mac",
                "version": "0.1.0",
            ],
            "field_meta": NSNull(),
        ], explicitID: 1)
    }

    private func newSession() {
        send(method: "session/new", params: [
            "cwd": configuration.workdir.path,
            "mcp_servers": [],
            "field_meta": NSNull(),
        ], explicitID: 2)
    }

    private func extensionParams() -> [String: Any] {
        var params: [String: Any] = ["field_meta": NSNull()]
        params["session_id"] = sessionID ?? NSNull()
        return params
    }

    @discardableResult
    private func send(method: String, params: Any, explicitID: Int? = nil) -> Int {
        let id = explicitID ?? allocateID()
        if let explicitID, explicitID >= nextID {
            nextID = explicitID + 1
        }
        pendingMethods[id] = method
        sendObject([
            "jsonrpc": "2.0",
            "id": id,
            "method": method,
            "params": params,
        ])
        return id
    }

    private func sendResponse(id: AnyHashable, result: Any) {
        sendObject([
            "jsonrpc": "2.0",
            "id": jsonCompatibleID(id),
            "result": result,
        ])
    }

    private func sendNotification(method: String, params: Any) {
        sendObject([
            "jsonrpc": "2.0",
            "method": method,
            "params": params,
        ])
    }

    private func sendError(id: AnyHashable, code: Int, message: String) {
        sendObject([
            "jsonrpc": "2.0",
            "id": jsonCompatibleID(id),
            "error": [
                "code": code,
                "message": message,
            ],
        ])
    }

    private func sendObject(_ object: [String: Any]) {
        sendQueue.async {
            guard JSONSerialization.isValidJSONObject(object),
                  let data = try? JSONSerialization.data(withJSONObject: object) else { return }
            var payload = data
            payload.append(0x0A)
            self.stdin.fileHandleForWriting.write(payload)
        }
    }

    private func allocateID() -> Int {
        defer { nextID += 1 }
        return nextID
    }

    private func consume(_ data: Data) {
        guard !data.isEmpty else { return }
        lineBuffer.append(data)
        while let newline = lineBuffer.firstIndex(of: 0x0A) {
            let line = lineBuffer[..<newline]
            lineBuffer.removeSubrange(...newline)
            guard !line.isEmpty,
                  let json = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any] else { continue }
            handle(json)
        }
    }

    private func handle(_ json: [String: Any]) {
        if let method = json["method"] as? String {
            if method == "session/update",
               let params = json["params"] as? [String: Any],
               let update = params["update"] as? [String: Any] {
                Task { @MainActor in self.model?.handleACPUpdate(update) }
            } else {
                Task { @MainActor in self.model?.handleBackendRequest(json) }
            }
            return
        }

        guard let id = json["id"] else { return }
        let result = json["result"] as? [String: Any] ?? [:]
        if let intID = Self.intID(from: id), intID == 1 {
            pendingMethods.removeValue(forKey: intID)
            Task { @MainActor in self.model?.handleInitialized(result) }
            newSession()
        } else if let intID = Self.intID(from: id), intID == 2 {
            pendingMethods.removeValue(forKey: intID)
            sessionID = result["session_id"] as? String ?? result["sessionId"] as? String
            Task { @MainActor in self.model?.handleNewSession(result) }
        } else {
            let methodName = Self.intID(from: id).flatMap { pendingMethods.removeValue(forKey: $0) }
            if methodName == "session/new" || methodName == "session/load" {
                let result = json["result"] as? [String: Any] ?? [:]
                sessionID = result["session_id"] as? String
                    ?? result["sessionId"] as? String
                    ?? sessionID
            }
            let error = json["error"] as? [String: Any]
            Task { @MainActor in
                self.model?.handleRPCResponse(
                    id: id,
                    method: methodName,
                    result: json["result"],
                    error: error
                )
            }
        }
    }

    private func jsonCompatibleID(_ id: AnyHashable) -> Any {
        if let value = id.base as? Int { return value }
        if let value = id.base as? String { return value }
        return String(describing: id.base)
    }

    private static func intID(from value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String { return Int(string) }
        return nil
    }

    private func appendTerminalOutput(_ data: Data, to record: TerminalRecord) {
        terminalQueue.async {
            record.output.append(data)
            guard let limit = record.outputLimit, limit >= 0, record.output.count > limit else { return }
            record.output.removeFirst(record.output.count - limit)
            record.truncated = true
        }
    }

    private func terminalEnvironment(from env: [[String: Any]]?) -> [String: String] {
        var result = ProcessInfo.processInfo.environment
        result["PATH"] = backendPath(with: result["PATH"])
        result["PYTHONPATH"] = pythonPath(with: result["PYTHONPATH"])
        env?.forEach { item in
            guard let name = item["name"] as? String,
                  let value = item["value"] as? String else { return }
            result[name] = value
        }
        return result
    }

    private func terminalID(from request: [String: Any]) -> String {
        let params = request["params"] as? [String: Any] ?? [:]
        return params["terminalId"] as? String
            ?? params["terminal_id"] as? String
            ?? ""
    }

    private func promptBlock(for attachment: PromptAttachment) -> [String: Any] {
        let uri = attachment.url.absoluteString
        if let text = attachment.embeddedText {
            return [
                "type": "resource",
                "resource": [
                    "uri": uri,
                    "text": text,
                    "mimeType": attachment.mimeType,
                    "field_meta": NSNull(),
                ],
                "annotations": NSNull(),
                "field_meta": NSNull(),
            ]
        }
        return [
            "type": "resource_link",
            "uri": uri,
            "name": attachment.name,
            "title": attachment.name,
            "description": "Attached file from Vibe Mac",
            "mimeType": attachment.mimeType,
            "size": attachment.size,
            "annotations": NSNull(),
            "field_meta": NSNull(),
        ]
    }
}
