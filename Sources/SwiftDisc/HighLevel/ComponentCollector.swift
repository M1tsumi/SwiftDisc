//
//  ComponentCollector.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation

public extension DiscordClient {
    /// Collect component interactions (buttons/selects) matching an optional `customId` filter.
    /// Returns an `AsyncStream<Interaction>` yielding matching Interaction objects.
    func createComponentCollector(customId: String? = nil, timeout: TimeInterval? = nil, max: Int? = nil) -> AsyncStream<Interaction> {
        AsyncStream { continuation in
            var collected = 0

            let task = Task {
                for await event in self.events {
                    switch event {
                    case .interactionCreate(let interaction):
                        // component interactions typically have a data.custom_id field
                        if let data = interaction.data, data.custom_id != nil {
                            if let cid = customId, data.custom_id != cid { continue }
                            continuation.yield(interaction)
                            collected += 1
                            if let max, collected >= max {
                                continuation.finish()
                                return
                            }
                        }
                    default: break
                    }
                }
                continuation.finish()
            }

            if let t = timeout {
                Task {
                    try? await Task.sleep(nanoseconds: UInt64(t * 1_000_000_000))
                    continuation.finish()
                    task.cancel()
                }
            }
        }
    }
}
