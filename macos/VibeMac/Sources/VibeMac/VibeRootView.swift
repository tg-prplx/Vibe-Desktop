import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct VibeRootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            if model.leftSidebarCollapsed {
                CollapsedSidebarView(model: model)
                    .frame(width: 58)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                DividerLine()
            } else {
                SidebarView(model: model)
                    .frame(width: 250)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                DividerLine()
            }
            CenterPane(model: model)
                .frame(minWidth: 320)
                .transition(.opacity)
            if model.inspectorCollapsed {
                DividerLine()
                CollapsedInspectorRail(model: model)
                    .frame(width: 52)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                DividerLine()
                InspectorView(model: model)
                    .frame(width: 370)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background(VibeTheme.swiftBackground)
        .ignoresSafeArea()
        .foregroundStyle(VibeTheme.swiftForeground)
        .font(.system(size: 14, weight: .regular))
        .animation(.easeInOut(duration: 0.18), value: model.leftSidebarCollapsed)
        .animation(.easeInOut(duration: 0.18), value: model.inspectorCollapsed)
        .animation(.easeInOut(duration: 0.16), value: model.selectedSection)
        .frame(minWidth: 940, minHeight: 640)
    }
}

struct CenterPane: View {
    @ObservedObject var model: AppModel

    var body: some View {
        switch model.selectedSection {
        case .commands:
            CommandsPane(model: model)
        case .files:
            CodeEditorPane(model: model)
        case .settings:
            SettingsPane(model: model)
        case .logs:
            LogsPane(model: model)
        case .chats:
            MainChatView(model: model)
        }
    }
}

struct SidebarView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Text("Vibe")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(VibeTheme.swiftForeground)
                Spacer()
                IconButton(systemName: "sidebar.left") {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        model.leftSidebarCollapsed = true
                    }
                }
            }
            .padding(.leading, 78)
            .padding(.trailing, 16)
            .frame(height: 58, alignment: .center)

            VStack(spacing: 5) {
                ForEach(SidebarSection.allCases) { section in
                    SidebarRow(
                        title: section.rawValue,
                        icon: section.icon,
                        selected: model.selectedSection == section,
                        badge: section == .chats ? "\(max(1, model.messages.filter { $0.role == .user }.count))" : nil
                    ) {
                        model.selectSection(section)
                    }
                }
            }
            .padding(.horizontal, 10)

            ChatManagerSidebar(model: model)
                .padding(.horizontal, 10)
                .frame(maxHeight: .infinity, alignment: .top)
                .layoutPriority(1)

            SidebarCard(title: "MODEL") {
                Text(model.modelName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VibeTheme.swiftOrange)
                Text(model.activeModelID)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(VibeTheme.swiftForeground)
                    .lineLimit(1)
            }

            SidebarCard(title: "TOKENS") {
                Text("240k context window")
                    .foregroundStyle(VibeTheme.swiftMuted)
                ProgressView(value: model.tokenProgress)
                    .tint(VibeTheme.swiftOrange)
                HStack {
                    Text("\(Int(model.tokenProgress * 100))% used")
                    Spacer()
                    Text(model.tokenText)
                }
                .font(.system(size: 12))
                .foregroundStyle(VibeTheme.swiftMuted)
            }

            HStack(spacing: 8) {
                Circle().fill(VibeTheme.swiftGreen).frame(width: 7, height: 7)
                Text("Vibe v2.9.3")
                    .foregroundStyle(VibeTheme.swiftMuted)
                    .font(.system(size: 12))
            }
            .padding(14)
        }
        .background(VibeTheme.swiftSidebar)
    }
}

struct CollapsedSidebarView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 58)
            IconButton(systemName: "sidebar.right") {
                withAnimation(.easeInOut(duration: 0.18)) {
                    model.leftSidebarCollapsed = false
                }
            }
            ForEach(SidebarSection.allCases) { section in
                Button {
                    model.selectSection(section)
                } label: {
                    Image(systemName: section.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(model.selectedSection == section ? VibeTheme.swiftOrange : VibeTheme.swiftMuted)
                        .frame(width: 36, height: 36)
                        .background(model.selectedSection == section ? VibeTheme.swiftSelection : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Circle().fill(VibeTheme.swiftGreen).frame(width: 7, height: 7)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity)
        .background(VibeTheme.swiftSidebar)
    }
}

struct ChatManagerSidebar: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("CHATS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(VibeTheme.swiftMuted)
                Spacer()
                Button {
                    model.newChat()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("New chat")
                Button {
                    model.listChatSessions()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Refresh chats")
            }

            if model.chatSessions.isEmpty {
                Text(model.chatListStatus)
                    .font(.system(size: 11))
                    .foregroundStyle(VibeTheme.swiftMuted)
                    .lineLimit(2)
                    .padding(.vertical, 4)
            } else {
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(model.chatSessions) { session in
                            ChatSessionRow(
                                session: session,
                                active: session.sessionID == model.activeSessionID
                            ) {
                                model.loadChatSession(session)
                            }
                        }
                    }
                    .padding(.trailing, 2)
                }
                .scrollIndicators(.visible)
                .frame(minHeight: 80)
            }
        }
        .padding(10)
        .background(VibeTheme.swiftPanel)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(VibeTheme.swiftBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onAppear { model.listChatSessions() }
    }
}

struct ChatSessionRow: View {
    let session: ChatSessionInfo
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(active ? VibeTheme.swiftOrange : VibeTheme.swiftMuted)
                    .frame(width: 6, height: 6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.displayTitle)
                        .font(.system(size: 12, weight: active ? .bold : .medium))
                        .foregroundStyle(active ? VibeTheme.swiftForeground : VibeTheme.swiftMuted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(session.updatedAt.isEmpty ? session.cwd : session.updatedAt)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(VibeTheme.swiftMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 6)
            .background(active ? VibeTheme.swiftSelection : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct CommandsPane: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            TopBar(model: model)
            DividerLine(horizontal: true)
            HStack {
                Text("Commands")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if model.availableCommands.isEmpty {
                        EmptyState(title: "Commands are loading", detail: "Vibe will publish available commands after the ACP session starts.")
                    } else {
                        ForEach(model.availableCommands, id: \.name) { command in
                            CommandListRow(command: command) {
                                model.sendSlashCommand(command.name)
                            }
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 18)
            }
        }
        .background(VibeTheme.swiftWorkspace)
    }
}

struct LogsPane: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            TopBar(model: model)
            DividerLine(horizontal: true)
            HStack {
                Text("Execution Logs")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    if model.logs.isEmpty {
                        EmptyState(title: "No logs yet", detail: "Backend and tool activity will appear here.")
                    } else {
                        ForEach(model.logs) { log in
                            HStack(alignment: .top, spacing: 10) {
                                Text(log.date, style: .time)
                                    .foregroundStyle(VibeTheme.swiftMuted)
                                    .frame(width: 72, alignment: .leading)
                                Text(log.text)
                                    .foregroundStyle(logColor(log.level))
                                    .textSelection(.enabled)
                                Spacer()
                            }
                            .font(.system(size: 12, design: .monospaced))
                            .padding(.vertical, 5)
                            .padding(.horizontal, 10)
                            .background(VibeTheme.swiftPanel)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 18)
            }
        }
        .background(VibeTheme.swiftWorkspace)
    }

    private func logColor(_ level: LogLevel) -> Color {
        switch level {
        case .info: return VibeTheme.swiftForeground
        case .success: return VibeTheme.swiftGreen
        case .warning: return VibeTheme.swiftYellow
        case .error: return VibeTheme.swiftRed
        }
    }
}

