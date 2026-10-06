import SwiftMechanics

enum LocalOptimizationFixtures {
    static func layout(n: Int,e: Int,m: Int,diagonalHessian: Bool = true) throws -> NonlinearProgramLayout {
        let reference=try SIReferenceQuantity<Double>(magnitude:1,dimension:.length),cost=try SIReferenceQuantity<Double>(magnitude:1,dimension:.energy)
        let metadata=try OptimizationMetadata(identity:"local-analytic",provenance:SourceProvenance(source:"analytic-C2",revision:1),variableIDs:(0..<n).map { UInt64($0+1) },
            variableReferences:[SIReferenceQuantity<Double>](repeating:reference,count:n),objectiveReference:cost,
            equalityReferences:[SIReferenceQuantity<Double>](repeating:reference,count:e),inequalityReferences:[SIReferenceQuantity<Double>](repeating:reference,count:m))
        func full(_ rows: Int) -> SparseOptimizationPattern {
            var offsets=[0],columns=[Int]()
            for _ in 0..<rows { for j in 0..<n { columns.append(j) }; offsets.append(columns.count) }
            return SparseOptimizationPattern(rows:rows,columns:n,rowOffsets:offsets,columnIndices:columns)
        }
        return NonlinearProgramLayout(metadata:metadata,equalityJacobian:full(e),inequalityJacobian:full(m),
            lagrangianHessian:SparseOptimizationPattern(rows:n,columns:n,rowOffsets:Array(0...n),columnIndices:Array(0..<n)))
    }
    static func policy(iterations: Int = 1000,fill: Int = 10000,pivot: Double = 1e-14,cancel: @escaping @Sendable () -> Bool = { false }) throws -> LocalOptimizationPolicy {
        let tolerance=try LinearTolerance<Double>(absoluteResidual:1e-10,relativeResidual:1e-10,pivotThreshold:pivot)
        let nonlinear=try NonlinearPolicy<Double>(strategy:.lineSearch(contraction:0.5,sufficientDecrease:1e-4,minimumFraction:1e-8),
            capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.partialPivotLU),tolerance:tolerance,
            referenceScale:1,minimumDirectionNorm:0,derivativeProbeDistance:1e-6,derivativeAbsoluteTolerance:1e-5,derivativeRelativeTolerance:1e-5,
            maximumFactorEntries:fill,estimateCondition:false,budget:NumericalBudget(scalarStorage:100000,arithmeticOperations:10000000,iterations:iterations))
        return try LocalOptimizationPolicy(nonlinear:nonlinear,curvatureCapability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky),curvatureTolerance:tolerance,
            maximumVariables:10,maximumRows:100,maximumNonzeros:1000,maximumDenseEntries:fill,maximumProviderScratchScalars:1000,
            rankThreshold:1e-12,nullspaceTolerance:1e-9,absoluteTolerance:1e-9,relativeTolerance:1e-10,strictMultiplierMargin:1e-8,inactiveSlackMargin:1e-8,isCancelled:cancel)
    }
    static func work(operations: Int = 10000000,storage: Int = 100000,iterations: Int = 10000) throws -> NumericalWork {
        NumericalWork(budget:try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:iterations))
    }
    static func problem(_ mode: ManufacturedSmoothProgram<Double>.Mode = .curved) throws -> FixedActiveNonlinearProblem {
        let n: Int,e: Int,m: Int,point: [Double],active: [Int],multipliers: [Double],eqMultipliers: [Double]
        switch mode {
        case .curved,.badHessian: n=2;e=1;m=0;point=[0.8,0.8];active=[];multipliers=[];eqMultipliers=[0.8]
        case .activeCurve: n=2;e=0;m=1;point=[0.8,0.1];active=[0];multipliers=[0.5];eqMultipliers=[]
        case .bound: n=1;e=0;m=0;point=[0];active=[1];multipliers=[1];eqMultipliers=[]
        case .rank,.nearRank: n=2;e=2;m=0;point=[0,0];active=[];multipliers=[];eqMultipliers=[0,0]
        case .saddle: n=2;e=0;m=0;point=[0,0];active=[];multipliers=[];eqMultipliers=[]
        case .weakActive: n=1;e=0;m=1;point=[0];active=[0];multipliers=[0];eqMultipliers=[]
        default: n=1;e=0;m=0;point=[0];active=[];multipliers=[];eqMultipliers=[]
        }
        return FixedActiveNonlinearProblem(provider:ManufacturedSmoothProgram<Double>(layout:try layout(n:n,e:e,m:m),mode:mode),
            lowerBounds:[Double](repeating:-10,count:n),upperBounds:[Double](repeating:mode == .bound ? 1 : 10,count:n),activeInequalities:active,
            initialPoint:point,initialEqualityMultipliers:eqMultipliers,initialActiveMultipliers:multipliers)
    }
    static func solve(_ p: FixedActiveNonlinearProblem,policy: LocalOptimizationPolicy? = nil) throws -> StrictLocalOptimum {
        var work=try self.work(); let service: any LocalOptimizationSolving=FixedActiveLocalOptimizer()
        return try service.solve(p,policy:policy ?? self.policy(),work:&work)
    }
}
