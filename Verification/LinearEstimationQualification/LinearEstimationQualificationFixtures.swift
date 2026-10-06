import SwiftMechanics

public enum LinearEstimationQualificationFixtures {
    public static func require(_ condition: Bool, _ message: String) throws(LinearEstimationQualificationError) {
        guard condition else { throw .assertion(message) }
    }
    public static func near(_ actual: Double, _ expected: Double, _ message: String) throws(LinearEstimationQualificationError) {
        try require(actual.isFinite && expected.isFinite && abs(actual-expected) <= 1e-11 + 1e-11*max(abs(actual),abs(expected)), message)
    }
    public static func matrix(_ matrix: DenseMatrix<Double>, _ expected: [Double], _ message: String) throws {
        try require(matrix.rowCount*matrix.columnCount == expected.count, message+" shape")
        for i in 0..<matrix.rowCount { for j in 0..<matrix.columnCount {
            try near(matrix.coefficient(row:i,column:j),expected[i*matrix.columnCount+j],message)
        } }
    }
    public static func work(operations: Int = 1_000_000, storage: Int = 100_000, iterations: Int = 1000) throws(NumericalError) -> NumericalWork {
        NumericalWork(budget: try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:iterations))
    }
    public static func policy(stateCount: Int = 4, metadata: Int = 256, bytes: Int = 4096,
                              magnitude: Double = 1e6, covariance: Double = 1e-12,
                              rank: Double = 1e-12, pivot: Double = 1e-14,
                              cancelled: @escaping @Sendable () -> Bool = { false }) throws(NumericalError) -> LinearEstimatorPolicy {
        LinearEstimatorPolicy(maximumStateCount:stateCount,maximumInputCount:4,maximumObservationCount:4,
            maximumMetadataBytes:metadata,maximumContinuationBytes:bytes,maximumCoefficientMagnitude:magnitude,
            covarianceTolerance:covariance,rankThreshold:rank,
            solveTolerance:try LinearTolerance(absoluteResidual:1e-12,relativeResidual:1e-12,pivotThreshold:pivot),isCancelled:cancelled)
    }
    public static func coordinate(_ name: String) -> LinearEstimatorCoordinate {
        LinearEstimatorCoordinate(identity:name,frame:"world",dimension:.dimensionless,normalizationSI:1)
    }
    public static func model(n: Int = 1, m: Int = 1, a: [Double] = [2], b: [Double] = [3], h: [Double] = [1],
                             q: [Double] = [1], r: [Double] = [4], admittedPolicy: LinearEstimatorPolicy? = nil,
                             clock: LinearEstimatorClock = LinearEstimatorClock(epochSeconds:2,periodSeconds:0.5,maximumTick:10),
                             revision: UInt64 = 19, sourceRevision: UInt64 = 17) throws -> LinearEstimatorModel {
        let selected: LinearEstimatorPolicy
        if let admittedPolicy { selected = admittedPolicy } else { selected = try policy() }
        let states = n == 1 ? [coordinate("x")] : [coordinate("x"),coordinate("v")]
        let observations = m == 1 ? [coordinate("z")] : [coordinate("z"),coordinate("w")]
        var ledger = try work()
        let service: any LinearEstimating = ReferenceLinearEstimator()
        return try service.admit(source:ModelStamp(identity:"linear-estimation-model",revision:sourceRevision),filterIdentity:"kf",
            filterRevision:revision,chartIdentity:"normalized-cartesian",clock:clock,stateCoordinates:states,
            inputCoordinates:[coordinate("u")],observationCoordinates:observations,
            transition:DenseMatrix(rows:n,columns:n,values:a),input:DenseMatrix(rows:n,columns:1,values:b),
            observation:DenseMatrix(rows:m,columns:n,values:h),processCovariance:DenseMatrix(rows:n,columns:n,values:q),
            observationCovariance:DenseMatrix(rows:m,columns:m,values:r),policy:selected,work:&ledger)
    }
    public static func initial(_ model: LinearEstimatorModel, mean: [Double] = [1], p: [Double] = [2],
                               admittedPolicy: LinearEstimatorPolicy? = nil) throws -> LinearEstimatorState {
        let selected: LinearEstimatorPolicy
        if let admittedPolicy { selected = admittedPolicy } else { selected = try policy() }
        var ledger = try work()
        let service: any LinearEstimating = ReferenceLinearEstimator()
        return try service.initialize(model:model,mean:mean,covariance:DenseMatrix(rows:mean.count,columns:mean.count,values:p),policy:selected,work:&ledger)
    }
    public static func input(_ state: LinearEstimatorState, values: [Double] = [2], source: ModelStamp? = nil,
                             revision: UInt64? = nil, coordinates: [LinearEstimatorCoordinate]? = nil,
                             start: Double? = nil, end: Double? = nil) -> LinearEstimatorInput {
        LinearEstimatorInput(source:source ?? state.model.source,filterIdentity:state.model.filterIdentity,
            filterRevision:revision ?? state.model.filterRevision,coordinates:coordinates ?? state.model.inputCoordinates,
            intervalStartSeconds:start ?? state.timeSeconds,intervalEndSeconds:end ?? (state.timeSeconds+state.model.clock.periodSeconds),normalizedValues:values)
    }
    public static func reading(_ state: LinearEstimatorState, values: [Double] = [10], sequence: UInt64 = 7,
                               sample: Double? = nil, delivery: Double? = nil, source: ModelStamp? = nil,
                               revision: UInt64? = nil, coordinates: [LinearEstimatorCoordinate]? = nil) -> LinearEstimatorObservation {
        LinearEstimatorObservation(source:source ?? state.model.source,filterIdentity:state.model.filterIdentity,
            filterRevision:revision ?? state.model.filterRevision,coordinates:coordinates ?? state.model.observationCoordinates,
            sequence:sequence,sampleTimeSeconds:sample ?? state.timeSeconds,deliveryTimeSeconds:delivery ?? state.timeSeconds,normalizedValues:values)
    }
    public static func predicted(_ state: LinearEstimatorState, values: [Double] = [2], admittedPolicy: LinearEstimatorPolicy? = nil) throws -> LinearEstimatorState {
        let selected: LinearEstimatorPolicy
        if let admittedPolicy { selected = admittedPolicy } else { selected = try policy() }
        var ledger = try work()
        let service: any LinearEstimating = ReferenceLinearEstimator()
        return try service.predict(state,input:input(state,values:values),policy:selected,work:&ledger)
    }
    public static func failure(_ operation: () throws(LinearEstimatorFailure) -> Void) throws(LinearEstimationQualificationError) -> LinearEstimatorFailure {
        do { try operation() } catch { return error }
        throw .assertion("Expected original typed estimator failure")
    }
    public static func sameState(_ actual: LinearEstimatorState, _ expected: LinearEstimatorState) throws {
        try require(actual.model.source==expected.model.source && actual.model.filterIdentity==expected.model.filterIdentity &&
            actual.model.filterRevision==expected.model.filterRevision && actual.model.chartIdentity==expected.model.chartIdentity &&
            actual.model.clock==expected.model.clock && actual.model.stateCoordinates==expected.model.stateCoordinates &&
            actual.model.inputCoordinates==expected.model.inputCoordinates && actual.model.observationCoordinates==expected.model.observationCoordinates,"Original model association prefix")
        try require(actual.tick==expected.tick && actual.timeSeconds.bitPattern==expected.timeSeconds.bitPattern &&
            actual.sampleResolved==expected.sampleResolved && actual.lastObservationSequence==expected.lastObservationSequence &&
            actual.lastObservationTimeSeconds?.bitPattern==expected.lastObservationTimeSeconds?.bitPattern,"Original temporal prefix")
        try require(actual.mean.count==expected.mean.count,"Original mean shape")
        for i in actual.mean.indices { try require(actual.mean[i].bitPattern==expected.mean[i].bitPattern,"Original mean bits") }
        let pairs = [(actual.covariance,expected.covariance),(actual.model.transition,expected.model.transition),
            (actual.model.input,expected.model.input),(actual.model.observation,expected.model.observation),
            (actual.model.processCovariance,expected.model.processCovariance),(actual.model.observationCovariance,expected.model.observationCovariance)]
        for (a,b) in pairs {
            try require(a.rowCount==b.rowCount && a.columnCount==b.columnCount,"Original covariance/model shape")
            for i in 0..<a.rowCount { for j in 0..<a.columnCount {
                try require(a.coefficient(row:i,column:j).bitPattern==b.coefficient(row:i,column:j).bitPattern,"Original covariance/model bits")
            } }
        }
    }
    public static func prefix(_ failure: LinearEstimatorFailure, _ state: LinearEstimatorState, work: NumericalWork,
                              cause: LinearEstimatorError) throws {
        try require(failure.cause==cause && failure.admittedWork==work,"Original failure cause and admitted work")
        guard let retained = failure.prefix else { throw LinearEstimationQualificationError.assertion("Missing original failure prefix") }
        try sameState(retained,state)
    }
}
