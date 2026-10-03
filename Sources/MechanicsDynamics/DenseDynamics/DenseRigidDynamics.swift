import MechanicsNumerics
public struct DenseRigidDynamics: RigidDynamicsSolving {
    private let equations: any RigidEquationComputing
    private let linearSolver: any LinearSolving<Double>
    public init(equations: any RigidEquationComputing = RigidEquationKernel(),
                linearSolver: any LinearSolving<Double> = ReferenceLinearSolver<Double>()) {
        self.equations = equations; self.linearSolver = linearSolver
    }
    public func forward(_ system: RigidDynamicsSystem, driveForce: [Double], policy: DynamicsSolvePolicy,
                        work: inout NumericalWork) throws(DynamicsError) -> DynamicsSolution {
        try solveFull(system,rhs:driveForce,includeBias:true,policy:policy,work:&work)
    }
    public func inverseMassProduct(_ system: RigidDynamicsSystem, rightHandSide: [Double], policy: DynamicsSolvePolicy,
                                   work: inout NumericalWork) throws(DynamicsError) -> DynamicsSolution {
        try solveFull(system,rhs:rightHandSide,includeBias:false,policy:policy,work:&work)
    }
    public func inverse(_ system: RigidDynamicsSystem, acceleration: [Double], policy: DynamicsSolvePolicy,
                        work: inout NumericalWork) throws(DynamicsError) -> DynamicsSolution {
        try validate(system,values:acceleration,policy:policy)
        let n = system.velocityCount
        try DynamicsArithmetic.storage(DynamicsArithmetic.sum(system.scalarStorage,DynamicsArithmetic.product(2,n)),&work)
        var drive = [Double](repeating:0,count:n), original = [Double](repeating:0,count:n)
        for i in 0..<n {
            try checkpoint(system)
            var required = system.inertialBias[i]
            for j in 0..<n { try DynamicsArithmetic.operations(2,&work); required = try DynamicsArithmetic.finite(required+system.massMatrix[i*n+j]*acceleration[j]) }
            try DynamicsArithmetic.operations(5,&work)
            drive[i] = try DynamicsArithmetic.finite(required-system.forces.total(at:i))
        }
        let residual = try verify(system,acceleration:acceleration,drive:drive,includeBias:true,policy:policy,original:&original,work:&work)
        return DynamicsSolution(acceleration:acceleration,driveForce:drive,originalPhysicalResidual:residual,linearDiagnostics:nil,work:work)
    }
    public func mixed(_ system: RigidDynamicsSystem, partition: [MixedCoordinate], policy: DynamicsSolvePolicy,
                      work: inout NumericalWork) throws(DynamicsError) -> DynamicsSolution {
        try validatePolicy(system,policy:policy)
        let n = system.velocityCount
        guard partition.count == n else { throw .invalidShape }
        // Integer indices are conservatively counted as scalar-equivalent slots as well.
        let fullStorage = try DynamicsArithmetic.sum(system.scalarStorage,DynamicsArithmetic.product(4,n))
        try DynamicsArithmetic.storage(fullStorage,&work)
        var acceleration = [Double](repeating:0,count:n), drive = [Double](repeating:0,count:n), original = [Double](repeating:0,count:n)
        var unknown: [Int] = []; unknown.reserveCapacity(n)
        for i in 0..<n {
            try DynamicsArithmetic.operations(1,&work)
            switch partition[i] {
            case .prescribedAcceleration(let value): guard value.isFinite else { throw .invalidInput }; acceleration[i] = value
            case .prescribedDriveForce(let value): guard value.isFinite else { throw .invalidInput }; drive[i] = value; unknown.append(i)
            }
        }
        var diagnostics: LinearDiagnostics<Double>?
        let m = unknown.count
        if m > 0 {
            let blockCount = try DynamicsArithmetic.product(m,m)
            let reserved = try DynamicsArithmetic.sum(fullStorage,DynamicsArithmetic.sum(blockCount,DynamicsArithmetic.product(2,m)))
            try DynamicsArithmetic.storage(reserved,&work)
            var matrix = [Double](repeating:0,count:blockCount), rhs = [Double](repeating:0,count:m)
            for i in 0..<m {
                try checkpoint(system)
                let row = unknown[i]
                try DynamicsArithmetic.operations(6,&work)
                var value = try DynamicsArithmetic.finite(drive[row]+system.forces.total(at:row)-system.inertialBias[row])
                for j in 0..<n {
                    if case .prescribedAcceleration = partition[j] {
                        try DynamicsArithmetic.operations(2,&work); value = try DynamicsArithmetic.finite(value-system.massMatrix[row*n+j]*acceleration[j])
                    }
                }
                rhs[i] = try scaledForce(value,index:row,policy:policy,work:&work)
                for j in i..<m {
                    let entry = try scaledMass(system.massMatrix[row*n+unknown[j]],row:row,column:unknown[j],policy:policy,work:&work)
                    matrix[i*m+j] = entry; matrix[j*m+i] = entry
                }
            }
            let solved = try nestedSolve(matrix,count:m,rhs:rhs,reserved:reserved,policy:policy,work:&work)
            diagnostics = solved.diagnostics
            for i in 0..<m { acceleration[unknown[i]] = try physicalAcceleration(solved.values[i],index:unknown[i],policy:policy,work:&work) }
        }
        try equations.originalInertialForce(system,acceleration:acceleration,includeBias:true,into:&original,work:&work)
        for i in 0..<n {
            if case .prescribedAcceleration = partition[i] {
                try DynamicsArithmetic.operations(5,&work); drive[i] = try DynamicsArithmetic.finite(original[i]-system.forces.total(at:i))
            }
        }
        let residual = try measure(system,drive:drive,original:original,includeBias:true,policy:policy,work:&work)
        try checkpoint(system)
        return DynamicsSolution(acceleration:acceleration,driveForce:drive,originalPhysicalResidual:residual,linearDiagnostics:diagnostics,work:work)
    }
    private func solveFull(_ system: RigidDynamicsSystem, rhs drive: [Double], includeBias: Bool,
                           policy: DynamicsSolvePolicy, work: inout NumericalWork) throws(DynamicsError) -> DynamicsSolution {
        try validate(system,values:drive,policy:policy)
        let n = system.velocityCount, matrixCount = try DynamicsArithmetic.product(n,n)
        let reserved = try DynamicsArithmetic.sum(system.scalarStorage,DynamicsArithmetic.sum(matrixCount,DynamicsArithmetic.product(4,n)))
        try DynamicsArithmetic.storage(reserved,&work)
        var matrix = [Double](repeating:0,count:matrixCount), rhs = [Double](repeating:0,count:n)
        for i in 0..<n {
            try checkpoint(system)
            var value = drive[i]
            if includeBias { try DynamicsArithmetic.operations(6,&work); value = try DynamicsArithmetic.finite(value+system.forces.total(at:i)-system.inertialBias[i]) }
            rhs[i] = try scaledForce(value,index:i,policy:policy,work:&work)
            for j in i..<n {
                let entry = try scaledMass(system.massMatrix[i*n+j],row:i,column:j,policy:policy,work:&work)
                matrix[i*n+j] = entry; matrix[j*n+i] = entry
            }
        }
        let solved = try nestedSolve(matrix,count:n,rhs:rhs,reserved:reserved,policy:policy,work:&work)
        // A required ownership copy separates normalized solver values from physical acceleration output.
        var acceleration = solved.values, original = [Double](repeating:0,count:n)
        for i in 0..<n { acceleration[i] = try physicalAcceleration(solved.values[i],index:i,policy:policy,work:&work) }
        let residual = try verify(system,acceleration:acceleration,drive:drive,includeBias:includeBias,policy:policy,original:&original,work:&work)
        return DynamicsSolution(acceleration:acceleration,driveForce:drive,originalPhysicalResidual:residual,linearDiagnostics:solved.diagnostics,work:work)
    }
    private func nestedSolve(_ values: [Double], count: Int, rhs: [Double], reserved: Int,
                             policy: DynamicsSolvePolicy, work: inout NumericalWork) throws(DynamicsError) -> LinearSolution<Double> {
        let matrix: DenseMatrix<Double>, budget: NumericalBudget
        do { matrix = try DenseMatrix(rows:count,columns:count,values:values); budget = try work.remainingBudget(reservedStorage:reserved) }
        catch { throw .numerical(error,failedSupplierWorkUnavailable:false) }
        let result: LinearSolution<Double>
        do { result = try linearSolver.solve(matrix,rightHandSide:rhs,capability:policy.capability,tolerance:policy.linearTolerance,budget:budget) }
        catch { throw .numerical(error,failedSupplierWorkUnavailable:true) }
        do { try work.absorb(result.diagnostics.work,reservedStorage:reserved) }
        catch { throw .numerical(error,failedSupplierWorkUnavailable:false) }
        guard result.values.count == count, result.values.allSatisfy({ $0.isFinite }) else { throw .invalidShape }
        return result
    }
    private func verify(_ system: RigidDynamicsSystem, acceleration: [Double], drive: [Double], includeBias: Bool,
                        policy: DynamicsSolvePolicy, original: inout [Double], work: inout NumericalWork) throws(DynamicsError) -> PhysicalResidual {
        try equations.originalInertialForce(system,acceleration:acceleration,includeBias:includeBias,into:&original,work:&work)
        let result = try measure(system,drive:drive,original:original,includeBias:includeBias,policy:policy,work:&work)
        try checkpoint(system); return result
    }
    private func measure(_ system: RigidDynamicsSystem, drive: [Double], original: [Double], includeBias: Bool,
                         policy: DynamicsSolvePolicy, work: inout NumericalWork) throws(DynamicsError) -> PhysicalResidual {
        var residual = 0.0, reference = 0.0
        for i in 0..<system.velocityCount {
            try checkpoint(system)
            var expected = drive[i]
            if includeBias { try DynamicsArithmetic.operations(5,&work); expected = try DynamicsArithmetic.finite(expected+system.forces.total(at:i)) }
            let scaledExpected = try scaledForce(expected,index:i,policy:policy,work:&work)
            let actual = try scaledForce(original[i],index:i,policy:policy,work:&work)
            try DynamicsArithmetic.operations(1,&work)
            residual = max(residual,abs(try DynamicsArithmetic.finite(actual-scaledExpected)))
            reference = max(reference,max(abs(actual),abs(scaledExpected)))
        }
        let threshold: Double
        do { threshold = try policy.linearTolerance.threshold(scale:reference) } catch { throw .numerical(error,failedSupplierWorkUnavailable:false) }
        guard residual <= threshold else { throw .physicalResidualRejected(value:residual,threshold:threshold) }
        return PhysicalResidual(equation:includeBias ? .completeInertiaAndKnownLoads : .massOnly,infinityNorm:residual,referenceScale:reference,threshold:threshold)
    }
    private func scaledForce(_ value: Double, index: Int, policy: DynamicsSolvePolicy, work: inout NumericalWork) throws(DynamicsError) -> Double {
        try DynamicsArithmetic.operations(2,&work)
        return try DynamicsArithmetic.finite((value/policy.energyScale)*policy.coordinateScales[index])
    }
    private func scaledMass(_ value: Double, row: Int, column: Int, policy: DynamicsSolvePolicy, work: inout NumericalWork) throws(DynamicsError) -> Double {
        try DynamicsArithmetic.operations(5,&work)
        return try DynamicsArithmetic.finite((((value/policy.energyScale)*policy.coordinateScales[row])*policy.coordinateScales[column])/(policy.timeScale*policy.timeScale))
    }
    private func physicalAcceleration(_ value: Double, index: Int, policy: DynamicsSolvePolicy, work: inout NumericalWork) throws(DynamicsError) -> Double {
        try DynamicsArithmetic.operations(3,&work)
        return try DynamicsArithmetic.finite(value*policy.coordinateScales[index]/(policy.timeScale*policy.timeScale))
    }
    private func validate(_ system: RigidDynamicsSystem, values: [Double], policy: DynamicsSolvePolicy) throws(DynamicsError) {
        try validatePolicy(system,policy:policy)
        guard values.count == system.velocityCount, values.allSatisfy({ $0.isFinite }) else { throw .invalidShape }
    }
    private func validatePolicy(_ system: RigidDynamicsSystem, policy: DynamicsSolvePolicy) throws(DynamicsError) {
        try checkpoint(system)
        guard policy.coordinateScales.count == system.velocityCount else { throw .invalidShape }
        do { try policy.capability.validate(for:Double.self,algorithms:[.cholesky]) }
        catch { throw .numerical(error,failedSupplierWorkUnavailable:false) }
    }
    private func checkpoint(_ system: RigidDynamicsSystem) throws(DynamicsError) {
        guard !system.admission.isCancelled(), !Task.isCancelled else { throw .cancelled }
    }
}
