@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct StationaryLoadInvocation: Sendable {
    public let initialWork:LoadWork
    internal let owner:StationaryLoadExecution
    internal let ticket:Int
    internal init(owner:StationaryLoadExecution,ticket:Int,work:LoadWork) { self.owner=owner;self.ticket=ticket;initialWork=work }
}
