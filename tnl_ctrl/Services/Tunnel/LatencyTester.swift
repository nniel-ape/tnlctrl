//
//  LatencyTester.swift
//  tnl_ctrl
//
//  TCP connect latency tester using Network framework.
//

import Network
import OSLog

private let logger = Logger(subsystem: "nniel.tnlctrl", category: "LatencyTester")

// MARK: - LatencyResult

enum LatencyResult: Sendable {
    case success(ms: Int)
    case timeout
    case error(String)
}

// MARK: - LatencyTester

@MainActor
@Observable
final class LatencyTester {
    static let shared = LatencyTester()

    private(set) var pingingServiceIds: Set<UUID> = []

    var isPingingAll: Bool {
        !pingingServiceIds.isEmpty
    }

    private init() {}

    // MARK: - Single Service Test

    func testLatency(for service: Service, timeout: TimeInterval = 5) async -> LatencyResult {
        pingingServiceIds.insert(service.id)
        defer { pingingServiceIds.remove(service.id) }

        return await Self.measureTCPConnect(
            host: service.server,
            port: UInt16(service.port),
            timeout: timeout
        )
    }

    // MARK: - Test All Services

    func testAll(
        services: [Service],
        onResult: @MainActor @Sendable (UUID, LatencyResult) -> Void
    ) async {
        for service in services {
            pingingServiceIds.insert(service.id)
        }

        await withTaskGroup(of: (UUID, LatencyResult).self) { group in
            for service in services {
                group.addTask {
                    let result = await Self.measureTCPConnect(
                        host: service.server,
                        port: UInt16(service.port),
                        timeout: 5
                    )
                    return (service.id, result)
                }
            }

            for await (id, result) in group {
                pingingServiceIds.remove(id)
                onResult(id, result)
            }
        }
    }

    // MARK: - TCP Connect Measurement

    nonisolated static func measureTCPConnect(
        host: String,
        port: UInt16,
        timeout: TimeInterval
    ) async -> LatencyResult {
        await withCheckedContinuation { continuation in
            let queue = DispatchQueue(label: "nniel.tnlctrl.latency.\(host):\(port)")
            var resumed = false

            let nwHost = NWEndpoint.Host(host)
            let nwPort = NWEndpoint.Port(rawValue: port) ?? .https
            let params = NWParameters.tcp
            let connection = NWConnection(host: nwHost, port: nwPort, using: params)

            let start = DispatchTime.now()

            // Timeout
            queue.asyncAfter(deadline: .now() + timeout) {
                guard !resumed else { return }
                resumed = true
                connection.cancel()
                logger.debug("Timeout connecting to \(host):\(port)")
                continuation.resume(returning: .timeout)
            }

            connection.stateUpdateHandler = { state in
                queue.async {
                    guard !resumed else { return }
                    switch state {
                    case .ready:
                        resumed = true
                        let elapsed = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
                        let ms = Int(elapsed / 1_000_000)
                        connection.cancel()
                        logger.debug("Connected to \(host):\(port) in \(ms)ms")
                        continuation.resume(returning: .success(ms: ms))
                    case let .failed(error):
                        resumed = true
                        connection.cancel()
                        logger.debug("Failed connecting to \(host):\(port): \(error)")
                        continuation.resume(returning: .error(error.localizedDescription))
                    case .cancelled:
                        // Handled by timeout or success path
                        break
                    default:
                        break
                    }
                }
            }

            connection.start(queue: queue)
        }
    }
}
