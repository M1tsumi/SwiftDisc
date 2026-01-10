//
//  ThreadsAndScheduledEventsBot.swift
//  SwiftDisc
//
//  Copyright © 2025 quefep. All rights reserved.
//

import Foundation
import SwiftDisc

@main
struct ThreadsAndScheduledEventsBot {
    static func main() async {
        let token = ProcessInfo.processInfo.environment["DISCORD_BOT_TOKEN"] ?? ""
        let client = DiscordClient(token: token)
        do {
            try await client.loginAndConnect(intents: [.guilds, .guildMembers])
        } catch {
            print("Failed to connect: \(error)")
            return
        }
        print("Listening for thread and scheduled event updates…")
        for await ev in client.events {
            switch ev {
            case .threadCreate(let ch):
                print("[THREAD_CREATE] #\(ch.name ?? "?") id=\(ch.id)")
            case .threadUpdate(let ch):
                print("[THREAD_UPDATE] #\(ch.name ?? "?") id=\(ch.id)")
            case .threadDelete(let ch):
                print("[THREAD_DELETE] id=\(ch.id)")
            case .threadMemberUpdate(let member):
                print("[THREAD_MEMBER_UPDATE] user=\(member.user_id ?? "?") threadMemberFlags=\(member.flags)")
            case .threadMembersUpdate(let update):
                print("[THREAD_MEMBERS_UPDATE] thread=\(update.id) added=\(update.added_members?.count ?? 0) removed=\(update.removed_member_ids?.count ?? 0)")
            case .guildScheduledEventCreate(let e):
                print("[GSE_CREATE] name=\(e.name) status=\(e.status) start=\(e.scheduled_start_time)")
            case .guildScheduledEventUpdate(let e):
                print("[GSE_UPDATE] name=\(e.name) status=\(e.status)")
            case .guildScheduledEventDelete(let e):
                print("[GSE_DELETE] name=\(e.name)")
            case .guildScheduledEventUserAdd(let u):
                print("[GSE_USER_ADD] event=\(u.guild_scheduled_event_id) user=\(u.user.id)")
            case .guildScheduledEventUserRemove(let u):
                print("[GSE_USER_REMOVE] event=\(u.guild_scheduled_event_id) user=\(u.user.id)")
            default:
                break
            }
        }
    }
}
