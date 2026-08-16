import Foundation
import Darwin

/// Thin wrapper around `/usr/sbin/networksetup`.
///
/// Elevation strategy (mirrors the GUI app's privilege model):
/// - If the CLI is already running as root (`sudo netswitch ...`), shell out to
///   `networksetup` directly — fastest, no prompt.
/// - Otherwise, route through `osascript ... with administrator privileges`,
///   which surfaces the native macOS password prompt. This is the *same* code path
///   the sandboxed GUI app relies on, so a successful run here is a useful (if not
///   identical — no sandbox) signal for the Phase 1 "riskiest unknown".
enum Net {
    static let path = "/usr/sbin/networksetup"

    static var isRoot: Bool { getuid() == 0 }

    // MARK: - Public

    /// Run a `networksetup` invocation, auto-elevating when not root.
    @discardableResult
    static func run(_ args: [String]) -> (output: String, status: Int32) {
        let display = "\(path) \(args.joined(separator: " "))"
        if isRoot {
            print("→ direct:   \(display)")
            return runDirect(args)
        } else {
            print("→ elevated:  \(display)   (osascript admin prompt)")
            return runElevated(args)
        }
    }

    /// Run read-only commands directly — they never need admin. Use for
    /// `-listallnetworkservices`, `-getinfo`, `-listpreferredwirelessnetworks`, etc.
    @discardableResult
    static func runReadonly(_ args: [String]) -> (output: String, status: Int32) {
        let r = runDirect(args)
        if r.status != 0 {
            fail("networksetup failed (exit \(r.status)): \(r.output.isEmpty ? "no output" : r.output)")
        }
        return r
    }

    // MARK: - Internals

    private static func runDirect(_ args: [String]) -> (output: String, status: Int32) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = args
        let outPipe = Pipe(), errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe
        do {
            try task.run()
        } catch {
            return ("launch failed: \(error.localizedDescription)", -1)
        }
        task.waitUntilExit()
        let combined = [readPipe(outPipe), readPipe(errPipe)]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        return (combined, task.terminationStatus)
    }

    /// Build `do shell script "<cmd>" with administrator privileges` and run via osascript.
    /// Every argument is POSIX-shell quoted before it is embedded in the command.
    /// Service names are user supplied, so they must never be interpolated raw.
    private static func runElevated(_ args: [String]) -> (output: String, status: Int32) {
        let quoted = args.map { quoteArg($0) }
        let command = "\(path) \(quoted.joined(separator: " "))"
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escaped)\" with administrator privileges"
        return runOSA(script)
    }

    private static func runOSA(_ script: String) -> (output: String, status: Int32) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        let outPipe = Pipe(), errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe
        do {
            try task.run()
        } catch {
            return ("launch failed: \(error.localizedDescription)", -1)
        }
        task.waitUntilExit()
        let combined = [readPipe(outPipe), readPipe(errPipe)]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        return (combined, task.terminationStatus)
    }

    private static func quoteArg(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func readPipe(_ pipe: Pipe) -> String {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (String(data: data, encoding: .utf8) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
