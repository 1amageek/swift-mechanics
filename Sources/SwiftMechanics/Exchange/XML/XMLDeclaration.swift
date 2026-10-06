public struct XMLDeclaration: Equatable, Sendable {
    /// Nil means the standalone pseudo-attribute was absent.
    public let standalone: Bool?
    public init(standalone: Bool? = nil) { self.standalone = standalone }
}
