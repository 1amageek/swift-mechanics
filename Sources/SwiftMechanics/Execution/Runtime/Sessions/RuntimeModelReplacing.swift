@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
public protocol RuntimeModelReplacing: RuntimeSessionOperating {
    func replaceModel(_ request: RuntimeModelReplacement) throws(RuntimeFailure) -> RuntimeAcceptedState
}
