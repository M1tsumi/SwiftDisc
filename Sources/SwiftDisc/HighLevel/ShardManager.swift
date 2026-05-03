import Foundation

/// Shard manager: maintains one `DiscordClient` per shard and starts them.
public actor ShardManager {
    private var clients: [DiscordClient] = []
    private var shardCount: Int
    private var token: String
    private var config: DiscordConfiguration
    private var healthCheckTask: Task<Void, Never>?
    private var healthCheckInterval: TimeInterval = 60 // seconds
    private var onShardHealthUpdate: ((Int, ShardHealth) -> Void)?
    private var shardHealth: [Int: ShardHealth] = [:]

    public enum ShardHealth {
        case connected
        case disconnected
        case error(Error)
        case connecting
    }

    public init(shardCount: Int, token: String, config: DiscordConfiguration) {
        self.shardCount = shardCount
        self.token = token
        self.config = config
    }
    
    /// Set a callback to be notified of shard health changes.
    public func setHealthCallback(_ callback: @escaping (Int, ShardHealth) -> Void) {
        self.onShardHealthUpdate = callback
    }
    
    /// Set the health check interval in seconds.
    public func setHealthCheckInterval(_ interval: TimeInterval) {
        self.healthCheckInterval = interval
    }

    /// Start all shards. Each shard runs in its own task.
    public func start() async {
        for i in 0..<shardCount {
            let client = DiscordClient(token: token, config: config)
            clients.append(client)
            shardHealth[i] = .disconnected
        }
        
        // Start health monitoring
        startHealthMonitoring()
        
        await withTaskGroup(of: Void.self) { group in
            for (index, client) in clients.enumerated() {
                group.addTask {
                    do {
                        await self.updateShardHealth(index, .connecting)
                        try await client.connect(shardId: index, shardCount: self.shardCount)
                        await self.updateShardHealth(index, .connected)
                    } catch {
                        await self.updateShardHealth(index, .error(error))
                    }
                }
            }
        }
    }
    
    /// Gracefully shut down all shards.
    public func shutdown() async {
        healthCheckTask?.cancel()
        healthCheckTask = nil
        
        // Note: DiscordClient doesn't currently expose a disconnect method
        // This is a placeholder for when that functionality becomes available
        for (index, _) in clients.enumerated() {
            shardHealth[index] = .disconnected
        }
        clients.removeAll()
    }
    
    /// Get the current health status of all shards.
    public func getShardHealth() async -> [Int: ShardHealth] {
        return shardHealth
    }
    
    /// Get the number of connected shards.
    public func connectedShardCount() async -> Int {
        return shardHealth.values.filter {
            if case .connected = $0 { return true }
            return false
        }.count
    }
    
    /// Restart a specific shard.
    public func restartShard(_ index: Int) async {
        guard index < clients.count else { return }
        let client = clients[index]
        
        // Note: DiscordClient doesn't currently expose a disconnect method
        // This is a placeholder for when that functionality becomes available
        
        // Reconnect
        Task {
            do {
                await updateShardHealth(index, .connecting)
                try await client.connect(shardId: index, shardCount: shardCount)
                await updateShardHealth(index, .connected)
            } catch {
                await updateShardHealth(index, .error(error))
            }
        }
    }
    
    private func startHealthMonitoring() {
        healthCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(healthCheckInterval * 1_000_000_000))
                await self?.checkShardHealth()
            }
        }
    }
    
    private func checkShardHealth() async {
        // Note: DiscordClient doesn't currently expose connection state
        // This is a placeholder for when that functionality becomes available
        // In a real implementation, we would query each client's connection state
        // and update shardHealth accordingly
    }
    
    private func updateShardHealth(_ index: Int, _ health: ShardHealth) async {
        let previous = shardHealth[index]
        shardHealth[index] = health
        
        // Only notify if health state actually changed
        if previous != health {
            await onShardHealthUpdate?(index, health)
        }
    }
}
