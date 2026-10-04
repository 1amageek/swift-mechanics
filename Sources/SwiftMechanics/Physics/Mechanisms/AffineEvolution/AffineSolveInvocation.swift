internal final class AffineSolveInvocation:Sendable {
    let reserved:Int
    let partitionWork:Bool
    let drive:[Double]
    let local:NumericalWork
    let dynamics:NumericalWork
    let rank:NumericalWork
    let linear:NumericalWork
    init(reserved:Int,partitionWork:Bool,drive:[Double],local:NumericalWork,dynamics:NumericalWork,rank:NumericalWork,linear:NumericalWork) {
        self.reserved=reserved;self.partitionWork=partitionWork;self.drive=drive
        self.local=local;self.dynamics=dynamics;self.rank=rank;self.linear=linear
    }
}
