@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal struct NonlinearEvolutionWorkspace {
    var work:NumericalWork
    var start:[Double]
    var k1:[Double]
    var k2:[Double]
    var k3:[Double]
    var k4:[Double]
    var stage:[Double]
    var result:[Double]
    var outer=0
    var calls=0
    var error:Double?
    var next:Double?
    var unavailable=false
    let maximumOuter:Int
    let reservedScalars:Int
    init(count:Int,budget:NumericalBudget,maximumOuter:Int) throws(RuntimeFailure) {
        work=NumericalWork(budget:budget);self.maximumOuter=maximumOuter
        do { reservedScalars=try NumericalWork.product(9,count);try work.requireStorage(reservedScalars) }
        catch { throw RuntimeFailure(.capacityExceeded,message:"Projected stage scalar capacity exhausted.") }
        start=[Double](repeating:0,count:count);k1=start;k2=start;k3=start;k4=start;stage=start;result=start
    }
    mutating func charge(_ count:Int,control:RuntimeStepControl) throws(RuntimeFailure) {
        try control.beginWorkBlock(units:1)
        let (value,overflow)=outer.addingReportingOverflow(count)
        guard count >= 0,!overflow,value <= maximumOuter else { throw RuntimeFailure(.capacityExceeded,message:"Projected outer arithmetic exhausted.") }
        outer=value
    }
    var evidence:NonlinearMechanismAttempt {
        NonlinearMechanismAttempt(work:NonlinearMechanismWorkReport(outer:outer,supplier:work.operations,calls:calls,scalars:reservedScalars,
            iterations:work.iterations,supplierScalars:work.peakScalarStorage,unavailable:unavailable),error:error,next:next)
    }
}
