@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class StationaryAssemblyInvocation:Sendable {
    let reserved:Int
    let numerical:NumericalWork
    let load:StationaryLoadInvocation
    init(reserved:Int,numerical:NumericalWork,load:StationaryLoadInvocation) {
        self.reserved=reserved;self.numerical=numerical;self.load=load
    }
}