struct SettingsPane: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            TopBar(model: model)
            DividerLine(horizontal: true)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Vibe Configuration")
                        .font(.system(size: 16, weight: .bold))
                    Text(model.configPath.isEmpty ? model.configSyncStatus : model.configPath)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(VibeTheme.swiftMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                PlainActionButton(title: "Refresh", systemName: "arrow.clockwise") {
                    model.refreshVibeConfig()
                }
                PlainActionButton(title: "Reload", systemName: "bolt") {
                    model.reloadVibeConfig()
                }
                PlainActionButton(title: "Save TOML", systemName: "square.and.arrow.down") {
                    model.saveRawVibeConfig()
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ConfigOverviewStrip(model: model)
                    ConfigModelsSection(model: model)
                    ConfigScalarSection(model: model)
                    ConfigInfrastructureSection(model: model)
                    ConfigEnvSection(model: model)
                    ConfigRawSection(model: model)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 22)
            }
        }
        .background(VibeTheme.swiftWorkspace)
        .onAppear { model.refreshVibeConfig() }
    }
}

struct CodeEditorPane: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            TopBar(model: model)
            DividerLine(horizontal: true)
            HStack(spacing: 0) {
                CodeFileBrowser(model: model)
                    .frame(width: 300)
                DividerLine()
                CodeEditorSurface(model: model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(VibeTheme.swiftWorkspace)
        .onAppear { model.refreshCodeFiles() }
    }
}

struct CodeFileBrowser: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Files")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                IconButton(systemName: "arrow.clockwise") {
                    model.refreshCodeFiles()
                }
            }
            TextField("Search files", text: $model.fileSearch)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(VibeTheme.swiftPanelElevated)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(VibeTheme.swiftBorder, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text("\(model.filteredCodeFiles.count) indexed")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(VibeTheme.swiftMuted)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    if model.filteredCodeFiles.isEmpty {
                        EmptySettingsText("No editable text files found")
                    } else {
                        ForEach(model.filteredCodeFiles) { file in
                            CodeFileRow(
                                file: file,
                                selected: model.selectedCodeFile?.path == file.path
                            ) {
                                model.openCodeFile(file)
                            }
                        }
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .padding(14)
        .background(VibeTheme.swiftSidebar)
    }
}

struct CodeFileRow: View {
    let file: CodeFileItem
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(selected ? VibeTheme.swiftOrange : VibeTheme.swiftMuted)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                        .font(.system(size: 12, weight: selected ? .bold : .medium))
                        .foregroundStyle(selected ? VibeTheme.swiftForeground : VibeTheme.swiftMuted)
                        .lineLimit(1)
                    Text(file.relativePath)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(VibeTheme.swiftMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(selected ? VibeTheme.swiftSelection : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        switch file.kind {
        case "swift": "swift"
        case "json", "toml", "yaml", "yml": "curlybraces"
        case "md": "doc.richtext"
        case "css", "scss": "paintbrush"
        default: "doc.text"
        }
    }
}

struct CodeEditorSurface: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.selectedCodeFile?.name ?? "No file selected")
                        .font(.system(size: 15, weight: .bold))
                    Text(model.selectedCodeFile?.relativePath ?? model.editorStatus)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(VibeTheme.swiftMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if model.editorDirty {
                    Text("edited")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(VibeTheme.swiftOrange)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(VibeTheme.swiftSelection)
                        .clipShape(Capsule())
                }
                Spacer()
                Button("Reveal") { model.revealCodeFile() }
                    .buttonStyle(.bordered)
                    .disabled(model.selectedCodeFile == nil)
                Button("Attach") { model.attachCodeFile() }
                    .buttonStyle(.bordered)
                    .disabled(model.selectedCodeFile == nil)
                Button("Revert") { model.revertCodeFile() }
                    .buttonStyle(.bordered)
                    .disabled(!model.editorDirty)
                Button("Save") { model.saveCodeFile() }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.selectedCodeFile == nil || !model.editorDirty || !model.editorError.isEmpty)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            DividerLine(horizontal: true)

            if !model.editorError.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Editor unavailable", systemImage: "exclamationmark.triangle")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(VibeTheme.swiftYellow)
                    Text(model.editorError)
                        .foregroundStyle(VibeTheme.swiftMuted)
                }
                .padding(18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if model.selectedCodeFile == nil {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Open a file to edit")
                        .font(.system(size: 20, weight: .bold))
                    Text("Select a text file from the project index. Large and binary files stay protected.")
                        .foregroundStyle(VibeTheme.swiftMuted)
                }
                .padding(28)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                HighlightedCodeEditor(
                    text: $model.editorText,
                    fileKind: model.selectedCodeFile?.kind ?? ""
                )
                    .background(VibeTheme.swiftTerminalBackground)
            }

            DividerLine(horizontal: true)
            HStack {
                Text(model.editorStatus)
                    .foregroundStyle(VibeTheme.swiftMuted)
                    .lineLimit(1)
                Spacer()
                if let file = model.selectedCodeFile {
                    Text("\(file.kind.uppercased()) · \(Self.formatBytes(file.size))")
                        .foregroundStyle(VibeTheme.swiftMuted)
                }
            }
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
        }
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        if bytes < 1_024 { return "\(bytes) B" }
        if bytes < 1_048_576 { return String(format: "%.1f KB", Double(bytes) / 1_024) }
        return String(format: "%.1f MB", Double(bytes) / 1_048_576)
    }
}

