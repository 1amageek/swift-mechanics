@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal final class ControlIntervalAdvance: Sendable {
    let request:ControlIntervalRequest
    let result:IntegrationAdvanceResult
    init(request:ControlIntervalRequest,result:IntegrationAdvanceResult) {
        self.request=request;self.result=result
    }
}
