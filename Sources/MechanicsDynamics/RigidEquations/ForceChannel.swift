/// Channels identify known supplied loads; constraint/contact labels do not infer unknown reactions.
public enum ForceChannel: Equatable, Sendable { case actuator, applied, constraint, contact }
