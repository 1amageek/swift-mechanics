@resultBuilder
public enum MachineBuilder {
    public static func buildExpression<Content: Machine>(_ content: Content) -> Content { content }
    public static func buildBlock() -> EmptyMachine { EmptyMachine() }
    public static func buildPartialBlock<Content: Machine>(first: Content) -> Content { first }
    public static func buildPartialBlock<First: Machine, Second: Machine>(accumulated: First, next: Second) -> ErasedPairMachine {
        ErasedPairMachine(accumulated, next)
    }
    public static func buildOptional<Content: Machine>(_ content: Content?) -> OptionalMachine<Content> { OptionalMachine(content) }
    public static func buildEither<First: Machine, Second: Machine>(first: First) -> ConditionalMachine<First, Second> { .first(first) }
    public static func buildEither<First: Machine, Second: Machine>(second: Second) -> ConditionalMachine<First, Second> { .second(second) }
    public static func buildArray<Content: Machine>(_ elements: [Content]) -> ArrayMachine<Content> { ArrayMachine(elements) }
    public static func buildLimitedAvailability<Content: Machine>(_ content: Content) -> AnyMachine { AnyMachine(content) }
}
