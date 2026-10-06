public enum XMLNodeContent: Sendable {
    case element(name: String, attributes: [XMLAttribute])
    case text(String)
    case comment(String)
}
