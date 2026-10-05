public struct XMLAttribute: Sendable {
    public let name: String
    public let value: String
    public let location: XMLLocation
    public init(name: String, value: String, location: XMLLocation = XMLLocation()) {
        self.name = name; self.value = value; self.location = location
    }
}
