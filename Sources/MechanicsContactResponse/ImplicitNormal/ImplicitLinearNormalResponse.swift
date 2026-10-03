import MechanicsCore
import MechanicsModel
import MechanicsNumerics
import MechanicsJoints
import MechanicsDynamics
import MechanicsCollision
import MechanicsContactLaws
import MechanicsComplementarity

public struct ImplicitLinearNormalResponse: CoupledContactResponding {
    private let adapter: any ContactWitnessAdapting
    private let dynamics: any RigidDynamicsSolving
    private let equations: any RigidEquationComputing
    private let complementarity: any ComplementaritySolving
    private let laws: any ContactLawEvaluating
    public init(adapter: any ContactWitnessAdapting = RigidContactWitnessAdapter(),
                dynamics: any RigidDynamicsSolving = DenseRigidDynamics(), equations: any RigidEquationComputing = RigidEquationKernel(),
                complementarity: any ComplementaritySolving = ProjectedComplementaritySolver(), laws: any ContactLawEvaluating = CompliantContactEvaluator()) {
        self.adapter=adapter; self.dynamics=dynamics; self.equations=equations; self.complementarity=complementarity; self.laws=laws
    }
    public func solve(_ input: ContactResponseInput, policy: ContactResponsePolicy,
                      responseWork: inout NumericalWork, dynamicsWork: inout NumericalWork, coneWork: inout NumericalWork,
                      lawWork: inout ContactWork) throws(ContactResponseError) -> ContactResponseSolution {
        let ports=try prepare(input,policy:policy,responseWork:&responseWork)
        let n=input.system.velocityCount, c=ports.count
        var workspace=NormalResponseWorkspace(velocityCount:n,contactCount:c)
        try freeMotion(input,policy:policy,workspace:&workspace,responseWork:&responseWork,dynamicsWork:&dynamicsWork)
        for j in 0..<c {
            try ResponseArithmetic.check(policy)
            try inverseImage(j,ports:ports,input:input,policy:policy,workspace:&workspace,dynamicsWork:&dynamicsWork)
            try effectiveColumn(j,ports:ports,workspace:&workspace,responseWork:&responseWork)
        }
        try assemble(input,policy:policy,ports:ports,workspace:&workspace,responseWork:&responseWork)
        let solved=try solveCone(input,policy:policy,ports:ports,workspace:&workspace,coneWork:&coneWork)
        try applyEndpoint(input,policy:policy,solved:solved,workspace:&workspace,responseWork:&responseWork)
        for j in 0..<c {
            try ResponseArithmetic.check(policy)
            let port=ports[j]
            let trial=try evaluateTrial(port,forceValue:solved.values[j],input:input,velocity:workspace.endpoint,policy:policy,responseWork:&responseWork,lawWork:&lawWork)
            workspace.lawResidual=max(workspace.lawResidual,trial.lawResidual)
            workspace.coneResidual=max(workspace.coneResidual,trial.coneResidual)
            let wrench=try verifyWrench(port,trial:trial,policy:policy,responseWork:&responseWork)
            workspace.lawResidual=max(workspace.lawResidual,wrench.lawResidual)
            workspace.wrenchResidual=max(workspace.wrenchResidual,wrench.wrenchResidual)
            try mapAndObserve(port,trial:trial,wrench:wrench,input:input,policy:policy,workspace:&workspace,responseWork:&responseWork)
        }
        let momentumResidual=try verifyMomentum(input,policy:policy,workspace:&workspace,responseWork:&responseWork,dynamicsWork:&dynamicsWork)
        try reject(workspace.lawResidual,phase:.normalLaw,policy:policy); try reject(workspace.coneResidual,phase:.normalCone,policy:policy)
        try reject(momentumResidual,phase:.momentum,policy:policy); try reject(workspace.wrenchResidual,phase:.wrench,policy:policy); try reject(workspace.powerResidual,phase:.power,policy:policy)
        try ResponseArithmetic.check(policy)
        let evidence=ContactPhysicalEvidence(normalLawResidual:workspace.lawResidual,normalConeResidual:workspace.coneResidual,momentumResidual:momentumResidual,
            wrenchResidual:workspace.wrenchResidual,powerResidual:workspace.powerResidual,threshold:policy.originalTolerance)
        return ContactResponseSolution(endpointVelocity:workspace.endpoint,generalizedContactForce:workspace.generalized,effectiveMassInverse:workspace.effective,observations:workspace.observations,
            originalPhysicalResidual:evidence,actualPower:workspace.actualPower,virtualPower:workspace.virtualPower,prescribedPower:workspace.prescribedPower,
            effectiveMassRank:nil,uniqueCompliantForce:true,numericalDiagnostics:solved.diagnostics,responseWork:responseWork,dynamicsWork:dynamicsWork,coneWork:coneWork,lawWork:lawWork)
    }
    // Keep compiler stack frames local to a bounded numerical phase.
    @inline(never)
    private func prepare(_ input: ContactResponseInput, policy: ContactResponsePolicy, responseWork: inout NumericalWork) throws(ContactResponseError) -> [PreparedContact] {
        try ResponseArithmetic.check(policy)
        let n=input.system.velocityCount, c=input.contacts.count, snapshot=input.system.input.snapshot
        guard c > 0, n > 0, input.driveForce.count == n, policy.dynamics.coordinateScales.count == n else { throw .invalidInput }
        guard c <= policy.maximumContacts, n <= policy.maximumVelocities, snapshot.bodies.count <= policy.maximumBodies,
              input.collision.proxies.count <= policy.maximumColliders else { throw .capacityExceeded }
        guard input.expectedModelRevision == snapshot.tree.revision else { throw .staleModel }
        guard input.expectedCollisionRevision == input.collision.revision else { throw .staleCollision }
        guard policy.precision == .float64, policy.backend == .referenceCPU else { throw .numerical(.unsupportedCapability) }
        let cn=try ResponseArithmetic.product(c,n), square=try ResponseArithmetic.product(c,c)
        // 256 scalar-equivalent slots per contact conservatively cover fixed port/observation records.
        // Local and retained supplier vectors are included; borrowed producer snapshots are excluded.
        let reserved=try ResponseArithmetic.sum(ResponseArithmetic.product(2,cn),ResponseArithmetic.sum(ResponseArithmetic.product(2,square),ResponseArithmetic.sum(ResponseArithmetic.product(12,n),ResponseArithmetic.product(256,c))))
        try ResponseArithmetic.storage(reserved,&responseWork)
        for i in 0..<n { try ResponseArithmetic.charge(1,&responseWork); guard input.driveForce[i].isFinite else { throw .invalidInput } }
        for i in 0..<c { for j in 0..<i { try ResponseArithmetic.charge(1,&responseWork); guard input.contacts[i].coordinateID != input.contacts[j].coordinateID else { throw .invalidInput } } }
        var ports: [PreparedContact]=[]; ports.reserveCapacity(c)
        for binding in input.contacts { ports.append(try adapter.prepare(binding,input:input,policy:policy,work:&responseWork)) }
        for port in ports { guard port.normalRow.count == n else { throw .invalidSupplierOutput } }
        return ports
    }
    // Keep compiler stack frames local to a bounded numerical phase.
    @inline(never)
    private func freeMotion(_ input: ContactResponseInput, policy: ContactResponsePolicy, workspace: inout NormalResponseWorkspace, responseWork: inout NumericalWork, dynamicsWork: inout NumericalWork) throws(ContactResponseError) {
        let n=input.system.velocityCount, h=input.timeStep
        let free: DynamicsSolution
        do { free=try dynamics.forward(input.system,driveForce:input.driveForce,policy:policy.dynamics,work:&dynamicsWork) } catch { throw .dynamics(error) }
        guard free.acceleration.count == n else { throw .invalidSupplierOutput }
        for i in 0..<n { try ResponseArithmetic.charge(2,&responseWork); workspace.freeVelocity[i]=try ResponseArithmetic.finite(input.system.input.velocity[i]+h*free.acceleration[i]) }
    }
    // Keep compiler stack frames local to a bounded numerical phase.
    @inline(never)
    private func inverseImage(_ j: Int, ports: [PreparedContact], input: ContactResponseInput, policy: ContactResponsePolicy, workspace: inout NormalResponseWorkspace, dynamicsWork: inout NumericalWork) throws(ContactResponseError) {
        let n=input.system.velocityCount
        for i in 0..<n { workspace.rhs[i]=ports[j].normalRow[i] }
        let image: DynamicsSolution
        do { image=try dynamics.inverseMassProduct(input.system,rightHandSide:workspace.rhs,policy:policy.dynamics,work:&dynamicsWork) } catch { throw .dynamics(error) }
        guard image.acceleration.count == n else { throw .invalidSupplierOutput }
        // Persistent flattened storage permits cross-contact products after supplier outputs release.
        for i in 0..<n { workspace.images[j*n+i]=image.acceleration[i] }
    }
    // Keep compiler stack frames local to a bounded numerical phase.
    @inline(never)
    private func effectiveColumn(_ j: Int, ports: [PreparedContact], workspace: inout NormalResponseWorkspace, responseWork: inout NumericalWork) throws(ContactResponseError) {
        let n=workspace.endpoint.count, c=ports.count
        for i in 0..<c {
            var value=0.0
            for k in 0..<n { try ResponseArithmetic.charge(2,&responseWork); value=try ResponseArithmetic.finite(value+ports[i].normalRow[k]*workspace.images[j*n+k]) }
            workspace.effective[i*c+j]=value
        }
    }
    // Keep compiler stack frames local to a bounded numerical phase.
    @inline(never)
    private func assemble(_ input: ContactResponseInput, policy: ContactResponsePolicy, ports: [PreparedContact], workspace: inout NormalResponseWorkspace, responseWork: inout NumericalWork) throws(ContactResponseError) {
        let n=input.system.velocityCount, c=ports.count, h=input.timeStep
        for i in 0..<c {
            var velocity=ports[i].normalDrift
            for k in 0..<n { try ResponseArithmetic.charge(2,&responseWork); velocity=try ResponseArithmetic.finite(velocity+ports[i].normalRow[k]*workspace.freeVelocity[k]) }
            try ResponseArithmetic.charge(3,&responseWork)
            workspace.linear[i]=try ResponseArithmetic.finite((ports[i].binding.witness.separation+h*velocity)/policy.lengthScale)
            for j in i..<c {
                try ResponseArithmetic.charge(3,&responseWork)
                let symmetry=abs(workspace.effective[i*c+j]-workspace.effective[j*c+i])*(policy.forceScale/policy.lengthScale)*h*h
                try reject(symmetry,phase:.momentum,policy:policy)
                try ResponseArithmetic.charge(5,&responseWork)
                var a=h*h*workspace.effective[i*c+j]
                if i == j { try ResponseArithmetic.charge(2,&responseWork); a=try ResponseArithmetic.finite(a+1/ports[i].stiffness) }
                let value=try ResponseArithmetic.finite((policy.forceScale/policy.lengthScale)*a)
                workspace.scaled[i*c+j]=value; workspace.scaled[j*c+i]=value
            }
        }
    }
    // Keep compiler stack frames local to a bounded numerical phase.
    @inline(never)
    private func solveCone(_ input: ContactResponseInput, policy: ContactResponsePolicy, ports: [PreparedContact], workspace: inout NormalResponseWorkspace, coneWork: inout NumericalWork) throws(ContactResponseError) -> ComplementaritySolution {
        let c=ports.count
        var coordinateIDs: [UInt64]=[]; coordinateIDs.reserveCapacity(c)
        for port in ports { coordinateIDs.append(port.binding.coordinateID) }
        let matrix: DenseMatrix<Double>, remaining: NumericalBudget
        do { matrix=try DenseMatrix(rows:c,columns:c,values:workspace.scaled); remaining=try coneWork.remainingBudget(reservedStorage:0) } catch { throw .numerical(error) }
        let problem: ComplementarityProblem, numericalPolicy: ComplementarityPolicy
        do {
            problem=try ComplementarityProblem(matrix:matrix,linearTerm:workspace.linear,
                cone:.nonnegativeOrthant(dimension:c),identity:ComplementarityIdentity(revision:input.expectedModelRevision,coordinateIDs:coordinateIDs,
                    frameLayoutRevision:input.expectedCollisionRevision,lawRevision:input.expectedModelRevision))
            numericalPolicy=try ComplementarityPolicy(precision:policy.precision,backend:policy.backend,tolerance:policy.coneTolerance,
                maximumIterations:policy.maximumConeIterations,choleskyPivotThreshold:policy.conePivotThreshold,budget:remaining)
        } catch { throw .complementarity(error,failedSupplierWorkUnavailable:false) }
        let solved: ComplementaritySolution
        do { solved=try complementarity.solve(problem,policy:numericalPolicy,warmStart:nil) } catch { throw .complementarity(error,failedSupplierWorkUnavailable:true) }
        do { try coneWork.absorb(solved.diagnostics.work,reservedStorage:0) } catch { throw .numerical(error) }
        guard solved.values.count == c else { throw .invalidSupplierOutput }
        return solved
    }
    // Keep compiler stack frames local to a bounded numerical phase.
    @inline(never)
    private func applyEndpoint(_ input: ContactResponseInput, policy: ContactResponsePolicy, solved: ComplementaritySolution, workspace: inout NormalResponseWorkspace, responseWork: inout NumericalWork) throws(ContactResponseError) {
        let n=input.system.velocityCount, c=input.contacts.count, h=input.timeStep
        for i in 0..<n {
            var correction=0.0
            for j in 0..<c {
                try ResponseArithmetic.charge(3,&responseWork)
                guard solved.values[j] >= 0 else { throw .invalidSupplierOutput }
                correction=try ResponseArithmetic.finite(correction+workspace.images[j*n+i]*solved.values[j]*policy.forceScale)
            }
            try ResponseArithmetic.charge(2,&responseWork); workspace.endpoint[i]=try ResponseArithmetic.finite(workspace.freeVelocity[i]+h*correction)
        }
    }
    // Keep compiler stack frames local to a bounded numerical phase.
    @inline(never)
    private func evaluateTrial(_ port: PreparedContact, forceValue: Double, input: ContactResponseInput, velocity: [Double], policy: ContactResponsePolicy, responseWork: inout NumericalWork, lawWork: inout ContactWork) throws(ContactResponseError) -> NormalLawTrial {
        let binding=port.binding, witness=binding.witness, snapshot=input.system.input.snapshot, h=input.timeStep
        try ResponseArithmetic.charge(1,&responseWork)
        let force=try ResponseArithmetic.finite(forceValue*policy.forceScale)
        let motion=try relativeVelocity(port,velocity:velocity,snapshot:snapshot,policy:policy,work:&responseWork)
        let relative=motion.linear
        let vn=try ResponseArithmetic.dot(witness.normal,relative,&responseWork)
        try ResponseArithmetic.charge(2,&responseWork)
        let gap=try ResponseArithmetic.finite(witness.separation+h*vn)
        let lawInput: ContactInput
        do { lawInput=try ContactInput(identity:binding.accepted.identity,basis:binding.basis,separation:gap,relativeVelocity:relative,
            relativeAngularVelocity:motion.angular,startTimeSeconds:snapshot.time,timeStepSeconds:h) } catch { throw .law(error) }
        let response: ContactResponse
        do { response=try laws.evaluate(input:lawInput,pair:binding.pair,accepted:binding.accepted,policy:policy.law,work:&lawWork) } catch { throw .law(error) }
        try ResponseArithmetic.charge(12,&responseWork)
        let lawResidual=abs(force-response.compressiveNormalForce)/policy.forceScale
        let x=force/policy.forceScale, dual=try ResponseArithmetic.finite((gap+force/port.stiffness)/policy.lengthScale)
        let projected=max(x-dual,0)
        let coneResidual=max(max(-x,0),max(max(-dual,0),max(abs(x*dual),abs(x-projected))))
        return NormalLawTrial(force:force,relative:relative,normalVelocity:vn,gap:gap,x:x,response:response,lawResidual:lawResidual,coneResidual:coneResidual)
    }
    // Keep compiler stack frames local to a bounded numerical phase.
    @inline(never)
    private func verifyWrench(_ port: PreparedContact, trial: NormalLawTrial, policy: ContactResponsePolicy, responseWork: inout NumericalWork) throws(ContactResponseError) -> NormalWrenchTrial {
        let witness=port.binding.witness, force=trial.force, response=trial.response
        let forceB=try ResponseArithmetic.scale(witness.normal,force,&responseWork)
        var lawResidual=try ResponseArithmetic.norm(ResponseArithmetic.sub(forceB,response.forceOnB,&responseWork),&responseWork)/policy.forceScale
        lawResidual=max(lawResidual,try ResponseArithmetic.norm(response.coupleOnB,&responseWork)/(policy.forceScale*policy.lengthScale))
        let forceA=try ResponseArithmetic.scale(forceB,-1,&responseWork)
        let torqueA=try ResponseArithmetic.cross(witness.pointA,forceA,&responseWork), torqueB=try ResponseArithmetic.cross(witness.pointB,forceB,&responseWork)
        let forceBalance=try ResponseArithmetic.norm(ResponseArithmetic.add(forceA,forceB,&responseWork),&responseWork)/policy.forceScale
        let torqueBalance=try ResponseArithmetic.norm(ResponseArithmetic.add(torqueA,torqueB,&responseWork),&responseWork)/(policy.forceScale*policy.lengthScale)
        let wrenchResidual=max(forceBalance,torqueBalance)
        return NormalWrenchTrial(forceA:forceA,forceB:forceB,torqueA:torqueA,torqueB:torqueB,lawResidual:lawResidual,wrenchResidual:wrenchResidual)
    }
    // Keep compiler stack frames local to a bounded numerical phase.
    @inline(never)
    private func mapAndObserve(_ port: PreparedContact, trial: NormalLawTrial, wrench: NormalWrenchTrial, input: ContactResponseInput, policy: ContactResponsePolicy, workspace: inout NormalResponseWorkspace, responseWork: inout NumericalWork) throws(ContactResponseError) {
        let n=input.system.velocityCount, h=input.timeStep, snapshot=input.system.input.snapshot
        let binding=port.binding, witness=binding.witness, response=trial.response
        let force=trial.force, relative=trial.relative, x=trial.x, vn=trial.normalVelocity, gap=trial.gap
        let forceA=wrench.forceA, forceB=wrench.forceB, torqueA=wrench.torqueA, torqueB=wrench.torqueB
        var mappedPower=0.0
        let columnsA: ArraySlice<SpatialMotion>, columnsB: ArraySlice<SpatialMotion>
        do { columnsA=try snapshot.geometricColumns(body:port.firstBody.body); columnsB=try snapshot.geometricColumns(body:port.secondBody.body) } catch { throw .joints(error) }
        // Body-origin torque/J mapping is independent of the adapter's point normalRow.
        let localTorqueA=try ResponseArithmetic.cross(port.firstOffset,forceA,&responseWork), localTorqueB=try ResponseArithmetic.cross(port.secondOffset,forceB,&responseWork)
        for i in 0..<n {
            let a=columnsA[columnsA.startIndex+i], b=columnsB[columnsB.startIndex+i]
            let qa=try ResponseArithmetic.dot(a.linear,forceA,&responseWork)+ResponseArithmetic.dot(a.angular,localTorqueA,&responseWork)
            let qb=try ResponseArithmetic.dot(b.linear,forceB,&responseWork)+ResponseArithmetic.dot(b.angular,localTorqueB,&responseWork)
            try ResponseArithmetic.charge(5,&responseWork)
            let q=try ResponseArithmetic.finite(qa+qb)
            workspace.generalized[i]=try ResponseArithmetic.finite(workspace.generalized[i]+q)
            mappedPower=try ResponseArithmetic.finite(mappedPower+q*workspace.endpoint[i])
        }
        let driftPower=try ResponseArithmetic.dot(forceB,port.relativeDrift,&responseWork)
        let actual=try ResponseArithmetic.dot(forceB,relative,&responseWork)
        try ResponseArithmetic.charge(5,&responseWork)
        workspace.powerResidual=max(workspace.powerResidual,abs(actual-mappedPower-driftPower)/policy.powerScale)
        workspace.actualPower=try ResponseArithmetic.finite(workspace.actualPower+actual); workspace.virtualPower=try ResponseArithmetic.finite(workspace.virtualPower+mappedPower)
        workspace.prescribedPower=try ResponseArithmetic.finite(workspace.prescribedPower+driftPower)
        workspace.observations.append(ContactObservation(coordinateID:binding.coordinateID,firstBody:binding.accepted.identity.firstBody,
            secondBody:binding.accepted.identity.secondBody,frame:binding.accepted.identity.frame,firstFeature:witness.featureA,secondFeature:witness.featureB,
            pointA:witness.pointA,pointB:witness.pointB,intervalStart:snapshot.time,intervalEnd:response.trialHistory.timeSeconds,
            normalForce:force,trialSeparation:gap,normalVelocity:vn,forceOnB:forceB,equivalentImpulseOnB:try ResponseArithmetic.scale(forceB,h,&responseWork),
            wrenchOnA:SpatialWrench(torque:torqueA,force:forceA),wrenchOnB:SpatialWrench(torque:torqueB,force:forceB),
            active:x > policy.originalTolerance ? .loaded : .separated,lawResponse:response))
    }
    // Keep compiler stack frames local to a bounded numerical phase.
    @inline(never)
    private func verifyMomentum(_ input: ContactResponseInput, policy: ContactResponsePolicy, workspace: inout NormalResponseWorkspace, responseWork: inout NumericalWork, dynamicsWork: inout NumericalWork) throws(ContactResponseError) -> Double {
        let n=input.system.velocityCount, h=input.timeStep
        for i in 0..<n { try ResponseArithmetic.charge(2,&responseWork); workspace.trialAcceleration[i]=try ResponseArithmetic.finite((workspace.endpoint[i]-input.system.input.velocity[i])/h) }
        do { try equations.originalInertialForce(input.system,acceleration:workspace.trialAcceleration,includeBias:true,into:&workspace.original,work:&dynamicsWork) } catch { throw .dynamics(error) }
        guard workspace.original.count == n else { throw .invalidSupplierOutput }
        var momentumResidual=0.0
        for i in 0..<n {
            try ResponseArithmetic.charge(11,&responseWork)
            let known: Double
            do { known=try input.system.forces.total(at:i) } catch { throw .dynamics(error) }
            let difference=try ResponseArithmetic.finite(workspace.original[i]-input.driveForce[i]-known-workspace.generalized[i])
            let normalized=try ResponseArithmetic.finite(abs(difference)*h*policy.dynamics.coordinateScales[i]/(policy.dynamics.energyScale*policy.dynamics.timeScale))
            momentumResidual=max(momentumResidual,normalized)
        }
        return momentumResidual
    }
    private func reject(_ value: Double,phase: ContactResidualPhase,policy: ContactResponsePolicy) throws(ContactResponseError) {
        guard value.isFinite else { throw .nonFiniteResult }
        guard value <= policy.originalTolerance else { throw .originalResidual(phase:phase,value:value,threshold:policy.originalTolerance) }
    }
    private func relativeVelocity(_ port: PreparedContact,velocity: [Double],snapshot: KinematicSnapshot,
                                  policy: ContactResponsePolicy,work: inout NumericalWork) throws(ContactResponseError) -> (linear: Vector3, angular: Vector3) {
        let a: ArraySlice<SpatialMotion>, b: ArraySlice<SpatialMotion>
        do { a=try snapshot.geometricColumns(body:port.firstBody.body); b=try snapshot.geometricColumns(body:port.secondBody.body) } catch { throw .joints(error) }
        var result=port.relativeDrift
        var angular=try ResponseArithmetic.sub(port.secondBody.prescribedDriftVelocity.angular,port.firstBody.prescribedDriftVelocity.angular,&work)
        for i in velocity.indices {
            try ResponseArithmetic.check(policy)
            let pa=try ResponseArithmetic.add(a[a.startIndex+i].linear,ResponseArithmetic.cross(a[a.startIndex+i].angular,port.firstOffset,&work),&work)
            let pb=try ResponseArithmetic.add(b[b.startIndex+i].linear,ResponseArithmetic.cross(b[b.startIndex+i].angular,port.secondOffset,&work),&work)
            result=try ResponseArithmetic.add(result,ResponseArithmetic.scale(ResponseArithmetic.sub(pb,pa,&work),velocity[i],&work),&work)
            angular=try ResponseArithmetic.add(angular,ResponseArithmetic.scale(ResponseArithmetic.sub(b[b.startIndex+i].angular,a[a.startIndex+i].angular,&work),velocity[i],&work),&work)
        }
        return (result,angular)
    }
}
