public struct MachineGroup<Content: Machine>: Machine {
    public let content: Content
    public init(@MachineBuilder content: () -> Content) { self.content = content() }
    public var body: Content { content }
}
