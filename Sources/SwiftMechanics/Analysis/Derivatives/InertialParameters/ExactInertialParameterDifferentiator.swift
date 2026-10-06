public struct ExactInertialParameterDifferentiator: InertialParameterDifferentiating {
    private let mechanics: any MechanicalDifferentiating
    private let equations: any RigidEquationComputing
    private let solver: any RigidDynamicsSolving

    public init() {
        let equations = RigidEquationKernel()
        self.equations = equations
        self.mechanics = ExactMechanicalDifferentiator(equations: equations,solver: DenseRigidDynamics(equations: equations))
        self.solver = DenseRigidDynamics(equations: equations)
    }

    @inline(never)
    public func product(_ input: InertialParameterInput, direction: [RigidInertialParameterDirection],
                        jointPolicy: JointEvaluationPolicy, admission: DynamicsAdmission, solvePolicy: DynamicsSolvePolicy,
                        policy: DerivativePolicy,
                        loadWork: inout LoadWork, supplierWork: inout DerivativeSupplierWork,
                        work: inout NumericalWork) throws(InertialParameterError) -> InertialParameterProduct {
        try preflight(input,admission,solvePolicy,policy,&work)
        let prepared = try prepare(input,direction,policy,&supplierWork,&work)
        var workspace = MechanicalDerivativeWorkspace()
        let tangent = try mechanical(input.primal,prepared.direction,jointPolicy,admission,policy,
                                     prepared.reserved,&workspace,&loadWork,&supplierWork,&work)
        let n = input.primal.tree.layout.velocityCount
        guard solvePolicy.coordinateScales.count == n else { throw .invalidShape }
        // The supplier's recorded peak conservatively reserves every still-live tangent/workspace slot.
        let live = work.peakScalarStorage
        try InertialParameterArithmetic.checkpoint(policy)
        var nested = try InertialParameterArithmetic.nested(work,reserved: live)
        try InertialParameterArithmetic.call(&supplierWork)
        let inverse: DynamicsSolution
        do { inverse = try solver.inverse(tangent.system,acceleration: input.primal.state.acceleration,policy: solvePolicy,work: &nested) }
        catch {
            try InertialParameterArithmetic.absorb(nested,reserved: live,into: &work)
            throw .dynamics(error)
        }
        try InertialParameterArithmetic.absorb(nested,reserved: live,into: &work)
        try InertialParameterArithmetic.checkpoint(policy)
        nested = try InertialParameterArithmetic.nested(work,reserved: live)
        try InertialParameterArithmetic.call(&supplierWork)
        let energy: MechanicalEnergy
        do { energy = try equations.energy(tangent.system,acceleration: input.primal.state.acceleration,
                    angularMomentumReference: .zero,requireComplete: false,work: &nested) }
        catch {
            try InertialParameterArithmetic.absorb(nested,reserved: live,into: &work)
            throw .dynamics(error)
        }
        try InertialParameterArithmetic.absorb(nested,reserved: live,into: &work)
        var required = [Double](repeating: 0,count: n)
        for i in 0..<n {
            try InertialParameterArithmetic.checkpoint(policy)
            try InertialParameterArithmetic.charge(2,&work)
            var value = try InertialParameterArithmetic.finite(tangent.inertialBias[i]-tangent.totalForce[i])
            for j in 0..<n {
                try InertialParameterArithmetic.charge(2,&work)
                value = try InertialParameterArithmetic.finite(value+tangent.massMatrix[i*n+j]*input.primal.state.acceleration[j])
            }
            required[i] = value
        }
        let original = try originalRequired(tangent,prepared.direction.inertias,policy,&work)
        try InertialParameterArithmetic.charge(10,&work)
        let energyAccepted = try InertialParameterArithmetic.core { () throws(CoreError) in
            try policy.tolerance.contains(error: original.kinetic-energy.kineticEnergy,
                                          scale: max(abs(original.kinetic),abs(energy.kineticEnergy)))
        }
        let directionAccepted = try InertialParameterArithmetic.core { () throws(CoreError) in
            try policy.tolerance.contains(error: original.kineticDirection-tangent.kineticEnergy,
                                          scale: max(abs(original.kineticDirection),abs(tangent.kineticEnergy)))
        }
        guard energyAccepted, directionAccepted else { throw .derivative(.primalMismatch) }
        var residual = 0.0, scale = 0.0
        for i in 0..<n {
            try InertialParameterArithmetic.checkpoint(policy)
            try InertialParameterArithmetic.charge(12,&work)
            let expected = try InertialParameterArithmetic.finite((required[i]/solvePolicy.energyScale)*solvePolicy.coordinateScales[i])
            let actual = try InertialParameterArithmetic.finite(((original.required[i]-tangent.totalForce[i])/solvePolicy.energyScale)*solvePolicy.coordinateScales[i])
            residual = max(residual,try InertialParameterArithmetic.finite(abs(actual-expected)))
            scale = max(scale,max(abs(actual),abs(expected)))
        }
        try InertialParameterArithmetic.charge(3,&work)
        let threshold = try InertialParameterArithmetic.finite(policy.residualTolerance.absolute+policy.residualTolerance.relative*scale)
        guard residual <= threshold else { throw .originalResidualRejected(value: residual,threshold: threshold) }
        try InertialParameterArithmetic.checkpoint(policy)
        return InertialParameterProduct(bindings: input.bindings,directions: direction,mechanics: tangent,
            primalInverse: inverse,primalEnergy: energy,requiredDriveDirection: required,
            originalResidual: residual,originalThreshold: threshold)
    }

    @inline(never)
    public func forwardProduct(_ input: InertialParameterInput, direction: [RigidInertialParameterDirection],
                               jointPolicy: JointEvaluationPolicy, admission: DynamicsAdmission, solvePolicy: DynamicsSolvePolicy,
                               policy: DerivativePolicy,
                               loadWork: inout LoadWork, supplierWork: inout DerivativeSupplierWork,
                               work: inout NumericalWork) throws(InertialParameterError) -> InertialParameterAccelerationProduct {
        try preflight(input,admission,solvePolicy,policy,&work)
        let prepared = try prepare(input,direction,policy,&supplierWork,&work)
        var workspace = MechanicalDerivativeWorkspace()
        try InertialParameterArithmetic.checkpoint(policy)
        var nested = try InertialParameterArithmetic.nested(work,reserved: prepared.reserved)
        try InertialParameterArithmetic.call(&supplierWork)
        let result: AccelerationTangent
        do { result = try mechanics.forwardDirection(input.primal,direction: prepared.direction,jointPolicy: jointPolicy,
            admission: admission,solvePolicy: solvePolicy,policy: policy,workspace: &workspace,loadWork: &loadWork,
            supplierWork: &supplierWork,work: &nested) }
        catch {
            try InertialParameterArithmetic.absorb(nested,reserved: prepared.reserved,into: &work)
            throw .derivative(error)
        }
        try InertialParameterArithmetic.absorb(nested,reserved: prepared.reserved,into: &work)
        try InertialParameterArithmetic.checkpoint(policy)
        return InertialParameterAccelerationProduct(bindings: input.bindings,directions: direction,dynamics: result)
    }

    @inline(never)
    private func mechanical(_ input: MechanicalDerivativeInput, _ direction: MechanicalDirection,
                            _ jointPolicy: JointEvaluationPolicy, _ admission: DynamicsAdmission, _ policy: DerivativePolicy,
                            _ reserved: Int, _ workspace: inout MechanicalDerivativeWorkspace, _ loads: inout LoadWork,
                            _ supplier: inout DerivativeSupplierWork, _ work: inout NumericalWork) throws(InertialParameterError) -> MechanicalTangent {
        try InertialParameterArithmetic.checkpoint(policy)
        var nested = try InertialParameterArithmetic.nested(work,reserved: reserved)
        try InertialParameterArithmetic.call(&supplier)
        let result: MechanicalTangent
        do { result = try mechanics.direction(input,direction: direction,jointPolicy: jointPolicy,admission: admission,
            policy: policy,workspace: &workspace,loadWork: &loads,supplierWork: &supplier,work: &nested) }
        catch {
            try InertialParameterArithmetic.absorb(nested,reserved: reserved,into: &work)
            throw .derivative(error)
        }
        try InertialParameterArithmetic.absorb(nested,reserved: reserved,into: &work)
        return result
    }

    @inline(never)
    private func prepare(_ input: InertialParameterInput, _ directions: [RigidInertialParameterDirection],
                         _ policy: DerivativePolicy, _ supplier: inout DerivativeSupplierWork,
                         _ work: inout NumericalWork) throws(InertialParameterError) -> (direction: MechanicalDirection, reserved: Int) {
        try InertialParameterArithmetic.checkpoint(policy)
        guard input.mappingPreservesTopology else { throw .topologyChange }
        // FIXME(INCOMPLETE_IMPLEMENTATION): This product has no inertial-parameter custom-force callback contract. The public entry points refuse such inputs before invocation; a supplier-owned analytic derivative and independent evidence are required before extending this domain.
        guard input.loadsAreParameterIndependent, input.primal.forceProvider == nil else { throw .forceDerivativeUnavailable }
        let primal = input.primal, b = primal.tree.bodies.count, n = primal.tree.layout.velocityCount
        guard b > 0, b <= policy.maximumBodies, n > 0, n <= policy.maximumVelocities else { throw .capacityExceeded }
        try InertialParameterArithmetic.charge(b,&work)
        guard primal.tree.bodies.allSatisfy({ $0.dimension == .spatial }), policy.inertiaValidation.physicalityRelative == 0 else { throw .unsupportedDomain }
        guard input.bindings.count == b, directions.count == b, input.currentRepresentations.count == b,
              primal.inertias.count == b, primal.drive.count == n, primal.state.acceleration.count == n,
              primal.state.v.count == n, primal.state.q.count == primal.tree.layout.positionCount,
              primal.parameters.isEmpty, primal.parameterIDs.isEmpty, primal.parameterDimensions.isEmpty else { throw .invalidShape }
        if let gravity = primal.gravity {
            try InertialParameterArithmetic.bytes(gravity.frame.key,policy,&work)
            try InertialParameterArithmetic.bytes(primal.tree.worldFrame.key,policy,&work)
            guard gravity.gradient == .zero, gravity.frame == primal.tree.worldFrame else { throw .unsupportedDomain }
        }
        guard primal.tree.revision == primal.state.revision else { throw .staleMapping }
        let reserved = try reservation(primal)
        try InertialParameterArithmetic.storage(reserved,&work)
        var mapped: [BodyInertiaDirection] = []
        mapped.reserveCapacity(b)
        for index in 0..<b {
            try InertialParameterArithmetic.checkpoint(policy)
            let binding = input.bindings[index], d = directions[index], body = primal.tree.bodies[index]
            let current = input.currentRepresentations[index], inertia = primal.inertias[index]
            for id in [binding.body,binding.frame,d.body,d.frame,body.id,body.frame,inertia.body,inertia.frame] {
                try InertialParameterArithmetic.bytes(id.key,policy,&work)
            }
            for source in [binding.representation.provenance.source,d.source.source,current.provenance.source] {
                try InertialParameterArithmetic.bytes(source,policy,&work)
            }
            try InertialParameterArithmetic.charge(80,&work)
            guard binding.modelRevision == primal.tree.revision, d.modelRevision == binding.modelRevision,
                  binding.body == body.id, binding.frame == body.frame, binding.referencePose == body.referencePose,
                  inertia.body == binding.body, inertia.frame == binding.frame,
                  d.body == binding.body, d.frame == binding.frame,
                  current == binding.representation, d.source == current.provenance,
                  inertia.properties == current.properties, d.parameterIDs == binding.parameterIDs else { throw .staleMapping }
            guard binding.parameterIDs.count == 10, d.parameterIDs.count == 10 else { throw .invalidShape }
            for previous in 0..<index {
                for id in binding.parameterIDs {
                    for previousID in input.bindings[previous].parameterIDs {
                        try InertialParameterArithmetic.checkpoint(policy)
                        try InertialParameterArithmetic.charge(1,&work)
                        guard id != previousID else { throw .invalidInput }
                    }
                }
            }
            for sign in [-1.0,1.0] {
                try InertialParameterArithmetic.checkpoint(policy)
                // Conservative constant bound includes endpoint conversion and Model's complete physical admission.
                try InertialParameterArithmetic.charge(1000,&work)
                let step = sign*policy.physicalNeighborhood
                let endpoint = try InertialParameterArithmetic.core { () throws(CoreError) in
                    (try binding.firstMoment.adding(d.firstMoment.scaled(by: step)),
                     try binding.inertiaAtOrigin.adding(d.inertiaAtOrigin.scaled(by: step)))
                }
                try InertialParameterArithmetic.call(&supplier)
                _ = try InertialParameterArithmetic.physical(mass: current.properties.mass+step*d.mass,
                    firstMoment: endpoint.0,inertiaAtOrigin: endpoint.1,policy: policy.inertiaValidation)
            }
            try InertialParameterArithmetic.charge(150,&work)
            let p = current.properties
            let conversion = try InertialParameterArithmetic.core { () throws(CoreError) in
                let dc = try d.firstMoment.subtracting(p.centerOfMass.scaled(by: d.mass)).scaled(by: 1/p.mass)
                let di = try d.inertiaAtOrigin.subtracting(InertialParameterArithmetic.parallelAxis(p.centerOfMass).scaled(by: d.mass))
                    .subtracting(InertialParameterArithmetic.parallelAxisDirection(p.centerOfMass,dc).scaled(by: p.mass))
                return (dc,di)
            }
            mapped.append(BodyInertiaDirection(body: binding.body,frame: binding.frame,mass: d.mass,
                centerOfMass: conversion.0,inertiaAtCenter: conversion.1))
        }
        try InertialParameterArithmetic.charge(try InertialParameterArithmetic.sum(
            InertialParameterArithmetic.sum(InertialParameterArithmetic.product(n,4),
                InertialParameterArithmetic.product(primal.bodyWrenches.count,9)),
            InertialParameterArithmetic.sum(primal.generalizedForces.count,
                InertialParameterArithmetic.product(primal.state.prescribedAnchors.count,18))),&work)
        let zero = [Double](repeating: 0,count: n)
        let tree = TreeDirection(revision: primal.tree.revision,configuration: zero,velocity: zero,acceleration: zero,
            screwPitch: zero,
            prescribed: [FrameMotionDirection](repeating: FrameMotionDirection(),count: primal.state.prescribedAnchors.count))
        let loadDirections = primal.bodyWrenches.map { BodyWrenchDirection(body: $0.body,frame: $0.frame) }
        let forceDirections = primal.generalizedForces.map { _ in zero }
        return (MechanicalDirection(tree: tree,inertias: mapped,bodyWrenches: loadDirections,
            generalizedForces: forceDirections,drive: zero),reserved)
    }

    private func reservation(_ input: MechanicalDerivativeInput) throws(InertialParameterError) -> Int {
        let b = input.tree.bodies.count, n = input.tree.layout.velocityCount
        let bodies = try InertialParameterArithmetic.product(200,b)
        let vectors = try InertialParameterArithmetic.product(40,n)
        let matrices = try InertialParameterArithmetic.product(2,InertialParameterArithmetic.product(n,n))
        let loads = try InertialParameterArithmetic.sum(InertialParameterArithmetic.product(10,input.bodyWrenches.count),
            InertialParameterArithmetic.product(n,input.generalizedForces.count))
        return try InertialParameterArithmetic.sum(InertialParameterArithmetic.sum(bodies,vectors),
            InertialParameterArithmetic.sum(matrices,InertialParameterArithmetic.sum(loads,1024)))
    }

    private func preflight(_ input: InertialParameterInput, _ admission: DynamicsAdmission,
                           _ solve: DynamicsSolvePolicy, _ policy: DerivativePolicy,
                           _ work: inout NumericalWork) throws(InertialParameterError) {
        try InertialParameterArithmetic.checkpoint(policy)
        guard !admission.isCancelled() else { throw .cancelled }
        try InertialParameterArithmetic.charge(8,&work)
        let primal = input.primal, n = primal.tree.layout.velocityCount
        guard solve.coordinateScales.count == n else { throw .invalidShape }
        guard primal.bodyWrenches.count <= admission.capacity.maximumBodyWrenches,
              primal.generalizedForces.count <= admission.capacity.maximumGeneralizedContributions,
              primal.tree.bodies.count <= admission.capacity.maximumBodies,
              n <= admission.capacity.maximumVelocities,
              primal.state.prescribedAnchors.count <= (try InertialParameterArithmetic.product(2,primal.tree.joints.count)) else {
            throw .capacityExceeded
        }
    }

    @inline(never)
    private func originalRequired(_ tangent: MechanicalTangent, _ directions: [BodyInertiaDirection],
                                  _ policy: DerivativePolicy, _ work: inout NumericalWork) throws(InertialParameterError) -> (required: [Double], kinetic: Double, kineticDirection: Double) {
        let system = tangent.system, n = system.velocityCount
        var result = [Double](repeating: 0,count: n)
        var kinetic = 0.0, kineticDirection = 0.0
        // Independently differentiates actual body Newton-Euler forces at fixed q/v/a; no dM/dBias access.
        for index in system.input.inertias.indices {
            try InertialParameterArithmetic.checkpoint(policy)
            try InertialParameterArithmetic.charge(1000,&work)
            let inertia = system.input.inertias[index], p = inertia.properties, d = directions[index]
            let state = system.input.snapshot.bodies[index]
            let body = try InertialParameterArithmetic.core { () throws(CoreError) in
                let r = try state.motion.pose.rotation.matrix()
                let offset = try r.applying(to: p.centerOfMass), doffset = try r.applying(to: d.centerOfMass)
                let tensor = try r.multiplied(by: p.inertiaAtCenter).multiplied(by: r.transposed())
                let dtensor = try r.multiplied(by: d.inertiaAtCenter).multiplied(by: r.transposed())
                let omega = state.motion.velocity.angular, alpha = state.motion.acceleration.angular
                let acceleration = try state.motion.acceleration.linear.adding(alpha.cross(offset))
                    .adding(omega.cross(omega.cross(offset)))
                let da = try alpha.cross(doffset).adding(omega.cross(omega.cross(doffset)))
                let force = try acceleration.scaled(by: p.mass)
                let dforce = try acceleration.scaled(by: d.mass).adding(da.scaled(by: p.mass))
                let dtorque = try dtensor.applying(to: alpha).adding(omega.cross(dtensor.applying(to: omega)))
                // The primal tensor participates in the independent fixed-state kinetic expression below.
                let velocity = try state.motion.velocity.linear.adding(omega.cross(offset))
                let dvelocity = try omega.cross(doffset)
                let dk = try d.mass*velocity.dot(velocity)/2+p.mass*velocity.dot(dvelocity)+omega.dot(dtensor.applying(to: omega))/2
                let kinetic = try (p.mass*velocity.dot(velocity)+omega.dot(tensor.applying(to: omega)))/2
                return (offset,doffset,force,dforce,dtorque,kinetic,dk)
            }
            kinetic = try InertialParameterArithmetic.finite(kinetic+body.5)
            kineticDirection = try InertialParameterArithmetic.finite(kineticDirection+body.6)
            let columns: ArraySlice<SpatialMotion>
            do { columns = try system.input.snapshot.geometricColumns(body: inertia.body) } catch { throw .joints(error) }
            guard columns.count == n else { throw .invalidShape }
            for (i,column) in columns.enumerated() {
                try InertialParameterArithmetic.checkpoint(policy)
                try InertialParameterArithmetic.charge(200,&work)
                let value = try InertialParameterArithmetic.core { () throws(CoreError) in
                    let com = try column.linear.adding(column.angular.cross(body.0))
                    let dcom = try column.angular.cross(body.1)
                    return try column.angular.dot(body.4)+dcom.dot(body.2)+com.dot(body.3)
                }
                result[i] = try InertialParameterArithmetic.finite(result[i]+value)
            }
        }
        return (result,kinetic,kineticDirection)
    }
}