struct HighlightedCodeEditor: NSViewRepresentable {
    @Binding var text: String
    let fileKind: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = VibeTheme.terminalBackground

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width, .height]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: 10_000_000)
        textView.textContainer?.widthTracksTextView = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.allowsUndo = true
        textView.font = Coordinator.editorFont
        textView.textColor = VibeTheme.terminalForeground
        textView.backgroundColor = VibeTheme.terminalBackground
        textView.insertionPointColor = VibeTheme.terminalForeground
        textView.textContainerInset = NSSize(width: 14, height: 14)
        textView.delegate = context.coordinator
        textView.string = text

        context.coordinator.applyHighlighting(to: textView, kind: fileKind)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = clampedRanges(selectedRanges, length: (text as NSString).length)
        }
        context.coordinator.applyHighlighting(to: textView, kind: fileKind)
    }

    private func clampedRanges(_ ranges: [NSValue], length: Int) -> [NSValue] {
        ranges.map { value in
            let range = value.rangeValue
            let location = min(range.location, length)
            let available = max(0, length - location)
            return NSValue(range: NSRange(location: location, length: min(range.length, available)))
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        static let editorFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        var parent: HighlightedCodeEditor
        private var applyingHighlight = false

        init(_ parent: HighlightedCodeEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !applyingHighlight, let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            applyHighlighting(to: textView, kind: parent.fileKind)
        }

        func applyHighlighting(to textView: NSTextView, kind: String) {
            guard let storage = textView.textStorage else { return }
            let source = textView.string as NSString
            let fullRange = NSRange(location: 0, length: source.length)
            guard fullRange.length > 0 else { return }

            applyingHighlight = true
            let selectedRanges = textView.selectedRanges
            storage.beginEditing()
            storage.setAttributes(baseAttributes, range: fullRange)
            highlight(pattern: commentPattern(for: kind), color: VibeTheme.mutedText, storage: storage, source: source)
            highlight(pattern: stringPattern, color: VibeTheme.green, storage: storage, source: source)
            highlight(pattern: numberPattern, color: VibeTheme.yellow, storage: storage, source: source)
            highlight(pattern: keywordPattern(for: kind), color: VibeTheme.mistralOrange, weight: .semibold, storage: storage, source: source)
            storage.endEditing()
            textView.selectedRanges = selectedRanges
            applyingHighlight = false
        }

        private var baseAttributes: [NSAttributedString.Key: Any] {
            [
                .font: Self.editorFont,
                .foregroundColor: VibeTheme.terminalForeground,
                .backgroundColor: VibeTheme.terminalBackground
            ]
        }

        private let stringPattern = #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#
        private let numberPattern = #"\b\d+(?:\.\d+)?\b"#

        private func commentPattern(for kind: String) -> String {
            switch kind.lowercased() {
            case "py", "rb", "sh", "bash", "zsh", "toml", "yaml", "yml":
                return #"(?m)#.*$"#
            default:
                return #"(?m)//.*$|/\*[\s\S]*?\*/"#
            }
        }

        private func keywordPattern(for kind: String) -> String {
            let common = ["return", "if", "else", "for", "while", "switch", "case", "break", "continue", "true", "false", "nil", "null", "try", "catch", "throw", "async", "await"]
            let languageSpecific: [String]
            switch kind.lowercased() {
            case "swift":
                languageSpecific = ["import", "struct", "class", "enum", "protocol", "extension", "func", "let", "var", "guard", "defer", "private", "public", "internal", "final", "some"]
            case "py":
                languageSpecific = ["from", "import", "def", "class", "with", "as", "elif", "except", "finally", "lambda", "yield", "pass", "None", "True", "False"]
            case "js", "jsx", "ts", "tsx":
                languageSpecific = ["import", "export", "from", "const", "let", "var", "function", "class", "interface", "type", "extends", "implements", "new", "this"]
            case "html", "xml":
                return #"</?[A-Za-z][A-Za-z0-9:-]*|[A-Za-z_:][-A-Za-z0-9_:.]*(?=\=)"#
            case "css", "scss":
                return #"(?m)[.#]?[A-Za-z_-][A-Za-z0-9_-]*(?=\s*[:{])"#
            default:
                languageSpecific = ["import", "export", "class", "struct", "func", "def", "const", "let", "var"]
            }
            return "\\b(\((common + languageSpecific).joined(separator: "|")))\\b"
        }

        private func highlight(
            pattern: String,
            color: NSColor,
            weight: NSFont.Weight = .regular,
            storage: NSTextStorage,
            source: NSString
        ) {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            let matches = regex.matches(in: source as String, range: NSRange(location: 0, length: source.length))
            let font = NSFont.monospacedSystemFont(ofSize: 13, weight: weight)
            for match in matches {
                storage.addAttributes([.foregroundColor: color, .font: font], range: match.range)
            }
        }
    }
}

struct ConfigOverviewStrip: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 1) {
            ConfigMetric(label: "Status", value: model.configSyncStatus, accent: VibeTheme.swiftGreen)
            ConfigMetric(label: "Active model", value: model.activeModelID, accent: VibeTheme.swiftOrange)
            ConfigMetric(label: "Provider", value: model.activeProvider.isEmpty ? "-" : model.activeProvider)
            ConfigMetric(label: "Vibe home", value: model.configuration.vibeHome.path)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(VibeTheme.swiftBorder, lineWidth: 1))
    }
}

struct ConfigMetric: View {
    let label: String
    let value: String
    var accent: Color?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(VibeTheme.swiftMuted)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: label == "Vibe home" ? .monospaced : .default))
                .foregroundStyle(accent ?? VibeTheme.swiftForeground)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VibeTheme.swiftPanel)
    }
}

struct ConfigModelsSection: View {
    @ObservedObject var model: AppModel

    var body: some View {
        SettingsSection(title: "MODELS", subtitle: "Active model and thinking are persisted through VibeConfig.") {
            if model.configModels.isEmpty {
                EmptySettingsText("No models loaded from config")
            } else {
                ForEach(model.configModels) { item in
                    HStack(spacing: 10) {
                        Image(systemName: item.active ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.active ? VibeTheme.swiftGreen : VibeTheme.swiftMuted)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text(item.alias)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(item.active ? VibeTheme.swiftOrange : VibeTheme.swiftForeground)
                                Text(item.provider)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(VibeTheme.swiftMuted)
                            }
                            Text("\(item.name) | thinking \(item.thinking) | temp \(item.temperature) | \(item.threshold) ctx")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(VibeTheme.swiftMuted)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Button(item.active ? "Active" : "Use") {
                            model.setConfigOption("model", value: item.alias)
                        }
                        .buttonStyle(.bordered)
                        .disabled(item.active)
                    }
                    .padding(.vertical, 7)
                    DividerLine(horizontal: true)
                }
            }
        }
    }
}

struct ConfigScalarSection: View {
    @ObservedObject var model: AppModel

    var body: some View {
        SettingsSection(title: "CORE SETTINGS", subtitle: "Top-level keys in ~/.vibe/config.toml.") {
            if model.configScalars.isEmpty {
                EmptySettingsText("Config fields will appear after backend initialization")
            } else {
                ForEach(model.configScalars) { scalar in
                    ConfigScalarRow(scalar: scalar, model: model)
                    DividerLine(horizontal: true)
                }
            }
        }
    }
}

