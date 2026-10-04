internal final class StationaryAssemblyOutcome:Sendable {
    let numerical:NumericalWork
    let load:LoadWork
    let output:AffineMotionSystem?
    let failure:RuntimeFailure?
    init(output:AffineMotionSystem,numerical:NumericalWork,load:LoadWork) {
        self.output=output;failure=nil;self.numerical=numerical;self.load=load
    }
    init(failure:RuntimeFailure,numerical:NumericalWork,load:LoadWork) {
        output=nil;self.failure=failure;self.numerical=numerical;self.load=load
    }
}
