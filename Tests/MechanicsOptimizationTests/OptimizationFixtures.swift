import MechanicsCore
import MechanicsModel
import MechanicsNumerics
import MechanicsOptimization

enum OptimizationFixtures {
    static func csr(_ rows: [[Double]],columns: Int) throws -> CSRMatrix<Double>? {
        if rows.isEmpty { return nil }
        var offsets=[0], indices=[Int](), values=[Double]()
        for row in rows {
            for j in 0..<columns { if row[j] != 0 { indices.append(j); values.append(row[j]) } }
            offsets.append(values.count)
        }
        return try CSRMatrix(rows:rows.count,columns:columns,rowOffsets:offsets,columnIndices:indices,values:values)
    }
    static func problem(cost: [Double],hessian: [Double]? = nil,equality: [[Double]] = [],eqRHS: [Double] = [],inequality: [[Double]] = [],ineqRHS: [Double] = [],
        lower: [Double]? = nil,upper: [Double]? = nil,variableScales: [Double]? = nil,costScale: Double = 1) throws -> ConvexOptimizationProblem {
        let n=cost.count
        var references=[SIReferenceQuantity<Double>](),eqRefs=references,ineqRefs=references
        for i in 0..<n { references.append(try SIReferenceQuantity(magnitude:variableScales?[i] ?? 1,dimension:.length)) }
        for _ in equality { eqRefs.append(try SIReferenceQuantity(magnitude:1,dimension:.length)) }
        for _ in inequality { ineqRefs.append(try SIReferenceQuantity(magnitude:1,dimension:.length)) }
        let metadata=try OptimizationMetadata(identity:"fixture",provenance:SourceProvenance(source:"analytic",revision:1),variableIDs:(0..<n).map { UInt64($0+1) },
            variableReferences:references,objectiveReference:SIReferenceQuantity(magnitude:costScale,dimension:.energy),equalityReferences:eqRefs,inequalityReferences:ineqRefs)
        let matrix: DenseMatrix<Double>?
        if let hessian { matrix=try DenseMatrix(rows:n,columns:n,values:hessian) } else { matrix=nil }
        return ConvexOptimizationProblem(metadata:metadata,linearCost:cost,hessian:matrix,equalities:try csr(equality,columns:n),equalityRightHandSide:eqRHS,
            inequalities:try csr(inequality,columns:n),inequalityRightHandSide:ineqRHS,lowerBounds:lower ?? [Double](repeating:0,count:n),upperBounds:upper ?? [Double](repeating:2,count:n))
    }
    static func policy(candidates: Int = 10000,rank: Double = 1e-12,pivot: Double = 1e-14,fill: Int = 10000,variables: Int = 10,rows: Int = 100,nonzeros: Int = 1000,precision: NumericalPrecision = .float64,
        cancel: @escaping @Sendable () -> Bool = { false }) throws -> OptimizationPolicy {
        try OptimizationPolicy(maximumVariables:variables,maximumRows:rows,maximumNonzeros:nonzeros,maximumFactorEntries:fill,maximumCandidateBases:candidates,
            rankThreshold:rank,certificateAbsolute:1e-9,certificateRelative:1e-10,
            luCapability:LinearCapability(precision:precision,backend:.referenceCPU,algorithm:.partialPivotLU),
            curvatureCapability:LinearCapability(precision:precision,backend:.referenceCPU,algorithm:.cholesky),
            linearTolerance:LinearTolerance(absoluteResidual:1e-10,relativeResidual:1e-10,pivotThreshold:pivot),isCancelled:cancel)
    }
    static func work(operations: Int = 10_000_000,storage: Int = 100_000,iterations: Int = 100000) throws -> NumericalWork {
        NumericalWork(budget:try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:iterations))
    }
    static func solve(_ p: ConvexOptimizationProblem,policy: OptimizationPolicy? = nil) throws -> OptimizationResult {
        var workspace=EnumerationWorkspace(),w=try work()
        let service: any OptimizationSolving=CompleteConvexOptimizer()
        return try service.solve(p,policy:policy ?? self.policy(),workspace:&workspace,work:&w)
    }
    static func close(_ a: Double,_ b: Double) -> Bool { abs(a-b) < 1e-8+1e-10*abs(b) }
}
