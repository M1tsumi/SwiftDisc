import Foundation

public struct ActivityBuilder {
    private var name: String
    private var type: Int = 0 // 0 = playing, 2 = listening, 3 = watching, etc.
    private var state: String?
    private var details: String?
    private var start: Int64?
    private var end: Int64?
    private var largeImage: String?
    private var largeText: String?
    private var smallImage: String?
    private var smallText: String?
    private var buttons: [String]?
    private var partyId: String?
    private var partySize: [Int]?
    private var secretJoin: String?
    private var secretSpectate: String?
    private var secretMatch: String?

    public init(name: String) { self.name = name }

    public func playing() -> ActivityBuilder { var c = self; c.type = 0; return c }
    public func streaming() -> ActivityBuilder { var c = self; c.type = 1; return c }
    public func listening() -> ActivityBuilder { var c = self; c.type = 2; return c }
    public func watching() -> ActivityBuilder { var c = self; c.type = 3; return c }
    public func competing() -> ActivityBuilder { var c = self; c.type = 5; return c }

    public func state(_ v: String) -> ActivityBuilder { var c = self; c.state = v; return c }
    public func details(_ v: String) -> ActivityBuilder { var c = self; c.details = v; return c }

    public func timestamps(start: Int64? = nil, end: Int64? = nil) -> ActivityBuilder { var c = self; c.start = start; c.end = end; return c }

    public func assets(largeImage: String? = nil, largeText: String? = nil, smallImage: String? = nil, smallText: String? = nil) -> ActivityBuilder {
        var c = self
        c.largeImage = largeImage
        c.largeText = largeText
        c.smallImage = smallImage
        c.smallText = smallText
        return c
    }

    public func withButtons(_ labels: [String]) -> ActivityBuilder { var c = self; c.buttons = labels; return c }

    public func party(id: String? = nil, size: [Int]? = nil) -> ActivityBuilder { var c = self; c.partyId = id; c.partySize = size; return c }

    public func secrets(join: String? = nil, spectate: String? = nil, match: String? = nil) -> ActivityBuilder { var c = self; c.secretJoin = join; c.secretSpectate = spectate; c.secretMatch = match; return c }

    public func build() -> PresenceUpdatePayload.Activity {
        let ts = (start == nil && end == nil) ? nil : .init(start: start, end: end)
        let assets = (largeImage == nil && largeText == nil && smallImage == nil && smallText == nil) ? nil : .init(large_image: largeImage, large_text: largeText, small_image: smallImage, small_text: smallText)
        let party = (partyId == nil && partySize == nil) ? nil : .init(id: partyId, size: partySize)
        let secrets = (secretJoin == nil && secretSpectate == nil && secretMatch == nil) ? nil : .init(join: secretJoin, spectate: secretSpectate, match: secretMatch)
        return .init(name: name, type: type, state: state, details: details, timestamps: ts, assets: assets, buttons: buttons, party: party, secrets: secrets)
    }
}
