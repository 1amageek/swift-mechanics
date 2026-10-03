import MechanicsNumerics
import MechanicsRuntime

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal struct IntegrationStageWorkspace {
    var start: [Double]
    var stage: [Double]
    var result: [Double]
    var k1: [Double]
    var k2: [Double]
    var k3: [Double]
    var k4: [Double]
    var supplier: NumericalWork
    var outer = 0
    var calls = 0
    var unavailable = false
    let maximumOuter: Int
    let scalars: Int
    init(count: Int, maximumOuter: Int, supplier: NumericalBudget) throws(RuntimeFailure) {
        let (scalars, overflow) = count.multipliedReportingOverflow(by: 7)
        guard !overflow, scalars >= 0 else { throw RuntimeFailure(.integerOverflow, message: "Integration stage workspace count overflow.") }
        self.scalars = scalars; self.maximumOuter = maximumOuter; self.supplier = NumericalWork(budget: supplier)
        start = [Double](repeating: .nan, count: count); stage = start; result = start; k1 = start; k2 = start; k3 = start; k4 = start
    }
    mutating func charge(_ units: Int, control: RuntimeStepControl) throws(RuntimeFailure) {
        try control.beginWorkBlock(units: 1)
        let (next, overflow) = outer.addingReportingOverflow(units)
        guard units >= 0, !overflow, next <= maximumOuter else { throw RuntimeFailure(.capacityExceeded, message: "Outer integration arithmetic bound exhausted.") }
        outer = next
    }
    var report: IntegrationWorkReport { IntegrationWorkReport(outer: outer, supplier: supplier.operations, calls: calls, scalars: scalars, iterations: supplier.iterations, supplierScalars: supplier.peakScalarStorage, unavailable: unavailable) }
}
