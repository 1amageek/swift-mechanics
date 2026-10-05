internal struct TaskSpacePhysicalInvocation: Sendable {
    enum Operation { case forward, inverse, inverseMass }
    let dynamics: any PhysicalRigidDynamicsSolving
    @inline(never)
    func call(_ operation: Operation, system: PhysicalRigidDynamicsSystem, values: [Double],
              policy: TaskSpacePolicy, reserved: Int, work: inout NumericalWork) throws(TaskSpaceFailure) -> PhysicalDynamicsSolution {
        try TaskSpaceArithmetic.check(system,policy)
        var local = try TaskSpaceArithmetic.seed(work,reserved:reserved)
        let before = local
        var result: PhysicalDynamicsSolution?, failure: DynamicsError?
        do throws(DynamicsError) {
            switch operation {
            case .forward: result = try dynamics.forward(system,driveForce:values,policy:policy.dynamics,work:&local)
            case .inverse: result = try dynamics.inverse(system,acceleration:values,policy:policy.dynamics,work:&local)
            case .inverseMass: result = try dynamics.inverseMassProduct(system,rightHandSide:values,policy:policy.dynamics,work:&local)
            }
        } catch { failure = error }
        try TaskSpaceArithmetic.reconcile(local,before:before,reserved:reserved,work:&work)
        if let failure { throw TaskSpaceFailure(.dynamics(failure),failedSupplierWorkUnavailable:failure.failedSupplierWorkUnavailable) }
        try TaskSpaceArithmetic.charge(try TaskSpaceArithmetic.product(6,system.velocityCount),&work)
        guard let result, result.system === system, result.work == local,
              result.acceleration.count == system.velocityCount, result.driveForce.count == system.velocityCount,
              result.acceleration.allSatisfy({$0.isFinite}), result.driveForce.allSatisfy({$0.isFinite}),
              result.originalPhysicalResidual.isAccepted else { throw TaskSpaceFailure(.invalidSupplierOutput) }
        switch operation {
        case .inverse: break
        default:
            guard let diagnostics = result.linearDiagnostics, diagnostics.capability == policy.dynamics.capability,
                  diagnostics.factorization == .cholesky, diagnostics.numericalRank == system.velocityCount,
                  diagnostics.originalResidual.isAccepted else { throw TaskSpaceFailure(.invalidSupplierOutput) }
        }
        let includeBias: Bool
        switch operation {
        case .inverseMass: includeBias = false
        default: includeBias = true
        }
        guard result.originalPhysicalResidual.equation == (includeBias ? .completeInertiaAndKnownLoads : .massOnly) else {
            throw TaskSpaceFailure(.invalidSupplierOutput)
        }
        switch operation {
        case .inverse: guard result.acceleration == values else { throw TaskSpaceFailure(.invalidSupplierOutput) }
        default: guard result.driveForce == values else { throw TaskSpaceFailure(.invalidSupplierOutput) }
        }
        // Recompute original body Newton/Euler forces through the qualified concrete source,
        // independently of an injected solver's success flag and assembled matrix product.
        var original = [Double](repeating:0,count:system.velocityCount)
        do { try RigidEquationKernel().originalInertialForce(system,acceleration:result.acceleration,includeBias:includeBias,into:&original,work:&work) }
        catch { throw TaskSpaceFailure(.dynamics(error),failedSupplierWorkUnavailable:error.failedSupplierWorkUnavailable) }
        var residual = 0.0, scale = 0.0
        for i in original.indices {
            try TaskSpaceArithmetic.charge(8,&work)
            let expected: Double
            do { expected = try TaskSpaceArithmetic.finite(result.driveForce[i] + (includeBias ? system.forces.total(at:i) : 0)) }
            catch let failure as TaskSpaceFailure { throw failure }
            catch let error as DynamicsError { throw TaskSpaceFailure(.dynamics(error)) }
            catch { throw TaskSpaceFailure(.invalidSupplierOutput) }
            let conversion = policy.dynamics.coordinateScales[i]/policy.dynamics.energyScale
            let actualScaled = try TaskSpaceArithmetic.finite(original[i]*conversion)
            let expectedScaled = try TaskSpaceArithmetic.finite(expected*conversion)
            residual = max(residual,abs(try TaskSpaceArithmetic.finite(actualScaled-expectedScaled)))
            scale = max(scale,max(abs(actualScaled),abs(expectedScaled)))
        }
        let threshold: Double
        do { threshold = try policy.dynamics.linearTolerance.threshold(scale:scale) }
        catch { throw TaskSpaceFailure(.numerical(error)) }
        guard residual <= threshold else { throw TaskSpaceFailure(.dynamics(.physicalResidualRejected(value:residual,threshold:threshold))) }
        try TaskSpaceArithmetic.check(system,policy)
        return result
    }
}
