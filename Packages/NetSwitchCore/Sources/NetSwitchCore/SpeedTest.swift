import Foundation

public struct SpeedTestServer: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let server: String
    public let dlURL: String
    public let ulURL: String
    public let pingURL: String
    public let getIpURL: String

    public var isCloudflare: Bool { id == Self.cloudflareID }

    public var location: String {
        guard !isCloudflare else { return "Automatic Cloudflare edge" }
        return name.components(separatedBy: " (").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? name
    }

    public static let cloudflareID = "cloudflare-auto"
    public static let cloudflare = SpeedTestServer(
        id: cloudflareID,
        name: "Cloudflare (automatic)",
        server: "https://speed.cloudflare.com/",
        dlURL: "__down",
        ulURL: "__up",
        pingURL: "__down",
        getIpURL: "meta"
    )

    public init(id: String, name: String, server: String, dlURL: String, ulURL: String, pingURL: String, getIpURL: String) {
        self.id = id
        self.name = name
        self.server = server
        self.dlURL = dlURL
        self.ulURL = ulURL
        self.pingURL = pingURL
        self.getIpURL = getIpURL
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, server, dlURL, ulURL, pingURL, getIpURL
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        if let stringID = try? values.decode(String.self, forKey: .id) {
            id = stringID
        } else {
            id = String(try values.decode(Int.self, forKey: .id))
        }
        name = try values.decode(String.self, forKey: .name)
        server = try values.decode(String.self, forKey: .server)
        dlURL = try values.decode(String.self, forKey: .dlURL)
        ulURL = try values.decode(String.self, forKey: .ulURL)
        pingURL = try values.decode(String.self, forKey: .pingURL)
        getIpURL = try values.decode(String.self, forKey: .getIpURL)
    }

    func endpoint(_ path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        let rawBaseString = server.hasPrefix("//") ? "https:\(server)" : server
        let baseString = rawBaseString.hasSuffix("/") ? rawBaseString : rawBaseString + "/"
        guard let baseURL = URL(string: baseString), baseURL.scheme?.lowercased() == "https",
              let url = URL(string: path, relativeTo: baseURL)?.absoluteURL,
              url.scheme?.lowercased() == "https", url.host == baseURL.host,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            throw NetworkMeasurementError.speedTestRejected
        }
        components.queryItems = (components.queryItems ?? []) + queryItems
        guard let endpoint = components.url else { throw NetworkMeasurementError.speedTestRejected }
        return endpoint
    }
}

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
    public let serverLocation: String
    public let serverRequestID: String?

    public init(pingMilliseconds: Double, jitterMilliseconds: Double, serverName: String, serverLocation: String, serverRequestID: String? = nil) {
        self.pingMilliseconds = pingMilliseconds
        self.jitterMilliseconds = jitterMilliseconds
        self.serverName = serverName
        self.serverLocation = serverLocation
        self.serverRequestID = serverRequestID
    }
}

public struct SpeedTestServerRecommendation: Sendable {
    public let server: SpeedTestServer
    public let latency: SpeedTestLatency

    public init(server: SpeedTestServer, latency: SpeedTestLatency) {
        self.server = server
        self.latency = latency
    }
}

public enum SpeedTestClient {
    private static let downloadBytes = 10_000_000
    private static let uploadBytes = 2_000_000
    private static let serverListURL = URL(string: "https://librespeed.org/backend-servers/servers.php")!

