//
//  GatewayStateManager.swift
//  SwiftDisc
//
//  Created by SwiftDisc Team
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

/// Manages gateway connection state and health monitoring
public class GatewayStateManager: Sendable {
    private let queue = DispatchQueue(label: "com.swiftdisc.gateway.state")
    private var _state: GatewayStateSnapshot

    /// Current gateway state
    public var currentState: GatewayStateSnapshot {
        queue.sync { _state }
    }

    /// Initialize state manager
    public init() {
        self._state = GatewayStateSnapshot(
            state: .disconnected,
            lastHeartbeatSent: nil,
            lastHeartbeatAck: nil,
            heartbeatInterval: nil,
            missedHeartbeats: 0,
            lastSequence: nil,
            sessionId: nil,
            resumeUrl: nil,
            connectionAttempts: 0,
            lastError: nil,
            uptime: nil
        )
    }

    /// Update connection state
    /// - Parameter state: New connection state
    public func updateState(_ state: GatewayStateSnapshot.GatewayConnectionState) {
        queue.async {
            let now = Date()
            var uptime: TimeInterval?

            if state == .connected && self._state.state != .connected {
                // Connection established, start uptime tracking
                uptime = 0
            } else if state == .connected && self._state.uptime != nil {
                // Continue tracking uptime
                uptime = self._state.uptime! + (now.timeIntervalSince(self._state.lastHeartbeatAck ?? now))
            }

            self._state = GatewayStateSnapshot(
                state: state,
                lastHeartbeatSent: self._state.lastHeartbeatSent,
                lastHeartbeatAck: self._state.lastHeartbeatAck,
                heartbeatInterval: self._state.heartbeatInterval,
                missedHeartbeats: state == .connected ? 0 : self._state.missedHeartbeats,
                lastSequence: self._state.lastSequence,
                sessionId: self._state.sessionId,
                resumeUrl: self._state.resumeUrl,
                connectionAttempts: state == .connecting ? self._state.connectionAttempts + 1 : self._state.connectionAttempts,
                lastError: state == .connected ? nil : self._state.lastError,
                uptime: uptime
            )
        }
    }

    /// Record heartbeat sent
    public func heartbeatSent() {
        queue.async {
            self._state = GatewayStateSnapshot(
                state: self._state.state,
                lastHeartbeatSent: Date(),
                lastHeartbeatAck: self._state.lastHeartbeatAck,
                heartbeatInterval: self._state.heartbeatInterval,
                missedHeartbeats: self._state.missedHeartbeats,
                lastSequence: self._state.lastSequence,
                sessionId: self._state.sessionId,
                resumeUrl: self._state.resumeUrl,
                connectionAttempts: self._state.connectionAttempts,
                lastError: self._state.lastError,
                uptime: self._state.uptime
            )
        }
    }

    /// Record heartbeat acknowledged
    public func heartbeatAcked() {
        queue.async {
            let now = Date()
            let uptime = self._state.uptime != nil ?
                self._state.uptime! + (now.timeIntervalSince(self._state.lastHeartbeatAck ?? now)) : nil

            self._state = GatewayStateSnapshot(
                state: self._state.state,
                lastHeartbeatSent: self._state.lastHeartbeatSent,
                lastHeartbeatAck: now,
                heartbeatInterval: self._state.heartbeatInterval,
                missedHeartbeats: 0,
                lastSequence: self._state.lastSequence,
                sessionId: self._state.sessionId,
                resumeUrl: self._state.resumeUrl,
                connectionAttempts: self._state.connectionAttempts,
                lastError: self._state.lastError,
                uptime: uptime
            )
        }
    }

    /// Record missed heartbeat
    public func heartbeatMissed() {
        queue.async {
            self._state = GatewayStateSnapshot(
                state: self._state.state,
                lastHeartbeatSent: self._state.lastHeartbeatSent,
                lastHeartbeatAck: self._state.lastHeartbeatAck,
                heartbeatInterval: self._state.heartbeatInterval,
                missedHeartbeats: self._state.missedHeartbeats + 1,
                lastSequence: self._state.lastSequence,
                sessionId: self._state.sessionId,
                resumeUrl: self._state.resumeUrl,
                connectionAttempts: self._state.connectionAttempts,
                lastError: self._state.lastError,
                uptime: self._state.uptime
            )
        }
    }

