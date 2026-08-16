import Foundation

/// Shared bail/validation helpers used across the CLI's files.

/// Print to stderr and exit non-zero. Used for hard errors (bad args, command failed).
func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("Error: \(message)\n".utf8))
    exit(1)
}

/// Bail out (print + exit 1) when a mutating networksetup call failed.
func check(_ r: (output: String, status: Int32), _ label: String) {
    if r.status != 0 {
        fail("\(label) failed (exit \(r.status)): \(r.output.isEmpty ? "no output" : r.output)")
    }
}

/// Validate a dotted-quad IPv4 address. Good enough to catch typos in a test tool;
/// not a full address parser.
func validIP(_ s: String) -> Bool {
    let parts = s.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count == 4 else { return false }
    return parts.allSatisfy {
        guard let n = Int($0) else { return false }
        return (0...255).contains(n)
    }
}

func requireIP(_ s: String, label: String) {
    guard validIP(s) else { fail("\(label) '\(s)' is not a valid IPv4 address.") }
}
