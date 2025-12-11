import SwiftDisc
import Foundation

@main
struct LinkedRolesBot {
    static func main() async {
        let token = ProcessInfo.processInfo.environment["DISCORD_BOT_TOKEN"] ?? ""
        let client = DiscordClient(token: token)
        
        do {
            try await client.loginAndConnect(intents: [.guilds])
            
            for await event in client.events {
                switch event {
                case .ready(let info):
                    print("Logged in as \(info.user.username)")
                    await setupRoleConnections(client: client, applicationId: info.application.id)
                    
                default:
                    break
                }
            }
        } catch {
            print("Error: \(error)")
        }
    }
    
    static func setupRoleConnections(client: DiscordClient, applicationId: ApplicationID) async {
        do {
            // Define the metadata schema for your application
            let metadataSchema = [
                ApplicationRoleConnectionMetadata(
                    type: .booleanEqual,
                    key: "is_premium_member",
                    name: "Premium Member",
                    description: "Whether the user has a premium membership"
                ),
                ApplicationRoleConnectionMetadata(
                    type: .integerGreaterThanOrEqual,
                    key: "account_level",
                    name: "Account Level",
                    description: "The user's account level (must be at least the specified level)"
                ),
                ApplicationRoleConnectionMetadata(
                    type: .datetimeGreaterThanOrEqual,
                    key: "join_date",
                    name: "Join Date",
                    description: "When the user joined your platform"
                ),
                ApplicationRoleConnectionMetadata(
                    type: .booleanEqual,
                    key: "verified_email",
                    name: "Verified Email",
                    description: "Whether the user has verified their email address"
                )
            ]
            
            // Register the metadata schema with Discord
            print("Registering role connection metadata...")
            let registeredMetadata = try await client.updateApplicationRoleConnectionMetadata(
                applicationId: applicationId,
                metadata: metadataSchema
            )
            
            print("Successfully registered \(registeredMetadata.count) metadata fields:")
            for metadata in registeredMetadata {
                print("  - \(metadata.name) (\(metadata.key)): \(metadata.description)")
            }
            
            // Example: Update a user's role connection data
            // This would typically be done after a user connects their account via OAuth2
            await exampleUpdateUserRoleConnection(client: client, applicationId: applicationId)
            
        } catch {
            print("Failed to setup role connections: \(error)")
        }
    }
    
    static func exampleUpdateUserRoleConnection(client: DiscordClient, applicationId: ApplicationID) async {
        do {
            // Example user data from your platform
            let userData = [
                "is_premium_member": "true",
                "account_level": "25",
                "join_date": "1640995200", // Unix timestamp for 2022-01-01
                "verified_email": "true"
            ]
            
            // Update the user's role connection
            print("Updating user role connection...")
            let connection = try await client.updateUserApplicationRoleConnection(
                applicationId: applicationId,
                platformName: "MyPlatform",
                platformUsername: "example_user",
                metadata: userData
            )
            
            print("Updated role connection:")
            print("  Platform: \(connection.platformName ?? "N/A")")
            print("  Username: \(connection.platformUsername ?? "N/A")")
            print("  Metadata: \(connection.metadata)")
            
        } catch {
            print("Failed to update user role connection: \(error)")
        }
    }
}

// MARK: - OAuth2 Flow Helper
/*
 To implement the complete OAuth2 flow for role connections, you'll need:
 
 1. Set up an OAuth2 redirect URI in your Discord application settings
 2. Request the `role_connections.write` scope during OAuth2 authorization
 3. Handle the OAuth2 callback to get the access token
 4. Use the access token to make role connection API calls on behalf of the user
 
 Example OAuth2 authorization URL:
 https://discord.com/oauth2/authorize?client_id=YOUR_APP_ID&redirect_uri=YOUR_REDIRECT_URI&response_type=code&scope=role_connections.write&prompt=consent
 
 After getting the access token, you can create a new DiscordClient instance:
 
 let oauthClient = DiscordClient(token: accessToken)
 let connection = try await oauthClient.updateUserApplicationRoleConnection(
     applicationId: yourAppId,
     platformName: "MyPlatform",
     platformUsername: username,
     metadata: userMetadata
 )
 */
