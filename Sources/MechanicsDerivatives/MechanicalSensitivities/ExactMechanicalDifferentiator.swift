import MechanicsCore
import MechanicsModel
import MechanicsJoints
import MechanicsLoads
import MechanicsDynamics
import MechanicsNumerics

public struct ExactMechanicalDifferentiator: MechanicalDifferentiating {
    private let equations: any RigidEquationComputing
    private let solver: any RigidDynamicsSolving
    public init(equations: any RigidEquationComputing = RigidEquationKernel(), solver: any RigidDynamicsSolving = DenseRigidDynamics()) {
        self.equations=equations; self.solver=solver
    }
    @inline(never)
    public func direction(_ input: MechanicalDerivativeInput, direction d: MechanicalDirection, jointPolicy: JointEvaluationPolicy,
                          admission: DynamicsAdmission, policy p: DerivativePolicy, workspace s: inout MechanicalDerivativeWorkspace,
                          loadWork: inout LoadWork, supplierWork: inout DerivativeSupplierWork, work w: inout NumericalWork) throws(DerivativeError) -> MechanicalTangent {
        guard input.bodyWrenches.count <= admission.capacity.maximumBodyWrenches,
              try DifferentialArithmetic.sum(input.generalizedForces.count,input.forceProvider == nil ? 0 : 1) <= admission.capacity.maximumGeneralizedContributions else { throw .capacityExceeded }
        try validate(input,d,p,&supplierWork,&w)
        let reserved=try storage(input)
        try DifferentialArithmetic.storage(DifferentialArithmetic.sum(reserved,s.retainedScalarSlots()),&w)
        let tree=try ExactTreeDifferentiator().direction(input.tree,state:input.state,direction:d.tree,jointPolicy:jointPolicy,
            policy:p,workspace:&s.tree,supplierWork:&supplierWork,work:&w)
        try callback(input,d,tree,p,&s,&supplierWork,&w)
        var forces=input.generalizedForces
        // COW materialization is confined to the supplier input boundary, once per product.
        if input.forceProvider != nil {
            do { forces.append(try GeneralizedForceContribution(values:s.callbackValue,channel:.applied)) }
            catch { throw .dynamics(error,failedSupplierWorkUnavailable:false) }
        }
        let original: RigidDynamicsInput
        do { original=try RigidDynamicsInput(snapshot:tree.snapshot,velocity:input.state.v,inertias:input.inertias,
            gravity:input.gravity,bodyWrenches:input.bodyWrenches,generalizedForces:forces) }
        catch { throw .dynamics(error,failedSupplierWorkUnavailable:false) }
        let system=try assemble(original,admission,reserved,&loadWork,&supplierWork,&w)
        return try MechanicalProductAssembler.evaluate(input,d,tree,system,p,&s,&w)
    }
    @inline(never)
    public func forwardDirection(_ input: MechanicalDerivativeInput, direction d: MechanicalDirection, jointPolicy: JointEvaluationPolicy,
                                 admission: DynamicsAdmission, solvePolicy: DynamicsSolvePolicy, policy p: DerivativePolicy,
                                 workspace s: inout MechanicalDerivativeWorkspace, loadWork: inout LoadWork,
                                 supplierWork: inout DerivativeSupplierWork, work w: inout NumericalWork) throws(DerivativeError) -> AccelerationTangent {
        let tangent=try direction(input,direction:d,jointPolicy:jointPolicy,admission:admission,policy:p,workspace:&s,
            loadWork:&loadWork,supplierWork:&supplierWork,work:&w)
        let reserved=try storage(input)
        let primal=try solve(tangent.system,input.drive,solvePolicy,reserved,false,&supplierWork,&w)
        let n=input.drive.count
        s.rightHandSide=[Double](repeating:0,count:n)
        for i in 0..<n {
            try DifferentialArithmetic.checkpoint(p); try DifferentialArithmetic.charge(3,&w)
            var value=try DifferentialArithmetic.finite(d.drive[i]+tangent.totalForce[i]-tangent.inertialBias[i])
            for j in 0..<n {
                try DifferentialArithmetic.charge(2,&w)
                value=try DifferentialArithmetic.finite(value-tangent.massMatrix[i*n+j]*primal.acceleration[j])
            }
            s.rightHandSide[i]=value
        }
        let solved=try solve(tangent.system,s.rightHandSide,solvePolicy,reserved,true,&supplierWork,&w)
        let evidence=try originalProduct(tangent,primal.acceleration,solved.acceleration,p,&s,&w)
        var residual=0.0, scale=0.0
        for i in 0..<n {
            try DifferentialArithmetic.charge(9,&w)
            let rhs=try DifferentialArithmetic.finite(d.drive[i]+tangent.totalForce[i])
            let actual=try DifferentialArithmetic.finite((evidence[i]/solvePolicy.energyScale)*solvePolicy.coordinateScales[i])
            let expected=try DifferentialArithmetic.finite((rhs/solvePolicy.energyScale)*solvePolicy.coordinateScales[i])
            residual=max(residual,abs(actual-expected)); scale=max(scale,max(abs(actual),abs(expected)))
        }
        try DifferentialArithmetic.charge(2,&w)
        let threshold=try DifferentialArithmetic.finite(p.residualTolerance.absolute+p.residualTolerance.relative*scale)
        guard residual <= threshold else { throw .originalResidualRejected(value:residual,threshold:threshold) }
        try DifferentialArithmetic.checkpoint(p)
        return AccelerationTangent(mechanics:tangent,primal:primal,acceleration:solved.acceleration,originalResidual:residual,originalThreshold:threshold)
    }
    @inline(never)
    public func forwardJacobian(_ input: MechanicalDerivativeInput, variable: MechanicalJacobianVariable, jointPolicy: JointEvaluationPolicy,
                                admission: DynamicsAdmission, solvePolicy: DynamicsSolvePolicy, policy p: DerivativePolicy,
                                workspace s: inout MechanicalDerivativeWorkspace, loadWork: inout LoadWork,
                                supplierWork: inout DerivativeSupplierWork, work w: inout NumericalWork) throws(DerivativeError) -> MechanicalAccelerationJacobian {
        let n=input.tree.layout.velocityCount, nn=try DifferentialArithmetic.product(n,n)
        guard n > 0, n <= p.maximumVelocities, n <= p.maximumJacobianColumns, input.tree.bodies.count <= p.maximumBodies else { throw .capacityExceeded }
        guard input.state.prescribedAnchors.count <= (try DifferentialArithmetic.product(input.tree.joints.count,2)) else { throw .capacityExceeded }
        let basis=try DifferentialArithmetic.sum(DifferentialArithmetic.product(n,6),
            DifferentialArithmetic.sum(DifferentialArithmetic.product(input.inertias.count,13),
                DifferentialArithmetic.sum(DifferentialArithmetic.product(input.bodyWrenches.count,9),
                    DifferentialArithmetic.sum(input.parameters.count,DifferentialArithmetic.product(input.state.prescribedAnchors.count,18)))))
        let outerReserved=try DifferentialArithmetic.sum(nn,basis)
        let reserved=try DifferentialArithmetic.sum(outerReserved,storage(input))
        try DifferentialArithmetic.storage(DifferentialArithmetic.sum(reserved,s.retainedScalarSlots()),&w)
        var result=[Double](repeating:0,count:nn), maximumResidual=0.0
        var q=[Double](repeating:0,count:n), v=q, drive=q
        let zeros=q
        var inertias:[BodyInertiaDirection]=[]; inertias.reserveCapacity(input.inertias.count)
        for x in input.inertias { inertias.append(BodyInertiaDirection(body:x.body,frame:x.frame)) }
        var wrenches:[BodyWrenchDirection]=[]; wrenches.reserveCapacity(input.bodyWrenches.count)
        for x in input.bodyWrenches { wrenches.append(BodyWrenchDirection(body:x.body,frame:x.frame)) }
        var generalized:[[Double]]=[]; generalized.reserveCapacity(input.generalizedForces.count)
        for _ in input.generalizedForces { generalized.append(zeros) }
        let parameterZeros=[Double](repeating:0,count:input.parameters.count)
        let prescribedZeros=[FrameMotionDirection](repeating:FrameMotionDirection(),count:input.state.prescribedAnchors.count)
        for column in 0..<n {
            try DifferentialArithmetic.checkpoint(p)
            do { try w.advanceIteration() } catch { throw .numerical(error) }
            switch variable { case .configuration: q[column]=1; case .velocity: v[column]=1; case .drive: drive[column]=1 }
            let td=TreeDirection(revision:input.tree.revision,configuration:q,velocity:v,acceleration:zeros,screwPitch:zeros,prescribed:prescribedZeros)
            let md=MechanicalDirection(tree:td,inertias:inertias,bodyWrenches:wrenches,generalizedForces:generalized,drive:drive,parameters:parameterZeros)
            // The published output matrix is live while each product runs; subtract it from the nested budget.
            var nested: NumericalWork
            do { nested=NumericalWork(budget:try w.remainingBudget(reservedStorage:outerReserved)) } catch { throw .numerical(error) }
            let product: AccelerationTangent
            do {
                product=try forwardDirection(input,direction:md,jointPolicy:jointPolicy,admission:admission,solvePolicy:solvePolicy,
                    policy:p,workspace:&s,loadWork:&loadWork,supplierWork:&supplierWork,work:&nested)
            } catch {
                do { try w.absorb(nested,reservedStorage:outerReserved) } catch { throw .numerical(error) }
                throw error
            }
            do { try w.absorb(nested,reservedStorage:outerReserved) } catch { throw .numerical(error) }
            for row in 0..<n { result[row*n+column]=product.acceleration[row] }
            maximumResidual=max(maximumResidual,product.originalResidual)
            switch variable { case .configuration: q[column]=0; case .velocity: v[column]=0; case .drive: drive[column]=0 }
        }
        try DifferentialArithmetic.checkpoint(p)
        return MechanicalAccelerationJacobian(revision:input.tree.revision,variable:variable,coordinateCount:n,values:result,maximumOriginalResidual:maximumResidual)
    }
    private func storage(_ input: MechanicalDerivativeInput) throws(DerivativeError) -> Int {
        let n=input.tree.layout.velocityCount, b=input.tree.bodies.count
        return try DifferentialArithmetic.sum(DifferentialArithmetic.sum(DifferentialArithmetic.product(b,500),DifferentialArithmetic.product(DifferentialArithmetic.product(b,n),60)),
            DifferentialArithmetic.sum(DifferentialArithmetic.product(DifferentialArithmetic.product(n,n),8),DifferentialArithmetic.sum(DifferentialArithmetic.product(n,36),DifferentialArithmetic.sum(DifferentialArithmetic.product(input.parameters.count,20),2048))))
    }
    @inline(never)
    private func validate(_ input: MechanicalDerivativeInput, _ d: MechanicalDirection, _ p: DerivativePolicy,
                          _ supplier: inout DerivativeSupplierWork, _ w: inout NumericalWork) throws(DerivativeError) {
        try DifferentialArithmetic.checkpoint(p)
        let n=input.tree.layout.velocityCount, b=input.tree.bodies.count
        guard n > 0, n <= p.maximumVelocities, b <= p.maximumBodies else { throw .capacityExceeded }
        guard input.inertias.count == b, d.inertias.count == b, input.drive.count == n, d.drive.count == n,
              input.bodyWrenches.count == d.bodyWrenches.count, input.generalizedForces.count == d.generalizedForces.count,
              input.parameters.count == d.parameters.count, input.parameters.count == input.parameterIDs.count,
              input.parameters.count == input.parameterDimensions.count else { throw .invalidShape }
        guard input.parameters.count <= p.maximumJacobianColumns else { throw .capacityExceeded }
        for i in input.parameters.indices {
            try DifferentialArithmetic.checkpoint(p); try DifferentialArithmetic.charge(2,&w)
            guard input.parameters[i].isFinite, d.parameters[i].isFinite else { throw .invalidInput }
            for j in 0..<i { try DifferentialArithmetic.charge(1,&w); guard input.parameterIDs[i] != input.parameterIDs[j] else { throw .invalidInput } }
        }
        for i in 0..<n {
            try DifferentialArithmetic.charge(2,&w)
            guard input.drive[i].isFinite, d.drive[i].isFinite else { throw .invalidInput }
        }
        for i in 0..<b {
            let a=input.inertias[i], da=d.inertias[i]
            try DifferentialArithmetic.identityBytes(a.body,p,&w); try DifferentialArithmetic.identityBytes(a.frame,p,&w)
            try DifferentialArithmetic.identityBytes(da.body,p,&w); try DifferentialArithmetic.identityBytes(da.frame,p,&w)
            guard a.body == da.body, a.frame == da.frame else { throw .staleBinding }
            try DifferentialArithmetic.charge(4,&w)
            guard da.mass.isFinite, da.inertiaAtCenter.m01 == da.inertiaAtCenter.m10,
                  da.inertiaAtCenter.m02 == da.inertiaAtCenter.m20, da.inertiaAtCenter.m12 == da.inertiaAtCenter.m21 else { throw .invalidInput }
            for slot in 0..<2 {
                let sign=slot == 0 ? -1.0 : 1.0
                try DifferentialArithmetic.checkpoint(p)
                try DifferentialArithmetic.charge(27,&w); try supplier.chargeCall()
                do {
                    let step=sign*p.physicalNeighborhood
                    _=try MassProperties3D(mass:a.properties.mass+step*da.mass,
                        centerOfMass:a.properties.centerOfMass.adding(da.centerOfMass.scaled(by:step)),
                        inertiaAtCenter:a.properties.inertiaAtCenter.adding(da.inertiaAtCenter.scaled(by:step)),policy:p.inertiaValidation)
                } catch let error as ModelError { throw .model(error) }
                catch let error as CoreError { throw .core(error) }
                catch { throw .unexpectedSupplierFailure }
            }
        }
        for i in input.generalizedForces.indices {
            guard input.generalizedForces[i].values.count == n, d.generalizedForces[i].count == n else { throw .invalidShape }
            for x in d.generalizedForces[i] { try DifferentialArithmetic.charge(1,&w); guard x.isFinite else { throw .invalidInput } }
        }
        for i in input.bodyWrenches.indices {
            let a=input.bodyWrenches[i], da=d.bodyWrenches[i]
            try DifferentialArithmetic.identityBytes(a.body,p,&w); try DifferentialArithmetic.identityBytes(a.frame,p,&w)
            try DifferentialArithmetic.identityBytes(da.body,p,&w); try DifferentialArithmetic.identityBytes(da.frame,p,&w)
            guard a.body == da.body, a.frame == da.frame else { throw .staleBinding }
        }
        if input.gravity == nil, d.gravity != .zero { throw .derivativeUnavailable }
        if input.forceProvider == nil, !input.parameters.isEmpty { throw .derivativeUnavailable }
    }
    @inline(never)
    private func callback(_ input: MechanicalDerivativeInput, _ d: MechanicalDirection, _ tangent: TreeTangent,
                          _ p: DerivativePolicy, _ s: inout MechanicalDerivativeWorkspace, _ supplier: inout DerivativeSupplierWork,
                          _ w: inout NumericalWork) throws(DerivativeError) {
        guard let provider=input.forceProvider else { return }
        try supplier.chargeCall()
        let m=provider.metadata, n=input.tree.layout.velocityCount
        guard m.parameterIDs.count == input.parameters.count, m.parameterDimensions.count == input.parameters.count else { throw .staleBinding }
        try DifferentialArithmetic.charge(try DifferentialArithmetic.product(input.parameters.count,9),&w)
        guard m.parameterIDs == input.parameterIDs, m.parameterDimensions == input.parameterDimensions else { throw .staleBinding }
        guard m.revision == input.tree.revision, m.coordinateCount == n, m.parameterCount == input.parameters.count else { throw .staleBinding }
        // FIXME(INCOMPLETE_IMPLEMENTATION): A force provider without an analytic/automatic derivative cannot enter this mechanical product. No finite difference surrogate is supplied; actual derivative requirements and evidence are necessary.
        guard m.availability != .unavailable else { throw .derivativeUnavailable }
        try DifferentialArithmetic.charge(try DifferentialArithmetic.product(n,4),&w)
        s.callbackValue=[Double](repeating:.nan,count:n); s.callbackDirection=[Double](repeating:.nan,count:n)
        try supplier.chargeCall(); try DifferentialArithmetic.checkpoint(p)
        try checkedCallback(&w) { ledger throws(DerivativeError) in
            try provider.value(tangent.snapshot,state:input.state,parameters:input.parameters,into:&s.callbackValue,work:&ledger)
        }
        try metadata(provider,m,p,&supplier,&w)
        guard s.callbackValue.count == n else { throw .invalidShape }
        for value in s.callbackValue { guard value.isFinite else { throw .nonFiniteResult } }
        try supplier.chargeCall(); try DifferentialArithmetic.checkpoint(p)
        try checkedCallback(&w) { ledger throws(DerivativeError) in
            try provider.direction(tangent,state:input.state,treeDirection:d.tree,parameters:input.parameters,parameterDirection:d.parameters,into:&s.callbackDirection,work:&ledger)
        }
        try metadata(provider,m,p,&supplier,&w)
        guard s.callbackDirection.count == n else { throw .invalidShape }
        for value in s.callbackDirection { guard value.isFinite else { throw .nonFiniteResult } }
        try DifferentialArithmetic.checkpoint(p)
    }
    @inline(never)
    private func checkedCallback(_ work: inout NumericalWork,
                                 _ operation: (inout NumericalWork) throws(DerivativeError) -> Void) throws(DerivativeError) {
        let previous = work
        var failure: DerivativeError?
        do throws(DerivativeError) { try operation(&work) } catch { failure = error }
        guard work.budget.scalarStorage == previous.budget.scalarStorage,
              work.budget.arithmeticOperations == previous.budget.arithmeticOperations,
              work.budget.iterations == previous.budget.iterations,
              work.operations >= previous.operations, work.iterations >= previous.iterations,
              work.peakScalarStorage >= previous.peakScalarStorage else {
            work = previous
            throw .invalidSupplierLedger(failedSupplierWorkUnavailable: true)
        }
        if let failure { throw failure }
    }
    private func metadata(_ provider: any DifferentiatedForceProviding, _ expected: ForceDerivativeMetadata, _ p: DerivativePolicy,
                          _ supplier: inout DerivativeSupplierWork, _ w: inout NumericalWork) throws(DerivativeError) {
        try DifferentialArithmetic.checkpoint(p); try supplier.chargeCall()
        let actual=provider.metadata
        guard actual.parameterIDs.count == expected.parameterIDs.count, actual.parameterDimensions.count == expected.parameterDimensions.count else { throw .callbackMetadataChanged }
        try DifferentialArithmetic.charge(try DifferentialArithmetic.sum(4,DifferentialArithmetic.product(expected.parameterIDs.count,9)),&w)
        guard actual == expected else { throw .callbackMetadataChanged }
    }
    @inline(never)
    private func assemble(_ input: RigidDynamicsInput, _ admission: DynamicsAdmission, _ reserved: Int, _ loads: inout LoadWork,
                          _ supplier: inout DerivativeSupplierWork, _ w: inout NumericalWork) throws(DerivativeError) -> RigidDynamicsSystem {
        var nested: NumericalWork
        do { nested=NumericalWork(budget:try w.remainingBudget(reservedStorage:reserved)) } catch { throw .numerical(error) }
        try supplier.chargeCall()
        let system: RigidDynamicsSystem
        do { system=try equations.assemble(input,admission:admission,loadWork:&loads,work:&nested) }
        catch {
            do { try w.absorb(nested,reservedStorage:reserved) } catch { throw .numerical(error) }
            throw .dynamics(error,failedSupplierWorkUnavailable:failedWork(error))
        }
        do { try w.absorb(nested,reservedStorage:reserved) } catch { throw .numerical(error) }
        return system
    }
    @inline(never)
    private func solve(_ system: RigidDynamicsSystem, _ rhs: [Double], _ policy: DynamicsSolvePolicy, _ reserved: Int, _ massOnly: Bool,
                       _ supplier: inout DerivativeSupplierWork, _ w: inout NumericalWork) throws(DerivativeError) -> DynamicsSolution {
        var nested: NumericalWork
        do { nested=NumericalWork(budget:try w.remainingBudget(reservedStorage:reserved)) } catch { throw .numerical(error) }
        try supplier.chargeCall()
        let result: DynamicsSolution
        do {
            if massOnly { result=try solver.inverseMassProduct(system,rightHandSide:rhs,policy:policy,work:&nested) }
            else { result=try solver.forward(system,driveForce:rhs,policy:policy,work:&nested) }
        } catch {
            do { try w.absorb(nested,reservedStorage:reserved) } catch { throw .numerical(error) }
            throw .dynamics(error,failedSupplierWorkUnavailable:failedWork(error))
        }
        do { try w.absorb(nested,reservedStorage:reserved) } catch { throw .numerical(error) }
        return result
    }
    private func failedWork(_ error: DynamicsError) -> Bool {
        if case .numerical(_,let unavailable)=error { return unavailable }; return false
    }
    @inline(never)
    private func originalProduct(_ tangent: MechanicalTangent, _ acceleration: [Double], _ da: [Double], _ p: DerivativePolicy,
                                 _ s: inout MechanicalDerivativeWorkspace, _ w: inout NumericalWork) throws(DerivativeError) -> [Double] {
        let n=acceleration.count
        s.originalDirection=[Double](repeating:0,count:n)
        // Independently differentiates body Newton-Euler at the accepted acceleration; no assembled dM/dBias access.
        for index in tangent.system.input.inertias.indices {
            try DifferentialArithmetic.checkpoint(p)
            let body=try WorldBodyDifferential.evaluate(tangent.tree,tangent.system.input.inertias,tangent.inertiaDirections,index,&w)
            let required=try body.required(tangent.tree,body:index,acceleration:acceleration,direction:da,&w)
            for i in 0..<n {
                let col=try body.column(tangent.tree.columns[index*n+i],&w)
                let scalar=try DifferentialArithmetic.add(DifferentialArithmetic.dot(col.angular,required.angular,&w),DifferentialArithmetic.dot(col.linear,required.linear,&w),&w)
                try DifferentialArithmetic.charge(1,&w)
                s.originalDirection[i]=try DifferentialArithmetic.finite(s.originalDirection[i]+scalar.direction)
            }
        }
        return s.originalDirection
    }
}