struct ConfigScalarRow: View {
    let scalar: VibeConfigScalar
    @ObservedObject var model: AppModel
    @State private var draft = ""

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(scalar.key)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                    if scalar.persisted {
                        Text("persisted")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(VibeTheme.swiftGreen)
                    }
                }
                Text(scalar.description)
                    .font(.system(size: 11))
                    .foregroundStyle(VibeTheme.swiftMuted)
                    .lineLimit(1)
            }
            Spacer()
            if let boolValue = scalar.boolValue {
                Toggle("", isOn: Binding(
                    get: { boolValue },
                    set: { model.setVibeConfigValue(key: scalar.key, value: $0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            } else {
                TextField("", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .frame(width: 190)
                    .background(VibeTheme.swiftPanelElevated)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(VibeTheme.swiftBorder, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                Button("Save") {
                    model.setVibeConfigValue(key: scalar.key, value: draft)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 7)
        .onAppear { draft = scalar.value }
        .onChange(of: scalar.value) { draft = $0 }
    }
}

struct ConfigInfrastructureSection: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SettingsSection(title: "PROVIDERS", subtitle: "Backends and API endpoints.") {
                if model.configProviders.isEmpty {
                    EmptySettingsText("No providers configured")
                } else {
                    ForEach(model.configProviders) { provider in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(provider.name)
                                    .font(.system(size: 12, weight: .bold))
                                Spacer()
                                Text(provider.backend)
                                    .foregroundStyle(VibeTheme.swiftOrange)
                            }
                            Text(provider.apiBase)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(VibeTheme.swiftMuted)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            if !provider.apiKeyEnv.isEmpty {
                                Text(provider.apiKeyEnv)
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(VibeTheme.swiftMuted)
                            }
                        }
                        .padding(.vertical, 7)
                        DividerLine(horizontal: true)
                    }
                }
            }

            SettingsSection(title: "MCP / CONNECTORS", subtitle: "Loaded by the CLI infrastructure.") {
                if model.configMCPServers.isEmpty && model.configConnectors.isEmpty {
                    EmptySettingsText("No MCP servers or connectors configured")
                } else {
                    ForEach(model.configMCPServers + model.configConnectors) { server in
                        HStack(spacing: 9) {
                            Image(systemName: server.disabled ? "pause.circle" : "point.3.connected.trianglepath.dotted")
                                .foregroundStyle(server.disabled ? VibeTheme.swiftMuted : VibeTheme.swiftGreen)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(server.name)
                                    .font(.system(size: 12, weight: .bold))
                                Text("\(server.transport) \(server.target)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(VibeTheme.swiftMuted)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 7)
                        DividerLine(horizontal: true)
                    }
                }
            }
        }
    }
}

struct ConfigEnvSection: View {
    @ObservedObject var model: AppModel
    @State private var envKey = ""
    @State private var envValue = ""

    var body: some View {
        SettingsSection(title: "ENVIRONMENT", subtitle: model.envPath.isEmpty ? "~/.vibe/.env" : model.envPath) {
            HStack(spacing: 8) {
                TextField("MISTRAL_API_KEY", text: $envKey)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(8)
                    .background(VibeTheme.swiftPanelElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                SecureField("value", text: $envValue)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(8)
                    .background(VibeTheme.swiftPanelElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                Button("Set") {
                    model.setVibeEnv(key: envKey.trimmingCharacters(in: .whitespacesAndNewlines), value: envValue)
                    envValue = ""
                }
                .buttonStyle(.bordered)
                Button("Unset") {
                    model.setVibeEnv(key: envKey.trimmingCharacters(in: .whitespacesAndNewlines), value: "")
                    envValue = ""
                }
                .buttonStyle(.bordered)
            }
            if model.configEnvVars.isEmpty {
                EmptySettingsText("No env vars saved in .env")
            } else {
                ForEach(model.configEnvVars) { variable in
                    SummaryRow(label: variable.key, value: variable.maskedValue.isEmpty ? "empty" : variable.maskedValue)
                }
            }
        }
    }
}

struct ConfigRawSection: View {
    @ObservedObject var model: AppModel

    var body: some View {
        SettingsSection(title: "RAW CONFIG.TOML", subtitle: "Validated through VibeConfig before write.") {
            TextEditor(text: $model.configRawText)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(VibeTheme.swiftForeground)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 260)
                .background(VibeTheme.swiftTerminalBackground)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(VibeTheme.swiftBorder, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(VibeTheme.swiftMuted)
                Spacer()
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(VibeTheme.swiftMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            content
                .font(.system(size: 12))
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VibeTheme.swiftPanel)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(VibeTheme.swiftBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct EmptySettingsText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .foregroundStyle(VibeTheme.swiftMuted)
            .font(.system(size: 12))
    }
}

struct PlainActionButton: View {
    let title: String
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemName)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(VibeTheme.swiftPanelElevated)
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(VibeTheme.swiftBorder, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }
}

struct EmptyState: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            Text(detail)
                .foregroundStyle(VibeTheme.swiftMuted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VibeTheme.swiftPanel)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(VibeTheme.swiftBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct CommandListRow: View {
    let command: (name: String, description: String)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "command")
                    .foregroundStyle(VibeTheme.swiftOrange)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 3) {
                    Text(command.name)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(VibeTheme.swiftOrange)
                    if !command.description.isEmpty {
                        Text(command.description)
                            .font(.system(size: 13))
                            .foregroundStyle(VibeTheme.swiftMuted)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Image(systemName: "arrow.turn.down.left")
                    .foregroundStyle(VibeTheme.swiftMuted)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VibeTheme.swiftPanel)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(VibeTheme.swiftBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct MainChatView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            TopBar(model: model)
            DividerLine(horizontal: true)
            HStack {
                Text(model.chatTitle)
                    .font(.system(size: 15, weight: .semibold))
                Image(systemName: "pencil")
                    .foregroundStyle(VibeTheme.swiftMuted)
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)

            if model.status != "Ready" || model.activityText != "Ready" {
                ActivityStrip(model: model)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 12)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        if model.messages.isEmpty {
                            EmptyChatView()
                        }
                        ForEach(model.messages) { message in
                            TimelineMessage(message: message, model: model)
                                .id(message.id)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                                    removal: .opacity
                                ))
                        }
                        if let permission = model.pendingPermission {
                            PermissionCard(permission: permission, model: model)
                                .transition(.scale(scale: 0.98).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 18)
                    .animation(.easeOut(duration: 0.16), value: model.messages.count)
                    .animation(.easeOut(duration: 0.16), value: model.pendingPermission?.id)
                }
                .onChange(of: model.messages.count) { _ in
                    if let last = model.messages.last {
                        withAnimation(.easeOut(duration: 0.18)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            ComposerView(model: model)
                .padding(.horizontal, 28)
                .padding(.bottom, 16)
        }
        .background(VibeTheme.swiftWorkspace)
    }
}

struct ActivityStrip: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(activityColor)
                .frame(width: 7, height: 7)
            Text(model.activityText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(VibeTheme.swiftForeground)
                .lineLimit(1)
            Spacer()
            Text(model.status)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VibeTheme.swiftMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(VibeTheme.swiftPanelElevated)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(VibeTheme.swiftBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var activityColor: Color {
        switch model.status {
        case "Error", "Backend exited": return VibeTheme.swiftRed
        case "Cancelling": return VibeTheme.swiftYellow
        case "Running": return VibeTheme.swiftOrange
        default: return VibeTheme.swiftMuted
        }
    }
}

struct TopBar: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 12) {
            Text("Mistral Vibe")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(VibeTheme.swiftOrange)
            Text("v2.9.3")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VibeTheme.swiftMuted)
            Text("·")
                .foregroundStyle(VibeTheme.swiftMuted)
            Text(model.activeModelID)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(VibeTheme.swiftForeground)
            WindowDragRegion()
                .frame(minWidth: 80, maxWidth: .infinity)
                .frame(height: 58)
            Text("Run")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(VibeTheme.swiftMuted)
            StatusPill(status: model.status)
            QuickActionsMenu(model: model)
            if model.status == "Running" {
                IconButton(systemName: "stop.fill") {
                    model.cancelPrompt()
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 58, alignment: .center)
    }
}

struct QuickActionsMenu: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Menu {
            Button("Open Working Directory") {
                model.openWorkingDirectory()
            }
            Button("Open Vibe Home") {
                model.openVibeHome()
            }
            Button("Open config.toml") {
                model.openConfigFile()
            }
            Divider()
            Button("Copy Last Response") {
                model.copyLastAssistantResponse()
            }
            Button("Copy Transcript") {
                model.copyTranscript()
            }
            Button("Export Transcript...") {
                model.exportTranscript()
            }
            Divider()
            Button("Refresh Chats") {
                model.listChatSessions()
            }
            Button("Clear Local View") {
                model.clearConversationView()
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(VibeTheme.swiftMuted)
                .frame(width: 30, height: 30)
        }
        .menuStyle(.borderlessButton)
        .help("Quick actions")
    }
}

struct MarkdownText: View {
    let content: String
    var fontSize: CGFloat = 15
    var color: Color = VibeTheme.swiftForeground

    var body: some View {
        Text(markdown)
            .font(.system(size: fontSize, design: usesMonospacedLayout ? .monospaced : .default))
            .foregroundStyle(color)
            .textSelection(.enabled)
            .lineSpacing(3)
    }

    private var markdown: AttributedString {
        (try? AttributedString(
            markdown: content,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        )) ?? AttributedString(content)
    }

    private var usesMonospacedLayout: Bool {
        content.contains("```")
            || content.contains("├")
            || content.contains("└")
            || content.contains("│")
            || content.contains("─")
    }
}

struct TimelineMessage: View {
    let message: ChatMessage
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            timelineMarker
            VStack(alignment: .leading, spacing: 7) {
                if message.role == .user {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 8) {
                            Text("You")
                                .font(.system(size: 14, weight: .bold))
                            Text(message.timestamp, style: .time)
                                .font(.system(size: 11))
                                .foregroundStyle(VibeTheme.swiftMuted)
                        }
                        MarkdownText(content: displayContent, fontSize: 15)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(VibeTheme.swiftPanelElevated)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(VibeTheme.swiftBorder, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    if message.role == .tool {
                        ToolCallCard(message: message, content: displayContent, model: model)
                    } else {
                        HStack(spacing: 8) {
                            Text(stepTitle)
                                .font(.system(size: titleSize, weight: .bold))
                                .foregroundStyle(titleColor)
                            Text(message.timestamp, style: .time)
                                .font(.system(size: 11))
                                .foregroundStyle(VibeTheme.swiftMuted)
                            if let status = message.status {
                                Text(status)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(status == "failed" ? VibeTheme.swiftRed : VibeTheme.swiftMuted)
                            }
                            Spacer()
                        }
                        if shouldShowContent {
                            MarkdownText(content: displayContent, fontSize: contentSize, color: contentColor)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
        }
    }

    private var timelineMarker: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(markerColor)
                .frame(width: markerSize, height: markerSize)
                .overlay(Circle().stroke(VibeTheme.swiftWorkspace, lineWidth: 2))
            Rectangle()
                .fill(VibeTheme.swiftBorder)
                .frame(width: 1)
                .frame(height: message.role == .tool ? 18 : 26)
                .opacity(message.role == .user ? 0 : 1)
        }
        .frame(width: 20)
        .frame(minHeight: 30)
        .padding(.top, 8)
    }

    private var markerColor: Color {
        switch message.role {
        case .user: return VibeTheme.swiftOrange
        case .assistant: return VibeTheme.swiftOrange
        case .thought: return VibeTheme.swiftYellow
        case .tool: return message.status == "failed" ? VibeTheme.swiftRed : VibeTheme.swiftGreen
        case .error: return VibeTheme.swiftRed
        }
    }

    private var markerSize: CGFloat {
        message.role == .tool ? 10 : 8
    }

    private var stepTitle: String {
        if message.role == .thought && message.content.isEmpty {
            return "Pondering..."
        }
        if message.role == .assistant && message.content.isEmpty {
            return "Generating..."
        }
        if message.role == .tool {
            return message.title
        }
        return message.title
    }

    private var titleSize: CGFloat {
        message.role == .tool ? 17 : 15
    }

    private var titleColor: Color {
        switch message.role {
        case .tool:
            return message.status == "failed" ? VibeTheme.swiftRed : VibeTheme.swiftForeground
        case .thought:
            return VibeTheme.swiftForeground
        case .assistant:
            return VibeTheme.swiftForeground
        case .error:
            return VibeTheme.swiftRed
        case .user:
            return VibeTheme.swiftForeground
        }
    }

    private var shouldShowContent: Bool {
        if message.role == .assistant && message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        if message.role == .thought && message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        if message.role == .tool {
            return !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    private var displayContent: String {
        let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        switch message.role {
        case .assistant:
            return "Generating..."
        case .thought:
            return "Thinking..."
        case .tool:
            return "Running \(message.title)..."
        default:
            return " "
        }
    }

    private var contentSize: CGFloat {
        message.role == .tool ? 13 : 15
    }

    private var contentColor: Color {
        if message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return VibeTheme.swiftMuted
        }
        return message.role == .thought ? VibeTheme.swiftMuted : VibeTheme.swiftForeground
    }
}

struct ToolCallCard: View {
    let message: ChatMessage
    let content: String
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(statusColor)
                    .frame(width: 22, height: 22)
                    .background(statusColor.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(actionTitle)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(VibeTheme.swiftForeground)
                        Text(message.timestamp, style: .time)
                            .font(.system(size: 11))
                            .foregroundStyle(VibeTheme.swiftMuted)
                    }
                    Text(toolSubtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(VibeTheme.swiftMuted)
                        .lineLimit(1)
                }

                Spacer()

                Text(statusLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            if !fileLines.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(fileLines, id: \.self) { path in
                        Button {
                            model.openFileInEditor(path: path)
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(VibeTheme.swiftMuted)
                                    .frame(width: 14)
                                Text(path)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(VibeTheme.swiftForeground)
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                                Spacer()
                                Text("Open")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(VibeTheme.swiftOrange)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(9)
                .background(VibeTheme.swiftPanel)
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(VibeTheme.swiftBorder, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }

            if isSearchReplace, let diff = searchReplaceDiff {
                SearchReplaceDiffView(diff: diff)
            } else if !detailText.isEmpty {
                Text(detailText)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(VibeTheme.swiftForeground)
                    .lineLimit(10)
                    .textSelection(.enabled)
                    .padding(9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(VibeTheme.swiftTerminalBackground)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(VibeTheme.swiftBorder, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
        }
        .padding(12)
        .background(VibeTheme.swiftPanelElevated)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(borderColor, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var lines: [String] {
        normalizedContent
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var actionTitle: String {
        if let running = lines.first(where: { $0.hasPrefix("Running ") }) {
            return running.replacingOccurrences(of: "Running ", with: "")
        }
        return message.title
    }

    private var fileLines: [String] {
        var paths = lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = trimmed.lowercased()
            if lower.hasPrefix("file: ") {
                return String(trimmed.dropFirst("file: ".count))
            }
            if lower.hasPrefix("path: ") {
                return String(trimmed.dropFirst("path: ".count))
            }
            return nil
        }
        if let file = jsonPayload?["file"] as? String, !file.isEmpty {
            paths.insert(file, at: 0)
        }
        if let path = jsonPayload?["path"] as? String, !path.isEmpty {
            paths.insert(path, at: 0)
        }
        return Array(NSOrderedSet(array: paths)) as? [String] ?? paths
    }

    private var detailText: String {
        let hiddenPrefixes = ["running ", "file: ", "path: "]
        return lines
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                let lower = trimmed.lowercased()
                return !hiddenPrefixes.contains(where: { lower.hasPrefix($0) })
                    && trimmed != "Done."
                    && trimmed != "Failed."
                    && lower != statusLabel.lowercased()
            }
            .joined(separator: "\n")
    }

    private var isSearchReplace: Bool {
        message.title.lowercased().contains("search_replace")
            || normalizedContent.contains("<<<<<<< SEARCH")
    }

    private var searchReplaceDiff: SearchReplaceDiff? {
        let allLines = normalizedContent.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let searchIndex = allLines.firstIndex(where: { $0.contains("<<<<<<< SEARCH") }),
              let separatorIndex = allLines[searchIndex...].firstIndex(where: { $0.contains("=======") }),
              let replaceIndex = allLines[separatorIndex...].firstIndex(where: { $0.contains(">>>>>>> REPLACE") }),
              searchIndex < separatorIndex,
              separatorIndex < replaceIndex else {
            return nil
        }
        let oldText = allLines[(searchIndex + 1)..<separatorIndex].joined(separator: "\n")
        let newText = allLines[(separatorIndex + 1)..<replaceIndex].joined(separator: "\n")
        return SearchReplaceDiff(oldText: oldText, newText: newText)
    }

    private var normalizedContent: String {
        if let content = jsonPayload?["content"] as? String {
            return content
        }
        return content
    }

    private var jsonPayload: [String: Any]? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{"), let data = trimmed.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private var toolSubtitle: String {
        if !fileLines.isEmpty {
            return "\(fileLines.count) file\(fileLines.count == 1 ? "" : "s") affected"
        }
        if detailText.isEmpty {
            return "Waiting for tool output"
        }
        return "Tool output available"
    }

    private var statusLabel: String {
        switch message.status {
        case "completed": return "Done"
        case "failed": return "Failed"
        case "running": return "Running"
        case let status?: return status.capitalized
        default: return "Running"
        }
    }

    private var statusColor: Color {
        switch message.status {
        case "completed": return VibeTheme.swiftGreen
        case "failed": return VibeTheme.swiftRed
        default: return VibeTheme.swiftOrange
        }
    }

    private var borderColor: Color {
        switch message.status {
        case "failed": return VibeTheme.swiftRed
        case "completed": return VibeTheme.swiftBorder
        default: return VibeTheme.swiftOrange.opacity(0.55)
        }
    }

    private var iconName: String {
        let lower = message.title.lowercased()
        if message.status == "failed" { return "xmark.octagon.fill" }
        if lower.contains("write") { return "square.and.pencil" }
        if lower.contains("read") { return "doc.text.magnifyingglass" }
        if lower.contains("terminal") || lower.contains("bash") { return "terminal" }
        if message.status == "completed" { return "checkmark.circle.fill" }
        return "gearshape.fill"
    }
}

struct SearchReplaceDiff {
    let oldText: String
    let newText: String
}

struct SearchReplaceDiffView: View {
    let diff: SearchReplaceDiff

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(rows) { row in
                HStack(alignment: .top, spacing: 8) {
                    Text(row.prefix)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(row.accent)
                        .frame(width: 16, alignment: .center)
                    Text(row.text.isEmpty ? " " : row.text)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(VibeTheme.swiftForeground)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(row.background)
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VibeTheme.swiftTerminalBackground)
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(VibeTheme.swiftBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private var rows: [DiffRow] {
        let removed = diff.oldText.split(separator: "\n", omittingEmptySubsequences: false)
            .map { DiffRow(kind: .removed, text: String($0)) }
        let added = diff.newText.split(separator: "\n", omittingEmptySubsequences: false)
            .map { DiffRow(kind: .added, text: String($0)) }
        return removed + added
    }

    private struct DiffRow: Identifiable {
        enum Kind {
            case added
            case removed
        }

        let id = UUID()
        let kind: Kind
        let text: String

        var prefix: String {
            kind == .added ? "+" : "-"
        }

        var accent: Color {
            kind == .added ? VibeTheme.swiftGreen : VibeTheme.swiftRed
        }

        var background: Color {
            kind == .added ? VibeTheme.swiftGreen.opacity(0.11) : VibeTheme.swiftRed.opacity(0.10)
        }
    }
}

struct PermissionCard: View {
    let permission: PermissionRequest
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "exclamationmark.shield")
                    .foregroundStyle(VibeTheme.swiftYellow)
                Text(permission.title)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
            }
            Text(permission.detail)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(VibeTheme.swiftMuted)
                .lineLimit(4)
            HStack {
                ForEach(permission.options) { option in
                    Button(option.name) {
                        model.approvePendingPermission(optionID: option.id)
                    }
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(VibeTheme.swiftWarningSurface)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(VibeTheme.swiftYellow, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct CommandAutocompleteList: View {
    let suggestions: [(name: String, description: String)]
    let complete: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(suggestions, id: \.name) { suggestion in
                Button {
                    complete(suggestion.name)
                } label: {
                    HStack(spacing: 10) {
                        Text(suggestion.name)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(VibeTheme.swiftOrange)
                            .frame(width: 112, alignment: .leading)
                        Text(suggestion.description)
                            .font(.system(size: 12))
                            .foregroundStyle(VibeTheme.swiftMuted)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "return")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VibeTheme.swiftMuted)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(VibeTheme.swiftPanel)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(VibeTheme.swiftBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct CommandInlineSuggest: View {
    let suggestion: (name: String, description: String)
    let accept: () -> Void

    var body: some View {
        Button(action: accept) {
            HStack(spacing: 8) {
                Image(systemName: "return")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(VibeTheme.swiftMuted)
                Text("complete")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(VibeTheme.swiftMuted)
                Text(suggestion.name)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(VibeTheme.swiftOrange)
                if !suggestion.description.isEmpty {
                    Text(suggestion.description)
                        .font(.system(size: 11))
                        .foregroundStyle(VibeTheme.swiftMuted)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct CommandInputField: View {
    @ObservedObject var model: AppModel
    @State private var prefixWidth: CGFloat = 0

    var body: some View {
        ZStack(alignment: .leading) {
            if !model.inlineCommandCompletionTail.isEmpty {
                Text(model.inlineCommandCompletionTail)
                    .font(inputFont)
                    .foregroundStyle(VibeTheme.swiftMuted.opacity(0.45))
                    .offset(x: prefixWidth)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            TextField(model.status == "Running" ? "Queue another message..." : "Ask Vibe anything...", text: $model.input, axis: .vertical)
                .textFieldStyle(.plain)
                .font(inputFont)
                .lineLimit(1...5)
                .onSubmit { model.submitComposer() }
                .background(
                    Text(model.input.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(inputFont)
                        .fixedSize()
                        .hidden()
                        .background(WidthReader(width: $prefixWidth))
                )
        }
    }

    private var inputFont: Font {
        model.input.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("/")
            ? .system(size: 15, design: .monospaced)
            : .system(size: 15)
    }
}

struct WidthReader: View {
    @Binding var width: CGFloat

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { width = proxy.size.width }
                .onChange(of: proxy.size.width) { width = $0 }
        }
    }
}

struct ComposerView: View {
    @ObservedObject var model: AppModel
    @State private var isDropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !model.attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(model.attachments) { attachment in
                            AttachmentChip(attachment: attachment) {
                                model.removeAttachment(attachment)
                            }
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                IconButton(systemName: "paperclip") {
                    chooseFiles()
                }
                CommandInputField(model: model)
                Button {
                    model.sendPrompt()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 34)
                        .background(VibeTheme.swiftOrange)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            if let suggestion = model.inlineCommandSuggestion {
                CommandInlineSuggest(suggestion: suggestion) {
                    model.completeCommand(suggestion.name)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(spacing: 14) {
                Label("Ask before editing", systemImage: "pencil.tip")
                    .foregroundStyle(VibeTheme.swiftMuted)
                if let first = model.attachments.first {
                    Label(first.name, systemImage: "paperclip")
                        .foregroundStyle(VibeTheme.swiftMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Label(model.configuration.workdir.lastPathComponent, systemImage: "folder")
                        .foregroundStyle(VibeTheme.swiftMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Text("/")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(VibeTheme.swiftMuted)
            }
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 2)
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(VibeTheme.swiftPanelElevated)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isDropTargeted ? VibeTheme.swiftOrange : VibeTheme.swiftBorder, lineWidth: isDropTargeted ? 1.5 : 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .animation(.easeOut(duration: 0.14), value: model.inlineCommandSuggestion?.name)
        .animation(.easeOut(duration: 0.14), value: isDropTargeted)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
            handleFileDrop(providers)
        }
    }

    private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.title = "Attach Files"
        panel.prompt = "Attach"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.directoryURL = model.configuration.workdir
        if panel.runModal() == .OK {
            model.attachFiles(panel.urls)
        }
    }

    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            accepted = true
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL?
                if let itemURL = item as? URL {
                    url = itemURL
                } else if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else {
                    url = nil
                }
                guard let url else { return }
                Task { @MainActor in
                    model.attachFiles([url])
                }
            }
        }
        return accepted
    }
}

struct AttachmentChip: View {
    let attachment: PromptAttachment
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: attachment.isEmbedded ? "doc.text" : "link")
                .foregroundStyle(VibeTheme.swiftOrange)
            Text(attachment.name)
                .lineLimit(1)
                .truncationMode(.middle)
            Button(action: remove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(VibeTheme.swiftMuted)
            }
            .buttonStyle(.plain)
        }
        .font(.system(size: 12))
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(VibeTheme.swiftBadge)
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(VibeTheme.swiftBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

struct InspectorView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 28) {
                ForEach(InspectorTab.allCases) { tab in
                    Button {
                        model.selectedInspectorTab = tab
                    } label: {
                        VStack(spacing: 8) {
                            Text(tab.rawValue)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(model.selectedInspectorTab == tab ? VibeTheme.swiftOrange : VibeTheme.swiftMuted)
                            Rectangle()
                                .fill(model.selectedInspectorTab == tab ? VibeTheme.swiftOrange : .clear)
                                .frame(height: 1.5)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                IconButton(systemName: "sidebar.trailing") {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        model.inspectorCollapsed = true
                    }
                }
            }
            .padding(.horizontal, 22)
            .frame(height: 58, alignment: .center)
            DividerLine(horizontal: true)

            ScrollView {
                VStack(spacing: 12) {
                    switch model.selectedInspectorTab {
                    case .files:
                        FileEditorMiniCard(model: model)
                        FilesCard(files: model.files, open: model.openFileInEditor)
                        FileActivityCard(files: model.files, open: model.openFileInEditor)
                    case .context:
                        ContextCard(model: model)
                        ConfigOptionsCard(model: model)
                        CommandsCard(commands: model.availableCommands)
                    case .run:
                        RunSummaryCard(model: model)
                        FilesCard(files: model.files, open: model.openFileInEditor)
                        TodoCard(todos: model.todos)
                        LogsCard(logs: model.logs)
                    }
                }
                .padding(12)
            }
        }
        .background(VibeTheme.swiftInspector)
    }
}

struct CollapsedInspectorRail: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 58)
            IconButton(systemName: "sidebar.leading") {
                withAnimation(.easeInOut(duration: 0.18)) {
                    model.inspectorCollapsed = false
                }
            }
            ForEach(InspectorTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        model.selectedInspectorTab = tab
                        model.inspectorCollapsed = false
                    }
                } label: {
                    Image(systemName: icon(for: tab))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(model.selectedInspectorTab == tab ? VibeTheme.swiftOrange : VibeTheme.swiftMuted)
                        .frame(width: 34, height: 34)
                        .background(model.selectedInspectorTab == tab ? VibeTheme.swiftSelection : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(VibeTheme.swiftInspector)
    }

    private func icon(for tab: InspectorTab) -> String {
        switch tab {
        case .run: return "play.fill"
        case .files: return "folder"
        case .context: return "slider.horizontal.3"
        }
    }
}

struct RunSummaryCard: View {
    @ObservedObject var model: AppModel

    var body: some View {
        InspectorCard(title: "RUN SUMMARY") {
            SummaryRow(label: "Status", value: model.status, accent: VibeTheme.swiftOrange)
            SummaryRow(label: "Activity", value: model.activityText)
            SummaryRow(label: "Started", value: "Today")
            SummaryRow(label: "Duration", value: model.duration)
            SummaryRow(label: "Model", value: model.activeModelID)
            SummaryRow(label: "Tokens", value: model.tokenText)
        }
    }
}

struct FilesCard: View {
    let files: [ProjectFile]
    var open: ((String) -> Void)?

    var body: some View {
        InspectorCard(title: "PROJECT STRUCTURE") {
            if files.isEmpty {
                Text("No file activity yet")
                    .foregroundStyle(VibeTheme.swiftMuted)
            } else {
                ForEach(files.prefix(12)) { file in
                    Button {
                        open?(file.path)
                    } label: {
                        HStack {
                            Image(systemName: icon(for: file.kind))
                                .foregroundStyle(color(for: file.kind))
                            Text(URL(fileURLWithPath: file.path).lastPathComponent)
                                .lineLimit(1)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(open == nil)
                }
            }
        }
    }

    private func icon(for kind: String) -> String {
        kind == "js" ? "curlybraces" : kind == "css" ? "number" : "doc.text"
    }

    private func color(for kind: String) -> Color {
        kind == "js" ? VibeTheme.swiftYellow : kind == "css" ? VibeTheme.swiftMuted : VibeTheme.swiftOrange
    }
}

struct FileEditorMiniCard: View {
    @ObservedObject var model: AppModel

    var body: some View {
        InspectorCard(title: "CODE EDITOR") {
            SummaryRow(label: "Indexed", value: "\(model.codeFiles.count)")
            SummaryRow(label: "Open", value: model.selectedCodeFile?.relativePath ?? "none")
            SummaryRow(
                label: "State",
                value: model.editorDirty ? "edited" : model.editorStatus,
                accent: model.editorDirty ? VibeTheme.swiftOrange : nil
            )
            HStack(spacing: 8) {
                Button("Open Files") {
                    model.selectedSection = .files
                    model.refreshCodeFiles()
                }
                .buttonStyle(.bordered)
                Button("Save") {
                    model.saveCodeFile()
                }
                .buttonStyle(.bordered)
                .disabled(model.selectedCodeFile == nil || !model.editorDirty)
            }
        }
    }
}

struct FileActivityCard: View {
    let files: [ProjectFile]
    var open: ((String) -> Void)?

    var body: some View {
        InspectorCard(title: "FILE ACTIVITY") {
            if files.isEmpty {
                Text("No read/write operations yet")
                    .foregroundStyle(VibeTheme.swiftMuted)
            } else {
                ForEach(files.prefix(20)) { file in
                    Button {
                        open?(file.path)
                    } label: {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.up.forward.square")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(VibeTheme.swiftOrange)
                                .frame(width: 14)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(file.path)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(VibeTheme.swiftForeground)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text(file.kind.isEmpty ? "file" : file.kind)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(VibeTheme.swiftMuted)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(open == nil)
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

struct ContextCard: View {
    @ObservedObject var model: AppModel

    var body: some View {
        InspectorCard(title: "SESSION CONTEXT") {
            SummaryRow(label: "Working dir", value: model.configuration.workdir.path)
            SummaryRow(label: "Repo root", value: model.configuration.repoRoot.path)
            SummaryRow(label: "Vibe home", value: model.configuration.vibeHome.path)
            SummaryRow(label: "Messages", value: "\(model.messages.count)")
            SummaryRow(label: "Files", value: "\(model.files.count)")
            SummaryRow(label: "Commands", value: "\(model.availableCommands.count)")
        }
    }
}

struct CommandsCard: View {
    let commands: [(name: String, description: String)]

    var body: some View {
        InspectorCard(title: "AVAILABLE COMMANDS") {
            if commands.isEmpty {
                Text("Commands will appear after backend initialization")
                    .foregroundStyle(VibeTheme.swiftMuted)
            } else {
                ForEach(commands.prefix(24), id: \.name) { command in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(command.name)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(VibeTheme.swiftOrange)
                        if !command.description.isEmpty {
                            Text(command.description)
                                .font(.system(size: 11))
                                .foregroundStyle(VibeTheme.swiftMuted)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

struct ConfigOptionsCard: View {
    @ObservedObject var model: AppModel

    var body: some View {
        InspectorCard(title: "VIBE CONFIG") {
            if model.configOptions.isEmpty {
                Text("Config options will appear after backend initialization")
                    .foregroundStyle(VibeTheme.swiftMuted)
            } else {
                ForEach(model.configOptions) { option in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(option.category.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(VibeTheme.swiftMuted)
                            Spacer()
                            Text(option.currentValue)
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(VibeTheme.swiftForeground)
                                .lineLimit(1)
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(option.choices) { choice in
                                    Button {
                                        model.setConfigOption(option.id, value: choice.id)
                                    } label: {
                                        Text(choice.name)
                                            .font(.system(size: 11, weight: choice.id == option.currentValue ? .bold : .medium))
                                            .lineLimit(1)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 5)
                                            .background(choice.id == option.currentValue ? VibeTheme.swiftSelection : VibeTheme.swiftBadge)
                                            .foregroundStyle(choice.id == option.currentValue ? VibeTheme.swiftOrange : VibeTheme.swiftForeground)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 5)
                }
            }
        }
    }
}

struct TodoCard: View {
    let todos: [TodoItem]

    var body: some View {
        InspectorCard(title: "TODO LIST") {
            ForEach(todos) { todo in
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: todo.completed ? "checkmark.square.fill" : "square")
                        .foregroundStyle(todo.completed ? VibeTheme.swiftGreen : VibeTheme.swiftMuted)
                    Text(todo.text)
                        .foregroundStyle(todo.completed ? VibeTheme.swiftMuted : VibeTheme.swiftForeground)
                    Spacer()
                }
            }
        }
    }
}

struct LogsCard: View {
    let logs: [ExecutionLog]

    var body: some View {
        InspectorCard(title: "EXECUTION LOGS") {
            ForEach(logs.suffix(80)) { log in
                HStack(alignment: .top, spacing: 8) {
                    Text(log.date, style: .time)
                        .foregroundStyle(VibeTheme.swiftMuted)
                    Text(log.text)
                        .foregroundStyle(color(for: log.level))
                        .lineLimit(3)
                    Spacer()
                }
                .font(.system(size: 11, design: .monospaced))
            }
        }
    }

    private func color(for level: LogLevel) -> Color {
        switch level {
        case .info: return VibeTheme.swiftForeground
        case .success: return VibeTheme.swiftGreen
        case .warning: return VibeTheme.swiftYellow
        case .error: return VibeTheme.swiftRed
        }
    }
}

struct InspectorCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(VibeTheme.swiftMuted)
            content
                .font(.system(size: 12))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VibeTheme.swiftPanel)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(VibeTheme.swiftBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SummaryRow: View {
    let label: String
    let value: String
    var accent: Color?

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(VibeTheme.swiftMuted)
            Spacer()
            if let accent {
                Circle().fill(accent).frame(width: 6, height: 6)
            }
            Text(value)
                .foregroundStyle(VibeTheme.swiftForeground)
                .lineLimit(1)
        }
    }
}

struct EmptyChatView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Start a native Vibe run")
                .font(.system(size: 18, weight: .semibold))
            Text("The Swift UI talks to Vibe through ACP, so tool calls, files, permissions, usage, and assistant chunks render as native macOS views.")
                .foregroundStyle(VibeTheme.swiftMuted)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VibeTheme.swiftPanel)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(VibeTheme.swiftBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SidebarRow: View {
    let title: String
    let icon: String
    let selected: Bool
    let badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 18)
                    .foregroundStyle(selected ? VibeTheme.swiftOrange : VibeTheme.swiftMuted)
                Text(title)
                    .foregroundStyle(selected ? VibeTheme.swiftOrange : VibeTheme.swiftForeground)
                Spacer()
                if let badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(VibeTheme.swiftMuted)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(VibeTheme.swiftBadge)
                        .clipShape(Capsule())
                }
            }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(selected ? VibeTheme.swiftSelection : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
}

struct SidebarCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(VibeTheme.swiftMuted)
            content
                .font(.system(size: 13))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VibeTheme.swiftPanel)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(VibeTheme.swiftBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
    }
}

struct StatusPill: View {
    let status: String
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(VibeTheme.swiftOrange).frame(width: 7, height: 7)
            Text(status)
                .font(.system(size: 13, weight: .semibold))
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(VibeTheme.swiftForeground)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(VibeTheme.swiftSelection)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct IconButton: View {
    let systemName: String
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isHovering ? VibeTheme.swiftForeground : VibeTheme.swiftMuted)
                .frame(width: 34, height: 34)
                .background(isHovering ? VibeTheme.swiftSelection : VibeTheme.swiftPanelElevated)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(isHovering ? VibeTheme.swiftMuted : VibeTheme.swiftBorder, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .scaleEffect(isHovering ? 1.04 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }
}

struct RoleIcon: View {
    let role: MessageRole

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 20, height: 20)
            .padding(.top, 8)
    }

    private var icon: String {
        switch role {
        case .user: return "person.crop.circle.fill"
        case .assistant: return "sparkles"
        case .thought: return "brain"
        case .tool: return "wrench.and.screwdriver"
        case .error: return "xmark.octagon"
        }
    }

    private var color: Color {
        switch role {
        case .user: return VibeTheme.swiftOrange
        case .assistant: return VibeTheme.swiftOrange
        case .thought: return VibeTheme.swiftMuted
        case .tool: return VibeTheme.swiftYellow
        case .error: return VibeTheme.swiftRed
        }
    }
}

struct DividerLine: View {
    var horizontal = false
    var body: some View {
        Rectangle()
            .fill(VibeTheme.swiftBorder)
            .frame(width: horizontal ? nil : 1, height: horizontal ? 1 : nil)
    }
}

struct WindowDragRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = DragRegionView()
        view.autoresizingMask = [.width]
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

final class DragRegionView: NSView {
    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        window.performDrag(with: event)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let window else { return nil }
        let screenPoint = convert(point, to: nil)
        for buttonType in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            guard let button = window.standardWindowButton(buttonType),
                  !button.isHidden,
                  button.superview != nil else { continue }
            let localPoint = button.convert(screenPoint, from: nil)
            if button.bounds.contains(localPoint) {
                return nil
            }
        }
        return self
    }
}
