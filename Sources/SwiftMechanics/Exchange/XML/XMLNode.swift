/// Parent indices refer only to the containing document's preorder node table.
public struct XMLNode: Sendable {
    public let parent: Int?
    public let content: XMLNodeContent
    public let location: XMLLocation
    public init(parent: Int?, content: XMLNodeContent, location: XMLLocation = XMLLocation()) {
        self.parent = parent; self.content = content; self.location = location
    }
}
