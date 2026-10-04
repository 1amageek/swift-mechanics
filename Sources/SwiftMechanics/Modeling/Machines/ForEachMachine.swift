/// Content and identity closures execute only during budgeted definition lowering.
public struct ForEachMachine<Data: RandomAccessCollection & Sendable, Content: Machine>: Machine where Data.Element: Sendable {
    public let data: Data
    private let identity: @Sendable (Data.Element) -> String
    private let content: @Sendable (Data.Element) -> Content
    public init(_ data: Data, id: @escaping @Sendable (Data.Element) -> String,
                @MachineBuilder content: @escaping @Sendable (Data.Element) -> Content) {
        self.data = data; identity = id; self.content = content
    }
    public var body: Never { fatalError("Lazy lowering must not evaluate body.") }
    public func _makeDefinition(into context: inout MachineDefinitionContext) throws(MachineDefinitionFailure) {
        for element in data {
            try context.admitIteration()
            try context.enterInstance(identity(element))
            defer { context.leaveInstance() }
            try context.lower(content(element))
        }
    }
}