    public static func availableServers() async -> [SpeedTestServer] {
        do {
            let (data, response) = try await URLSession.shared.data(from: serverListURL)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return [.cloudflare]
            }
            let servers = try JSONDecoder().decode([SpeedTestServer].self, from: data)
                .filter { !$0.isCloudflare && (try? $0.endpoint($0.pingURL)) != nil }
            return [.cloudflare] + servers
        } catch {
            return [.cloudflare]
        }
    }

    public static func recommendServer(from servers: [SpeedTestServer]) async -> SpeedTestServerRecommendation? {
        await withTaskGroup(of: SpeedTestServerRecommendation?.self) { group in
            for server in servers {
                group.addTask {
                    guard let latency = try? await measurePingAndJitter(server: server, sampleCount: 1) else { return nil }
                    return SpeedTestServerRecommendation(server: server, latency: latency)
                }
            }
            var best: SpeedTestServerRecommendation?
            for await candidate in group {
                guard let candidate else { continue }
                if best == nil || candidate.latency.pingMilliseconds < best!.latency.pingMilliseconds {
                    best = candidate
                }
            }
            return best
        }
    }

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

    public static func measurePingAndJitter(
        server: SpeedTestServer = .cloudflare,
        sampleCount: Int = 6
    ) async throws -> SpeedTestLatency {
        if server.isCloudflare { return try await measureCloudflarePingAndJitter(sampleCount: sampleCount) }

        var samples: [Double] = []
        for _ in 0..<max(sampleCount, 2) {
            try Task.checkCancellation()
            let requestURL = try server.endpoint(
                server.pingURL,
                queryItems: [URLQueryItem(name: "r", value: UUID().uuidString)]
            )
            var request = URLRequest(url: requestURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
            request.httpMethod = "GET"
            let start = Date()
            let (_, response) = try await URLSession.shared.data(for: request)
            let elapsed = Date().timeIntervalSince(start) * 1_000
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw NetworkMeasurementError.speedTestRejected
            }
            samples.append(elapsed)
        }
        let ping = samples.reduce(0, +) / Double(samples.count)
        let differences = zip(samples, samples.dropFirst()).map { abs($0 - $1) }
        let jitter = differences.reduce(0, +) / Double(max(differences.count, 1))
        return SpeedTestLatency(
            pingMilliseconds: ping,
            jitterMilliseconds: jitter,
            serverName: server.name,
            serverLocation: server.location
        )
    }

    private static func measureCloudflarePingAndJitter(sampleCount: Int) async throws -> SpeedTestLatency {
        var samples: [Double] = []
        var serverLocation = "Unknown"
        var serverID: String?
        let measuredSampleCount = max(sampleCount, 2)

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
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw NetworkMeasurementError.speedTestRejected
            }
            if sampleIndex > 0 { samples.append(elapsed) }
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
            serverName: "speed.cloudflare.com",
            serverLocation: serverLocation,
            serverRequestID: serverID
        )
    }

    public static func measureDownload(
        server: SpeedTestServer = .cloudflare,
        onSample: @escaping @MainActor @Sendable (Double) -> Void = { _ in }
    ) async throws -> SpeedTestMeasurement {
        try await measureChunks(totalBytes: downloadBytes, chunkBytes: 1_000_000, direction: .download, server: server, onSample: onSample)
    }

    public static func measureUpload(
        server: SpeedTestServer = .cloudflare,
        onSample: @escaping @MainActor @Sendable (Double) -> Void = { _ in }
    ) async throws -> SpeedTestMeasurement {
        try await measureChunks(totalBytes: uploadBytes, chunkBytes: 500_000, direction: .upload, server: server, onSample: onSample)
    }

    private enum TransferDirection { case download, upload }

    private static func measureChunks(
        totalBytes: Int,
        chunkBytes: Int,
        direction: TransferDirection,
        server: SpeedTestServer,
        onSample: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws -> SpeedTestMeasurement {
        var transferredBytes = 0
        var measuredDuration = 0.0
        let chunkCount = Int(ceil(Double(totalBytes) / Double(chunkBytes)))

        for _ in 0..<chunkCount {
            try Task.checkCancellation()
            let byteCount = min(chunkBytes, totalBytes - transferredBytes)
            let path = direction == .download ? server.dlURL : server.ulURL
            let queryItems: [URLQueryItem]
            if server.isCloudflare {
                queryItems = [
                    URLQueryItem(name: "bytes", value: String(byteCount)),
                    URLQueryItem(name: "cb", value: UUID().uuidString)
                ]
            } else if direction == .download {
                queryItems = [
                    URLQueryItem(name: "ckSize", value: String(max(1, Int(ceil(Double(byteCount) / 1_000_000))))),
                    URLQueryItem(name: "r", value: UUID().uuidString)
                ]
            } else {
                queryItems = [URLQueryItem(name: "r", value: UUID().uuidString)]
            }

            var request = URLRequest(
                url: try server.endpoint(path, queryItems: queryItems),
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: 45
            )
            request.httpMethod = direction == .download ? "GET" : "POST"
            if direction == .upload {
                request.httpBody = Data(repeating: 0x4E, count: byteCount)
                if server.isCloudflare {
                    request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
                }
            }

            let start = Date()
            let (responseData, response) = try await URLSession.shared.data(for: request)
            let duration = max(Date().timeIntervalSince(start), 0.001)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw NetworkMeasurementError.speedTestRejected
            }
            let actualBytes = direction == .upload ? byteCount : responseData.count
            guard actualBytes > 0 else { throw NetworkMeasurementError.speedTestRejected }
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
