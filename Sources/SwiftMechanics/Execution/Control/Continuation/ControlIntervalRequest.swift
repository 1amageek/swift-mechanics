@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal final class ControlIntervalRequest: Sendable {
    let input:ControlSampleInput
    let equation:HeldPrismaticControlEquation
    let requested:Double
    init(input:ControlSampleInput,equation:HeldPrismaticControlEquation,requested:Double) {
        self.input=input;self.equation=equation;self.requested=requested
    }
}
