import MechanicsCore
import MechanicsConstraints
import MechanicsNumerics
import MechanicsNonlinear

internal enum ConstraintFixtures {
    static func budget(storage: Int = 100_000, operations: Int = 2_000_000, iterations: Int = 1000) throws -> NumericalBudget {
        try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:iterations)
    }
    static func work(storage: Int = 100_000, operations: Int = 2_000_000, iterations: Int = 1000) throws -> NumericalWork {
        NumericalWork(budget:try budget(storage:storage,operations:operations,iterations:iterations))
    }
    static func layout(_ n: Int = 2, scales: [Double]? = nil, timeScale: Double = 1) throws -> ConstraintCoordinateLayout {
        try ConstraintCoordinateLayout(coordinateIDs:(0..<n).map { UInt64($0+1) },dimensions:[PhysicalDimension](repeating:.length,count:n),scales:scales ?? [Double](repeating:1,count:n),timeScale:timeScale,revision:7)
    }
    static func evaluation(maximumRows: Int = 10, cancelled: @escaping @Sendable () -> Bool = {false}) throws -> ConstraintEvaluationPolicy {
        try ConstraintEvaluationPolicy(maximumCoordinates:10,maximumRows:maximumRows,expectedLayoutRevision:7,isCancelled:cancelled)
    }
    static func policy(metric: [Double] = [1,1], rank: ConstraintRankPolicy = .allowRedundancy, correction: Double = 10,
                       residual: Double = 1e-8, internalTolerance: Double = 1e-10, nonlinearIterations: Int = 1000,
                       nonlinearStorage: Int = 100_000, maximumFactorEntries: Int = 1000,
                       cancelled: @escaping @Sendable () -> Bool = {false}) throws -> ConstraintSolvePolicy {
        let tolerance=try LinearTolerance<Double>(absoluteResidual:internalTolerance,relativeResidual:0,pivotThreshold:1e-13)
        let nonlinear=try NonlinearPolicy<Double>(strategy:.lineSearch(contraction:0.5,sufficientDecrease:1e-4,minimumFraction:1e-7),
            capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.partialPivotLU),tolerance:tolerance,referenceScale:1,
            minimumDirectionNorm:0,derivativeProbeDistance:1e-6,derivativeAbsoluteTolerance:1e-4,derivativeRelativeTolerance:1e-4,
            maximumFactorEntries:maximumFactorEntries,estimateCondition:false,budget:budget(storage:nonlinearStorage,iterations:nonlinearIterations))
        return try ConstraintSolvePolicy(evaluation:evaluation(cancelled:cancelled),diagonalMetric:metric,energyScale:5,rankPolicy:rank,
            rankRelativeTolerance:1e-10,originalResidualTolerance:residual,maximumCorrection:correction,nonlinear:nonlinear,
            linearCapability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky),linearTolerance:tolerance)
    }
    static func affine(id: UInt64 = 1, constant: Double = -1, coefficients: [Double] = [1,1]) -> QuadraticConstraint {
        QuadraticConstraint(id:id,constant:constant,linear:coefficients,hessian:[Double](repeating:0,count:coefficients.count*coefficients.count),timeLinear:0,timeQuadratic:0,mixedTime:[Double](repeating:0,count:coefficients.count))
    }
    static func system(_ rows: [QuadraticConstraint], layout given: ConstraintCoordinateLayout? = nil) throws -> QuadraticConstraintSystem {
        let l=try given ?? layout()
        return try QuadraticConstraintSystem(layout:l,rows:rows,minimumPosition:[Double](repeating:-10,count:l.scales.count),maximumPosition:[Double](repeating:10,count:l.scales.count),minimumTime:-10,maximumTime:10)
    }
    static func loops() throws -> QuadraticConstraintSystem {
        let first=QuadraticConstraint(id:1,constant:-1,linear:[0,0],hessian:[2,0,0,2],timeLinear:0,timeQuadratic:0,mixedTime:[0,0])
        let second=QuadraticConstraint(id:2,constant:0,linear:[-2,0],hessian:[2,0,0,2],timeLinear:0,timeQuadratic:0,mixedTime:[0,0])
        return try system([first,second])
    }
    static func close(_ a: Double,_ b: Double,_ tolerance: Double = 1e-7) -> Bool { abs(a-b) <= tolerance }
}
