internal final class AffineSolveOutcome:Sendable {
    let local:NumericalWork
    let dynamics:NumericalWork
    let rank:NumericalWork
    let linear:NumericalWork
    let result:ConstrainedMotion?
    let failure:MechanismError?
    init(result:ConstrainedMotion,local:NumericalWork,dynamics:NumericalWork,rank:NumericalWork,linear:NumericalWork) {
        self.result=result;failure=nil;self.local=local;self.dynamics=dynamics;self.rank=rank;self.linear=linear
    }
    init(failure:MechanismError,local:NumericalWork,dynamics:NumericalWork,rank:NumericalWork,linear:NumericalWork) {
        result=nil;self.failure=failure;self.local=local;self.dynamics=dynamics;self.rank=rank;self.linear=linear
    }
}
