@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol StationaryLoadExecuting: Sendable {
    func beginInvocation() throws(StationaryLoadError) -> StationaryLoadInvocation
    func finishInvocation(_ invocation:StationaryLoadInvocation,work:LoadWork,failedSupplierWorkUnavailable:Bool) throws(StationaryLoadError)
    func report() -> StationaryLoadWorkReport
    func close() -> StationaryLoadWorkReport
}
