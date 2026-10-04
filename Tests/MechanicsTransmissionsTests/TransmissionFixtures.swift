import SwiftMechanics

internal enum TransmissionFixtures {
    static func work(storage: Int = 200_000,operations: Int = 2_000_000) throws -> NumericalWork {
        NumericalWork(budget:try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:1000))
    }
    static func policy(maximumPorts: Int = 10,expectedModelRevision: UInt64 = 9,expectedLayoutRevision: UInt64 = 7,cancelled: @escaping @Sendable () -> Bool = {false}) throws -> TransmissionPolicy {
        try TransmissionPolicy(maximumCoordinates:10,maximumPorts:maximumPorts,maximumRelations:10,expectedLayoutRevision:expectedLayoutRevision,expectedModelRevision:expectedModelRevision,
            geometryTolerance:1e-9,originalTolerance:1e-8,powerScale:10,powerTolerance:1e-8,isCancelled:cancelled)
    }
    static func layout(_ n: Int = 2,rack: Bool = false) throws -> ConstraintCoordinateLayout {
        var dimensions=[PhysicalDimension](repeating:.angle,count:n)
        if rack { dimensions[1] = .length }
        return try ConstraintCoordinateLayout(coordinateIDs:(0..<n).map {UInt64($0+1)},dimensions:dimensions,scales:[Double](repeating:1,count:n),timeScale:2,revision:7)
    }
    static func port(_ index: Int,rack: Bool = false,flip: Bool = false,frame: String = "world",origin: Vector3 = .zero) throws -> TransmissionPortBinding {
        let manifold=try JointManifold(rack ? .prismatic(axis:.unitX) : .revolute(axis:.unitZ))
        let rotation=flip ? try UnitQuaternion(axis:.unitX,angle:.pi) : .identity
        return try TransmissionPortBinding(coordinateIndex:index,coordinateID:UInt64(index+1),body:EntityID(kind:.body,key:"body-\(index)"),
            joint:EntityID(kind:.joint,key:"joint-\(index)"),frame:EntityID(kind:.frame,key:frame),manifold:manifold,
            jointToReference:RigidTransform(rotation:rotation,translation:origin),layoutRevision:7,modelRevision:9)
    }
    static func compile(_ relations: [TransmissionRelation],count: Int = 2,rack: Bool = false,flipSecond: Bool = false) throws -> CompiledTransmissionNetwork {
        var work=try Self.work(), ports: [TransmissionPortBinding]=[]
        for i in 0..<count { ports.append(try port(i,rack:rack && i == 1,flip:flipSecond && i == 1,origin:rack && i == 1 ? Vector3(0,1,0) : .zero)) }
        return try AffineTransmissionCompiler().compile(id:100,layout:layout(count,rack:rack),ports:ports,relations:relations,
            minimumPosition:[Double](repeating:-1000,count:count),maximumPosition:[Double](repeating:1000,count:count),minimumTime:0,maximumTime:10,policy:policy(),work:&work)
    }
    static func assemblyPolicy(_ n: Int) throws -> ConstraintSolvePolicy {
        let tolerance=try LinearTolerance<Double>(absoluteResidual:1e-10,relativeResidual:0,pivotThreshold:1e-13)
        let nonlinear=try NonlinearPolicy<Double>(strategy:.newton,capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.partialPivotLU),
            tolerance:tolerance,referenceScale:1,minimumDirectionNorm:0,derivativeProbeDistance:1e-6,derivativeAbsoluteTolerance:1e-5,derivativeRelativeTolerance:1e-5,
            maximumFactorEntries:1000,estimateCondition:false,budget:NumericalBudget(scalarStorage:100_000,arithmeticOperations:1_000_000,iterations:1000))
        return try ConstraintSolvePolicy(evaluation:ConstraintEvaluationPolicy(maximumCoordinates:10,maximumRows:10,expectedLayoutRevision:7),diagonalMetric:[Double](repeating:1,count:n),
            energyScale:1,rankPolicy:.allowRedundancy,rankRelativeTolerance:1e-10,originalResidualTolerance:1e-8,maximumCorrection:100,nonlinear:nonlinear,
            linearCapability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky),linearTolerance:tolerance)
    }
    static func close(_ a: Double,_ b: Double,_ tolerance: Double = 1e-7) -> Bool { abs(a-b) <= tolerance }
}