    /// Update heartbeat interval
    /// - Parameter interval: Heartbeat interval in milliseconds
    public func setHeartbeatInterval(_ interval: TimeInterval) {
        queue.async {
            self._state = GatewayStateSnapshot(
                state: self._state.state,
                lastHeartbeatSent: self._state.lastHeartbeatSent,
                lastHeartbeatAck: self._state.lastHeartbeatAck,
                heartbeatInterval: interval / 1000, // Convert to seconds
                missedHeartbeats: self._state.missedHeartbeats,
                lastSequence: self._state.lastSequence,
                sessionId: self._state.sessionId,
                resumeUrl: self._state.resumeUrl,
                connectionAttempts: self._state.connectionAttempts,
                lastError: self._state.lastError,
                uptime: self._state.uptime
            )
        }
    }

    /// Update sequence number
    /// - Parameter sequence: Last sequence number received
    public func updateSequence(_ sequence: Int) {
        queue.async {
            self._state = GatewayStateSnapshot(
                state: self._state.state,
                lastHeartbeatSent: self._state.lastHeartbeatSent,
                lastHeartbeatAck: self._state.lastHeartbeatAck,
                heartbeatInterval: self._state.heartbeatInterval,
                missedHeartbeats: self._state.missedHeartbeats,
                lastSequence: sequence,
                sessionId: self._state.sessionId,
                resumeUrl: self._state.resumeUrl,
                connectionAttempts: self._state.connectionAttempts,
                lastError: self._state.lastError,
                uptime: self._state.uptime
            )
        }
    }

    /// Update session information
    /// - Parameters:
    ///   - sessionId: Session ID
    ///   - resumeUrl: Resume URL
    public func updateSession(sessionId: String, resumeUrl: String?) {
        queue.async {
            self._state = GatewayStateSnapshot(
                state: self._state.state,
                lastHeartbeatSent: self._state.lastHeartbeatSent,
                lastHeartbeatAck: self._state.lastHeartbeatAck,
                heartbeatInterval: self._state.heartbeatInterval,
                missedHeartbeats: self._state.missedHeartbeats,
                lastSequence: self._state.lastSequence,
                sessionId: sessionId,
                resumeUrl: resumeUrl,
                connectionAttempts: self._state.connectionAttempts,
                lastError: self._state.lastError,
                uptime: self._state.uptime
            )
        }
    }

    /// Record connection error
    /// - Parameter error: Error description
    public func connectionError(_ error: String) {
        queue.async {
            self._state = GatewayStateSnapshot(
                state: .disconnected,
                lastHeartbeatSent: self._state.lastHeartbeatSent,
                lastHeartbeatAck: self._state.lastHeartbeatAck,
                heartbeatInterval: self._state.heartbeatInterval,
                missedHeartbeats: self._state.missedHeartbeats,
                lastSequence: self._state.lastSequence,
                sessionId: self._state.sessionId,
                resumeUrl: self._state.resumeUrl,
                connectionAttempts: self._state.connectionAttempts,
                lastError: error,
                uptime: nil
            )
        }
    }

    /// Check if connection should be considered unhealthy
    /// - Returns: True if connection is unhealthy
    public func isUnhealthy() -> Bool {
        let state = currentState
        return state.missedHeartbeats >= 3 || state.state == .disconnected
    }

    /// Get current latency in milliseconds
    /// - Returns: Latency if available
    public func currentLatency() -> TimeInterval? {
        let state = currentState
        guard let sent = state.lastHeartbeatSent, let ack = state.lastHeartbeatAck else {
            return nil
        }
        return ack.timeIntervalSince(sent) * 1000
    }
}</content>
<parameter name="filePath">/home/quefep/Desktop/Github/quefep/Swift/SwiftDisc/Sources/SwiftDisc/HighLevel/GatewayStateManager.swift