public struct CoSimulationWorkLedger: Sendable {
    internal enum Operation { case cold, observe, encoder, checkpoint, step, restart }
    public let budget: CoSimulationBudget
    public private(set) var admittedNumericalOperations = 0
    public private(set) var admittedNumericalIterations = 0
    public private(set) var peakNumericalScalars = 0
    public private(set) var admittedActuationWork = 0
    public private(set) var admittedValidationWork = 0
    public private(set) var admittedCodecByteCapacity = 0
    /// Reconciled returned ledgers only; opaque decode work and unreconciled failed work are not invented.
    public private(set) var recordedNumericalOperations = 0
    public private(set) var recordedNumericalIterations = 0
    public private(set) var recordedActuationWork = 0
    public private(set) var attemptedMacros: UInt64 = 0
    internal init(budget: CoSimulationBudget) { self.budget=budget }
    internal static func add(_ a: Int, _ b: Int) throws(CoSimulationFailure) -> Int {
        let next=a.addingReportingOverflow(b)
        guard a >= 0, b >= 0, !next.overflow else { throw .refusal(.capacity) }
        return next.partialValue
    }
    internal static func multiply(_ a: Int, _ b: Int) throws(CoSimulationFailure) -> Int {
        let next=a.multipliedReportingOverflow(by:b)
        guard a >= 0, b >= 0, !next.overflow else { throw .refusal(.capacity) }
        return next.partialValue
    }
    private mutating func reserve(operations: Int, iterations: Int, scalars: Int, actuation: Int,
                                  validation: Int, codec: Int) throws(CoSimulationFailure) {
        let n=try Self.add(admittedNumericalOperations,operations), i=try Self.add(admittedNumericalIterations,iterations)
        let a=try Self.add(admittedActuationWork,actuation), v=try Self.add(admittedValidationWork,validation)
        let c=try Self.add(admittedCodecByteCapacity,codec)
        guard n <= budget.numerical.arithmeticOperations, i <= budget.numerical.iterations,
              scalars <= budget.numerical.scalarStorage, a <= budget.maximumActuationWork,
              v <= budget.maximumValidationWork, c <= budget.maximumCodecByteCapacity else { throw .refusal(.capacity) }
        admittedNumericalOperations=n; admittedNumericalIterations=i; peakNumericalScalars=max(peakNumericalScalars,scalars)
        admittedActuationWork=a; admittedValidationWork=v; admittedCodecByteCapacity=c
    }
    internal mutating func reserve(_ operation: Operation, _ config: CoSimulationParticipantConfiguration) throws(CoSimulationFailure) {
        let p=config.control, cap=p.runtimeCapacity
        var ops=0, iterations=0, scalars=0, actuation=0, validation=0, codec=0
        switch operation {
        case .cold:
            ops=p.numerical.arithmeticOperations; iterations=p.numerical.iterations; scalars=p.numerical.scalarStorage
            actuation=try Self.multiply(2,p.actuation.maximumWork); validation=try Self.multiply(2,cap.maximumValidationWork)
        case .observe: actuation=p.actuation.maximumWork
        case .encoder:
            ops=config.encoderBudget.arithmeticOperations; iterations=config.encoderBudget.iterations; scalars=config.encoderBudget.scalarStorage
        case .checkpoint: codec=try Self.multiply(2,cap.maximumCheckpointBytes)
        case .step:
            ops=try Self.add(p.numerical.arithmeticOperations,p.integration.budget.maximumOuterArithmetic)
            iterations=p.numerical.iterations; scalars=try Self.add(p.numerical.scalarStorage,14)
            actuation=try Self.multiply(4,p.actuation.maximumWork)
            validation=try Self.add(try Self.multiply(2,cap.maximumValidationWork),cap.maximumStepWorkUnits)
        case .restart:
            actuation=try Self.multiply(2,p.actuation.maximumWork); validation=try Self.multiply(2,cap.maximumValidationWork)
            codec=cap.maximumCheckpointBytes
        }
        try reserve(operations:ops,iterations:iterations,scalars:scalars,actuation:actuation,validation:validation,codec:codec)
    }
    internal mutating func beginMacro() throws(CoSimulationFailure) {
        guard attemptedMacros < budget.maximumMacros else { throw .refusal(.capacity) }
        try reserve(operations:512,iterations:0,scalars:64,actuation:0,validation:0,codec:0)
        attemptedMacros += 1
    }
    internal mutating func record(_ numerical: NumericalWork, expectedBudget: NumericalBudget) throws(CoSimulationFailure) {
        guard numerical.budget == expectedBudget else { throw CoSimulationFailure(.unavailableSupplierWork,unavailable:true) }
        let n=try Self.add(recordedNumericalOperations,numerical.operations)
        let i=try Self.add(recordedNumericalIterations,numerical.iterations)
        guard n <= admittedNumericalOperations, i <= admittedNumericalIterations else { throw CoSimulationFailure(.unavailableSupplierWork,unavailable:true) }
        recordedNumericalOperations=n; recordedNumericalIterations=i
    }
    internal mutating func record(_ result: ControlStepResult) throws(CoSimulationFailure) {
        let report=result.integration.work
        guard !report.failedSupplierWorkUnavailable else { throw CoSimulationFailure(.unavailableSupplierWork,unavailable:true) }
        let n=try Self.add(recordedNumericalOperations,try Self.add(report.outerArithmeticBoundCharged,report.supplierArithmeticCharged))
        let i=try Self.add(recordedNumericalIterations,report.supplierIterationsCharged)
        let a=try Self.add(recordedActuationWork,result.actuationWork.used)
        guard n <= admittedNumericalOperations, i <= admittedNumericalIterations, a <= admittedActuationWork else { throw CoSimulationFailure(.unavailableSupplierWork,unavailable:true) }
        recordedNumericalOperations=n; recordedNumericalIterations=i; recordedActuationWork=a
    }
}
