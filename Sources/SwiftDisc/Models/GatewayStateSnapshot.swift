//
//  GatewayStateSnapshot.swift
//  SwiftDisc
//
//  Created by SwiftDisc Team
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

/// Snapshot of gateway connection state
public struct GatewayStateSnapshot: Codable, Sendable {
    /// Current connection state
    public let state: GatewayConnectionState
    /// Last heartbeat sent timestamp
    public let lastHeartbeatSent: Date?
    /// Last heartbeat acknowledged timestamp
    public let lastHeartbeatAck: Date?
    /// Current heartbeat interval
    public let heartbeatInterval: TimeInterval?
    /// Number of consecutive missed heartbeats
    public let missedHeartbeats: Int
    /// Last sequence number received
    public let lastSequence: Int?
    /// Session ID
    public let sessionId: String?
    /// Resume URL
    public let resumeUrl: String?
    /// Connection attempt count
    public let connectionAttempts: Int
    /// Last connection error
    public let lastError: String?
    /// Connection uptime
    public let uptime: TimeInterval?

    public enum GatewayConnectionState: String, Codable, Sendable {
        case disconnected
        case connecting
        case connected
        case identifying
        case ready
        case resuming
        case reconnecting
    }
}

/// Gateway health metrics
public struct GatewayHealthMetrics: Codable, Sendable {
    /// Average latency in milliseconds
    public let averageLatency: Double
    /// 95th percentile latency
    public let p95Latency: Double
    /// Total heartbeats sent
    public let heartbeatsSent: Int
    /// Total heartbeats acknowledged
    public let heartbeatsAcked: Int
    /// Heartbeat success rate (0.0 to 1.0)
    public let heartbeatSuccessRate: Double
    /// Total reconnections
    public let reconnections: Int
    /// Total messages received
    public let messagesReceived: Int
    /// Total messages sent
    public let messagesSent: Int
    /// Current connection uptime
    public let uptime: TimeInterval
}</content>
<parameter name="filePath">/home/quefep/Desktop/Github/quefep/Swift/SwiftDisc/Sources/SwiftDisc/Models/GatewayStateSnapshot.swift