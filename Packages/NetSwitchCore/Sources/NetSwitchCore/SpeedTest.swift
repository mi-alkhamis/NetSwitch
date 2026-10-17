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

    public init(pingMilliseconds: Double, jitterMilliseconds: Double, serverName: String, serverLocation: String) {
        self.pingMilliseconds = pingMilliseconds
        self.jitterMilliseconds = jitterMilliseconds
        self.serverName = serverName
        self.serverLocation = serverLocation
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
            }
        }

        let ping = samples.reduce(0, +) / Double(samples.count)
        let differences = zip(samples, samples.dropFirst()).map { abs($0 - $1) }
        let jitter = differences.reduce(0, +) / Double(max(differences.count, 1))
        return SpeedTestLatency(
            pingMilliseconds: ping,
            jitterMilliseconds: jitter,
            serverName: "Cloudflare Speed Test",
            serverLocation: serverLocation
        )
    }

    public static func measureDownload() async throws -> SpeedTestMeasurement {
        let url = URL(string: "https://speed.cloudflare.com/__down?bytes=\(downloadBytes)")!
        return try await measure(url: url, method: "GET", body: nil)
    }

    public static func measureUpload() async throws -> SpeedTestMeasurement {
        let url = URL(string: "https://speed.cloudflare.com/__up?bytes=\(uploadBytes)")!
        let payload = Data(repeating: 0x4E, count: uploadBytes)
        return try await measure(url: url, method: "POST", body: payload)
    }

    private static func measure(url: URL, method: String, body: Data?) async throws -> SpeedTestMeasurement {
        var request = URLRequest(url: url, timeoutInterval: 45)
        request.httpMethod = method
        request.httpBody = body
        if body != nil {
            request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        }

        let start = Date()
        let (responseData, response) = try await URLSession.shared.data(for: request)
        let duration = max(Date().timeIntervalSince(start), 0.001)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode) else {
            throw NetworkMeasurementError.speedTestRejected
        }

        let bytes = body?.count ?? responseData.count
        return SpeedTestMeasurement(
            megabitsPerSecond: Double(bytes) * 8 / duration / 1_000_000,
            transferredBytes: bytes
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

