import Foundation

struct CLIConfiguration {
    var repoRoot: URL
    var workdir: URL
    var vibeHome: URL
    var blurEnabled: Bool
    var metalEnabled: Bool
    var title: String

    static func parse(processArguments: [String]) -> CLIConfiguration {
        var args = Array(processArguments.dropFirst())
        var repoRoot: URL?
        var workdir: URL?
        var vibeHome: URL?
        var blurEnabled = true
        var metalEnabled = true
        var title = "Vibe"

        while !args.isEmpty {
            let arg = args.removeFirst()
            if arg == "--" {
                break
            }
            switch arg {
            case "--repo-root":
                if let value = args.first {
                    repoRoot = URL(fileURLWithPath: NSString(string: value).expandingTildeInPath)
                    args.removeFirst()
                }
            case "--workdir":
                if let value = args.first {
                    workdir = URL(fileURLWithPath: NSString(string: value).expandingTildeInPath)
                    args.removeFirst()
                }
            case "--vibe-home":
                if let value = args.first {
                    vibeHome = URL(fileURLWithPath: NSString(string: value).expandingTildeInPath)
                    args.removeFirst()
                }
            case "--no-blur":
                blurEnabled = false
            case "--no-metal":
                metalEnabled = false
            case "--title":
                if let value = args.first {
                    title = value
                    args.removeFirst()
                }
            default:
                continue
            }
        }

        let launchDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let resolvedRepoRoot = (
            repoRoot
                ?? findRepoRoot(startingAt: launchDirectory)
                ?? bundledBackendRoot()
                ?? launchDirectory
        ).standardizedFileURL
        let resolvedWorkdir = (workdir ?? launchDirectory).standardizedFileURL
        let resolvedVibeHome = (
            vibeHome
                ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".vibe")
        ).standardizedFileURL

        return CLIConfiguration(
            repoRoot: resolvedRepoRoot,
            workdir: resolvedWorkdir,
            vibeHome: resolvedVibeHome,
            blurEnabled: blurEnabled,
            metalEnabled: metalEnabled,
            title: title
        )
    }
}

private func bundledBackendRoot() -> URL? {
    guard let resourceURL = Bundle.main.resourceURL else { return nil }
    let backendURL = resourceURL.appendingPathComponent("VibeBackend")
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: backendURL.appendingPathComponent("pyproject.toml").path),
          fileManager.fileExists(atPath: backendURL.appendingPathComponent("vibe").path) else {
        return nil
    }
    return backendURL
}

private func findRepoRoot(startingAt start: URL) -> URL? {
    var cursor = start.standardizedFileURL
    let fileManager = FileManager.default

    while true {
        let marker = cursor.appendingPathComponent("pyproject.toml")
        if fileManager.fileExists(atPath: marker.path),
           let content = try? String(contentsOf: marker),
           content.contains("mistral-vibe") {
            return cursor
        }

        let parent = cursor.deletingLastPathComponent()
        if parent.path == cursor.path {
            return nil
        }
        cursor = parent
    }
}
