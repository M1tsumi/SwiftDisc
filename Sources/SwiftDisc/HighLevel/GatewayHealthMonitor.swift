//
//  GatewayHealthMonitor.swift
//  SwiftDisc
//
//  Created by SwiftDisc Team
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

/// Monitors gateway health and provides metrics
public class GatewayHealthMonitor: Sendable {
    private let stateManager: GatewayStateManager
    private let queue = DispatchQueue(label: "com.swiftdisc.gateway.health")
    private var _metrics: GatewayHealthMetrics
    private var latencyHistory: [TimeInterval] = []
    private let maxLatencySamples = 100

    /// Current health metrics
    public var metrics: GatewayHealthMetrics {
        queue.sync { _metrics }
    }

    /// Initialize health monitor
    /// - Parameter stateManager: Gateway state manager to monitor
    public init(stateManager: GatewayStateManager) {
        self.stateManager = stateManager
        self._metrics = GatewayHealthMetrics(
            averageLatency: 0,
            p95Latency: 0,
            heartbeatsSent: 0,
            heartbeatsAcked: 0,
            heartbeatSuccessRate: 0,
            reconnections: 0,
            messagesReceived: 0,
            messagesSent: 0,
            uptime: 0
        )
    }

    /// Record heartbeat sent
    public func heartbeatSent() {
        queue.async {
            self._metrics = GatewayHealthMetrics(
                averageLatency: self._metrics.averageLatency,
                p95Latency: self._metrics.p95Latency,
                heartbeatsSent: self._metrics.heartbeatsSent + 1,
                heartbeatsAcked: self._metrics.heartbeatsAcked,
                heartbeatSuccessRate: self.calculateSuccessRate(sent: self._metrics.heartbeatsSent + 1, acked: self._metrics.heartbeatsAcked),
                reconnections: self._metrics.reconnections,
                messagesReceived: self._metrics.messagesReceived,
                messagesSent: self._metrics.messagesSent,
                uptime: self._metrics.uptime
            )
        }
    }

    /// Record heartbeat acknowledged with latency
    /// - Parameter latency: Latency in milliseconds
    public func heartbeatAcked(latency: TimeInterval) {
        queue.async {
            self.latencyHistory.append(latency)
            if self.latencyHistory.count > self.maxLatencySamples {
                self.latencyHistory.removeFirst()
            }

            let avgLatency = self.latencyHistory.reduce(0, +) / Double(self.latencyHistory.count)
            let sortedLatencies = self.latencyHistory.sorted()
            let p95Index = Int(Double(sortedLatencies.count) * 0.95)
            let p95Latency = sortedLatencies.indices.contains(p95Index) ? sortedLatencies[p95Index] : avgLatency

            self._metrics = GatewayHealthMetrics(
                averageLatency: avgLatency,
                p95Latency: p95Latency,
                heartbeatsSent: self._metrics.heartbeatsSent,
                heartbeatsAcked: self._metrics.heartbeatsAcked + 1,
                heartbeatSuccessRate: self.calculateSuccessRate(sent: self._metrics.heartbeatsSent, acked: self._metrics.heartbeatsAcked + 1),
                reconnections: self._metrics.reconnections,
                messagesReceived: self._metrics.messagesReceived,
                messagesSent: self._metrics.messagesSent,
                uptime: self._metrics.uptime
            )
        }
    }

    /// Record reconnection
    public func reconnected() {
        queue.async {
            self._metrics = GatewayHealthMetrics(
                averageLatency: self._metrics.averageLatency,
                p95Latency: self._metrics.p95Latency,
                heartbeatsSent: self._metrics.heartbeatsSent,
                heartbeatsAcked: self._metrics.heartbeatsAcked,
                heartbeatSuccessRate: self._metrics.heartbeatSuccessRate,
                reconnections: self._metrics.reconnections + 1,
                messagesReceived: self._metrics.messagesReceived,
                messagesSent: self._metrics.messagesSent,
                uptime: self._metrics.uptime
            )
        }
    }

    /// Record message received
    public func messageReceived() {
        queue.async {
            self._metrics = GatewayHealthMetrics(
                averageLatency: self._metrics.averageLatency,
                p95Latency: self._metrics.p95Latency,
                heartbeatsSent: self._metrics.heartbeatsSent,
                heartbeatsAcked: self._metrics.heartbeatsAcked,
                heartbeatSuccessRate: self._metrics.heartbeatSuccessRate,
                reconnections: self._metrics.reconnections,
                messagesReceived: self._metrics.messagesReceived + 1,
                messagesSent: self._metrics.messagesSent,
                uptime: self._metrics.uptime
            )
        }
    }

    /// Record message sent
    public func messageSent() {
        queue.async {
            self._metrics = GatewayHealthMetrics(
                averageLatency: self._metrics.averageLatency,
                p95Latency: self._metrics.p95Latency,
                heartbeatsSent: self._metrics.heartbeatsSent,
                heartbeatsAcked: self._metrics.heartbeatsAcked,
                heartbeatSuccessRate: self._metrics.heartbeatSuccessRate,
                reconnections: self._metrics.reconnections,
                messagesReceived: self._metrics.messagesReceived,
                messagesSent: self._metrics.messagesSent + 1,
                uptime: self._metrics.uptime
            )
        }
    }

    /// Update uptime
    /// - Parameter uptime: Current uptime in seconds
    public func updateUptime(_ uptime: TimeInterval) {
        queue.async {
            self._metrics = GatewayHealthMetrics(
                averageLatency: self._metrics.averageLatency,
                p95Latency: self._metrics.p95Latency,
                heartbeatsSent: self._metrics.heartbeatsSent,
                heartbeatsAcked: self._metrics.heartbeatsAcked,
                heartbeatSuccessRate: self._metrics.heartbeatSuccessRate,
                reconnections: self._metrics.reconnections,
                messagesReceived: self._metrics.messagesReceived,
                messagesSent: self._metrics.messagesSent,
                uptime: uptime
            )
        }
    }

    /// Get health status
    /// - Returns: Health status description
    public func healthStatus() -> String {
        let metrics = self.metrics
        let state = stateManager.currentState

        if state.state == .disconnected {
            return "Disconnected"
        }

        if metrics.heartbeatSuccessRate < 0.8 {
            return "Poor - Low heartbeat success rate (\(Int(metrics.heartbeatSuccessRate * 100))%)"
        }

        if metrics.averageLatency > 1000 {
            return "Degraded - High latency (\(Int(metrics.averageLatency))ms)"
        }

        if state.missedHeartbeats > 0 {
            return "Warning - Missed heartbeats (\(state.missedHeartbeats))"
        }

        return "Healthy"
    }

    /// Check if gateway is healthy
    /// - Returns: True if healthy
    public func isHealthy() -> Bool {
        let metrics = self.metrics
        let state = stateManager.currentState

        return state.state == .ready &&
               metrics.heartbeatSuccessRate >= 0.8 &&
               metrics.averageLatency <= 1000 &&
               state.missedHeartbeats == 0
    }

    private func calculateSuccessRate(sent: Int, acked: Int) -> Double {
        guard sent > 0 else { return 0 }
        return Double(acked) / Double(sent)
    }
}</content>
<parameter name="filePath">/home/quefep/Desktop/Github/quefep/Swift/SwiftDisc/Sources/SwiftDisc/HighLevel/GatewayHealthMonitor.swift