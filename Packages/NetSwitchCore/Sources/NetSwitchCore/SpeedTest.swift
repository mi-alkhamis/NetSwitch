import Foundation

public struct SpeedTestMeasurement: Equatable, Sendable {
    public let megabitsPerSecond: Double
    public let transferredBytes: Int

    public init(megabitsPerSecond: Double, transferredBytes: Int) {
        self.megabitsPerSecond = megabitsPerSecond
        self.transferredBytes = transferredBytes
    }
}

public struct SpeedTestLatency: Equatable, Sendable {
    public let pingMilliseconds: Double
    public let jitterMilliseconds: Double
    public let serverName: String
    /// Cloudflare edge location code, such as SFO or LHR.
    public let serverLocation: String
    /// The response's CF-Ray request identifier, useful for tracing the serving edge.
    public let serverRequestID: String?

    public init(pingMilliseconds: Double, jitterMilliseconds: Double, serverName: String, serverLocation: String, serverRequestID: String? = nil) {
        self.pingMilliseconds = pingMilliseconds
        self.jitterMilliseconds = jitterMilliseconds
        self.serverName = serverName
        self.serverLocation = serverLocation
        self.serverRequestID = serverRequestID
    }
}

public enum SpeedTestClient {
    private static let downloadBytes = 10_000_000
    private static let uploadBytes = 2_000_000

    public static func publicIPAddress() async throws -> String {
        let url = URL(string: "https://speed.cloudflare.com/meta")!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let metadata = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let address = metadata["clientIp"] as? String,
              !address.isEmpty else {
            throw NetworkMeasurementError.publicIPUnavailable
        }
        return address
    }

    public static func measurePingAndJitter(sampleCount: Int = 6) async throws -> SpeedTestLatency {
        var samples: [Double] = []
        var serverLocation = "Unknown"
        var serverID: String?
        let measuredSampleCount = max(sampleCount, 2)

        // Warm the HTTPS connection first so the initial TLS handshake does not skew ping.
        for sampleIndex in 0...measuredSampleCount {
            var components = URLComponents(string: "https://speed.cloudflare.com/__down")!
            components.queryItems = [
                URLQueryItem(name: "bytes", value: "0"),
                URLQueryItem(name: "cb", value: UUID().uuidString)
            ]
            var request = URLRequest(url: components.url!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
            request.httpMethod = "GET"

            let start = Date()
            let (_, response) = try await URLSession.shared.data(for: request)
            let elapsed = Date().timeIntervalSince(start) * 1_000
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                throw NetworkMeasurementError.speedTestRejected
            }

            if sampleIndex > 0 {
                samples.append(elapsed)
            }
            if let ray = http.value(forHTTPHeaderField: "cf-ray"),
               let location = ray.split(separator: "-").last {
                serverLocation = String(location)
                serverID = ray
            }
        }

        let ping = samples.reduce(0, +) / Double(samples.count)
        let differences = zip(samples, samples.dropFirst()).map { abs($0 - $1) }
        let jitter = differences.reduce(0, +) / Double(max(differences.count, 1))
        return SpeedTestLatency(
            pingMilliseconds: ping,
            jitterMilliseconds: jitter,
            serverName: URL(string: "https://speed.cloudflare.com")?.host ?? "Unknown",
            serverLocation: serverLocation,
            serverRequestID: serverID
        )
    }

    public static func measureDownload(
        onSample: @escaping @MainActor @Sendable (Double) -> Void = { _ in }
    ) async throws -> SpeedTestMeasurement {
        try await measureChunks(
            totalBytes: downloadBytes,
            chunkBytes: 1_000_000,
            direction: .download,
            onSample: onSample
        )
    }

    public static func measureUpload(
        onSample: @escaping @MainActor @Sendable (Double) -> Void = { _ in }
    ) async throws -> SpeedTestMeasurement {
        try await measureChunks(
            totalBytes: uploadBytes,
            chunkBytes: 500_000,
            direction: .upload,
            onSample: onSample
        )
    }

    private enum TransferDirection: Equatable {
        case download
        case upload
    }

    private static func measureChunks(
        totalBytes: Int,
        chunkBytes: Int,
        direction: TransferDirection,
        onSample: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws -> SpeedTestMeasurement {
        var transferredBytes = 0
        var measuredDuration = 0.0
        let chunkCount = Int(ceil(Double(totalBytes) / Double(chunkBytes)))

        for _ in 0..<chunkCount {
            try Task.checkCancellation()
            let byteCount = min(chunkBytes, totalBytes - transferredBytes)
            var components = URLComponents(string: direction == .download
                ? "https://speed.cloudflare.com/__down"
                : "https://speed.cloudflare.com/__up")!
            components.queryItems = [
                URLQueryItem(name: "bytes", value: String(byteCount)),
                URLQueryItem(name: "cb", value: UUID().uuidString)
            ]
            var request = URLRequest(url: components.url!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 45)
            request.httpMethod = direction == .download ? "GET" : "POST"
            if direction == .upload {
                request.httpBody = Data(repeating: 0x4E, count: byteCount)
                request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            }

            let start = Date()
            let (responseData, response) = try await URLSession.shared.data(for: request)
            let duration = max(Date().timeIntervalSince(start), 0.001)
            guard let response = response as? HTTPURLResponse,
                  (200..<300).contains(response.statusCode) else {
                throw NetworkMeasurementError.speedTestRejected
            }

            let actualBytes = direction == .upload ? byteCount : responseData.count
            transferredBytes += actualBytes
            measuredDuration += duration
            await onSample(Double(actualBytes) * 8 / duration / 1_000_000)
        }

        return SpeedTestMeasurement(
            megabitsPerSecond: Double(transferredBytes) * 8 / max(measuredDuration, 0.001) / 1_000_000,
            transferredBytes: transferredBytes
        )
    }
}

public enum NetworkMeasurementError: LocalizedError {
    case speedTestRejected
    case invalidDNSResponse
    case publicIPUnavailable

    public var errorDescription: String? {
        switch self {
        case .speedTestRejected: "The speed test service did not accept the request. Please try again."
        case .invalidDNSResponse: "A DNS provider returned an invalid response."
        case .publicIPUnavailable: "The public IP address could not be read from the speed test service."
        }
    }
}

