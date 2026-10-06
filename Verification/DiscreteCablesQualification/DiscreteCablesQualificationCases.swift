import SwiftMechanics

public struct DiscreteCablesQualificationCases: DiscreteCablesQualifying, Sendable {
    private typealias F = DiscreteCablesQualificationFixtures
    private typealias O = DiscreteCablesQualificationOracle
    private typealias E = DiscreteCablesQualificationError
    public init() {}
    public func run(_ selected: DiscreteCablesQualificationCase) throws(DiscreteCablesQualificationError) {
        switch selected {
        case .stretchAndUnilateral: try stretchAndUnilateral()
        case .independentDerivatives: try independentDerivatives()
        case .bendAndPrestress: try bendAndPrestress()
        case .rigidCovariance: try rigidCovariance()
        case .massAndDrag: try massAndDrag()
        case .gravityAndSupport: try gravityAndSupport()
        case .dragAndTransactionalRollback: try dragAndTransactionalRollback()
        case .resourceAndIdentityRefusals: try resourceAndIdentityRefusals()
        case .cancellation: try cancellation()
        }
    }
    private func stretchAndUnilateral() throws(E) {
        let rest = [0.0,0,0,1,0,0]
        for unilateral in [false,true] {
            let chain = try F.chain(rest,secondMoment: 0,formulation: unilateral ? .tensionOnlyCable : .bilateralSpringChain)
            for l in [1.2,0.8] {
                let s = try F.state(chain,[0,0,0,l,0,0]), a = try F.assemble(chain,s)
                let active = !unilateral || l > 1
                let force = active ? 60*(l-1) : 0
                try F.near(a.storedEnergy,active ? 30*(l-1)*(l-1) : 0,"selected segment energy")
                try F.near(F.flat(a.physicalInternalForce),[force,0,0,-force,0,0],"physical stretch force sign")
                let k = try F.matrix(a), diagonal = active ? [60,60*(l-1)/l,60*(l-1)/l] : [0,0,0]
                for i in 0..<6 { for j in 0..<6 {
                    let expected = i%3 == j%3 ? diagonal[i%3]*(i/3 == j/3 ? 1 : -1) : 0
                    try F.near(k[i*6+j],expected,"all stretch tangent entries")
                } }
                try F.near(a.lumpedNodeMass,[1,1],"two-node reference masses")
                try F.require(a.cable.source == chain.source && a.cable.revision == 11 && a.cable.material.source == chain.material.source,"original source/revision authority retained")
            }
        }
        let chain = try F.chain(rest,secondMoment: 0,formulation: .tensionOnlyCable), s = try F.state(chain)
        let a = try F.assemble(chain,s,order: .forceOnly)
        try F.near(a.storedEnergy,0,"unilateral exact rest energy")
        try F.near(F.flat(a.physicalInternalForce),[0,0,0,0,0,0],"unilateral exact rest force")
        try F.require(a.stiffnessBlocks == nil,"force-only tangent explicitly absent")
        let policy = try F.policy(); var work = try F.work(); let service: any CableAssembling = ObjectiveCableAssembler()
        try F.expect(.nonsmoothStretch(index: 0),"exact unilateral tangent refusal") { () throws(CableError) in
            _ = try service.assemble(chain,state: s,derivativeOrder: .forceAndTangent,policy: policy,work: &work)
        }
        let diagonal = try F.chain([0,0,0,0.7,-0.2,0.9],secondMoment: 0,formulation: .tensionOnlyCable)
        let diagonalState = try F.state(diagonal); var diagonalWork = try F.work()
        try F.expect(.nonsmoothStretch(index: 0),"non-axis exact unilateral tangent refusal") { () throws(CableError) in
            _ = try service.assemble(diagonal,state: diagonalState,derivativeOrder: .forceAndTangent,policy: policy,work: &diagonalWork)
        }
    }
    private func independentDerivatives() throws(E) {
        let rest = [0.0,0,0,1,0,0,2,0,0], x = [0.2,-0.1,0.3,1.3,0.2,-0.1,1.7,1.1,0.4]
        for (bend,unilateral) in [(0.0,false),(3.0,false),(3.0,true)] {
            let chain = try F.chain(rest,secondMoment: bend/120,formulation: unilateral ? .tensionOnlyCable : .bilateralSpringChain)
            let a = try F.assemble(chain,F.state(chain,x)), force = F.flat(a.physicalInternalForce), k = try F.matrix(a)
            try F.near(a.storedEnergy,O.energy(x,rest: rest,bend: bend,unilateral: unilateral),"independent original scalar energy")
            try F.near(force,O.force(x,rest: rest,bend: bend,unilateral: unilateral),"independent analytic physical force")
            for column in x.indices {
                var plus = x, minus = x; plus[column] += 1e-6; minus[column] -= 1e-6
                let gradient = (O.energy(plus,rest: rest,bend: bend,unilateral: unilateral)-O.energy(minus,rest: rest,bend: bend,unilateral: unilateral))/2e-6
                try F.near(force[column],-gradient,"independent energy-gradient coordinate "+String(column),absolute: 2e-7,relative: 2e-7)
                plus = x; minus = x; plus[column] += 1e-5; minus[column] -= 1e-5
                let fp = O.force(plus,rest: rest,bend: bend,unilateral: unilateral), fm = O.force(minus,rest: rest,bend: bend,unilateral: unilateral)
                for row in x.indices {
                    let expected = -(fp[row]-fm[row])/2e-5
                    try F.near(k[row*x.count+column],expected,"independent full tangent "+String(row)+","+String(column),absolute: 2e-7,relative: 2e-7)
                    try F.near(k[row*x.count+column],k[column*x.count+row],"original Hessian symmetry")
                }
            }
            let direction = [0.1,-0.2,0.3,-0.15,0.25,-0.1,0.05,-0.12,0.18]
            var plus = x, minus = x
            for i in x.indices { plus[i] += 1e-6*direction[i]; minus[i] -= 1e-6*direction[i] }
            let power = O.dot(force,direction)
            try F.near(power,-(O.energy(plus,rest: rest,bend: bend,unilateral: unilateral)-O.energy(minus,rest: rest,bend: bend,unilateral: unilateral))/2e-6,"physical virtual power",absolute: 2e-7,relative: 2e-7)
        }
    }
    private func bendAndPrestress() throws(E) {
        let rest = [0.0,0,0,1,0,0,2,0,0], chain = try F.chain(rest)
        let straight = try F.assemble(chain,F.state(chain))
        try F.near(straight.storedEnergy,0,"straight natural curvature")
        try F.near(F.flat(straight.physicalInternalForce),[Double](repeating: 0,count: 9),"straight force")
        let k = try F.matrix(straight)
        for axis in 0..<3 {
            var translation = [Double](repeating: 0,count: 9), rotation = translation
            let omega = (0..<3).map { $0 == axis ? 1.0 : 0 }
            for i in 0..<3 {
                translation[3*i+axis] = 1
                let value = O.cross(omega,[rest[3*i],rest[3*i+1],rest[3*i+2]])
                for j in 0..<3 { rotation[3*i+j] = value[j] }
            }
            try F.near(O.action(k,translation),[Double](repeating: 0,count: 9),"straight translation nullspace")
            try F.near(O.action(k,rotation),[Double](repeating: 0,count: 9),"stress-free rigid rotation nullspace")
        }
        let antiparallel = [0.0,0,0,1,0,0,0,0,0]
        let anti = try F.assemble(chain,F.state(chain,antiparallel))
        try F.near(anti.storedEnergy,6,"antiparallel smooth cosine energy")
        try F.near(F.flat(anti.physicalInternalForce),[Double](repeating: 0,count: 9),"antiparallel stationary gradient")
        try F.require(try F.matrix(anti).allSatisfy(\.isFinite),"antiparallel finite full tangent")
        let curved = [0.0,0,0,1,0,0,1,1,0], reference = try F.chain(curved)
        let prestressed = try F.assemble(reference,F.state(reference))
        try F.near(prestressed.storedEnergy,3,"curved reference explicitly prestressed")
        try F.near(F.flat(prestressed.physicalInternalForce),[0,-3,0,-3,3,0,3,0,0],"independent curved-reference physical bending force")
        let zeroBend = try F.chain(curved,secondMoment: 0), noBend = try F.assemble(zeroBend,F.state(zeroBend))
        try F.near(noBend.storedEnergy,0,"zero second-moment bend disabled")
        try F.near(F.flat(noBend.physicalInternalForce),[Double](repeating: 0,count: 9),"zero-bend reference force")
    }
    private func rigidCovariance() throws(E) {
        let rest = [0.0,0,0,1,0,0,2,0,0], x = [0.2,-0.1,0.3,1.3,0.2,-0.1,1.7,1.1,0.4]
        let chain = try F.chain(rest), a = try F.assemble(chain,F.state(chain,x))
        let rotatedChain = try F.chain(O.rotate(rest,translate: true)), rotatedState = try F.state(rotatedChain,O.rotate(x,translate: true))
        let b = try F.assemble(rotatedChain,rotatedState), force = F.flat(a.physicalInternalForce)
        try F.near(b.storedEnergy,a.storedEnergy,"finite rigid energy covariance")
        try F.near(F.flat(b.physicalInternalForce),O.rotate(force),"finite rigid physical force covariance")
        let k = try F.matrix(a), rotatedK = try F.matrix(b), permutation = [1,2,0], sign = [-1.0,1,-1]
        for i in 0..<9 { for j in 0..<9 {
            let sourceRow = 3*(i/3)+permutation[i%3], sourceColumn = 3*(j/3)+permutation[j%3]
            try F.near(rotatedK[i*9+j],sign[i%3]*sign[j%3]*k[sourceRow*9+sourceColumn],"all rigid tangent covariance entries")
        } }
        var resultant = [0.0,0,0], torque = resultant
        for i in 0..<3 {
            let f = [force[3*i],force[3*i+1],force[3*i+2]]
            let moment = O.cross([x[3*i],x[3*i+1],x[3*i+2]],f)
            for axis in 0..<3 { resultant[axis] += f[axis]; torque[axis] += moment[axis] }
        }
        try F.near(resultant,[0,0,0],"physical internal force balance")
        try F.near(torque,[0,0,0],"physical internal torque balance")
        for axis in 0..<3 {
            var translation = [Double](repeating: 0,count: 9), rotation = translation, covariant = translation
            let omega = (0..<3).map { $0 == axis ? 1.0 : 0 }
            for i in 0..<3 {
                translation[3*i+axis] = 1
                let q = O.cross(omega,[x[3*i],x[3*i+1],x[3*i+2]])
                let rf = O.cross(omega,[force[3*i],force[3*i+1],force[3*i+2]])
                for j in 0..<3 { rotation[3*i+j] = q[j]; covariant[3*i+j] = -rf[j] }
            }
            try F.near(O.action(k,translation),[Double](repeating: 0,count: 9),"prestress translation nullspace")
            try F.near(O.action(k,rotation),covariant,"prestress differentiated force covariance")
        }
    }
    private func massAndDrag() throws(E) {
        let chain = try F.chain([0,0,0,1,0,0,3,0,0],secondMoment: 0,damping: 0.5)
        let s = try F.state(chain,velocity: [1,2,0,-1,0,2,0,-2,1]), a = try F.assemble(chain,s)
        try F.near(a.lumpedNodeMass,[1,3,2],"reference segment half-mass assembly")
        try F.near(a.totalReferenceMass,6,"positive total reference mass")
        try F.near(a.dampingDiagonal,[0.5,1.5,1],"stationary mass drag diagonal")
        try F.near(F.flat(a.physicalDampingForce),[-0.5,-1,0,1.5,0,-3,0,2,-1],"physical drag sign and mass")
        try F.near(a.dissipatedPower,15,"independent nonnegative drag power")
        try F.near(O.dot(F.flat(a.physicalDampingForce),F.flat(s.velocities)),-15,"original drag physical power")
        let deformed = try F.assemble(chain,F.state(chain,[0,0,0,1.2,0,0,3.3,0,0]))
        try F.near(deformed.lumpedNodeMass,a.lumpedNodeMass,"mass remains reference based under motion")
    }
    private func gravityAndSupport() throws(E) {
        let rest = [2.0,3,4,3,3,4], chain = try F.chain(rest,secondMoment: 0)
        let s = try F.state(chain,velocity: [0,1,0,0,1,0]), loads = try F.loads(chain,gravity: [0,-2,0])
        let policy = try F.policy(); var work = try F.work(); let service: any CableEvolving = BoundedCableEvolution()
        let (final,evidence) = try F.accepted(service.evolve(chain,state: s,loads: loads,duration: 0.01,policy: policy,work: &work),"gravity translation")
        try F.near(F.flat(final.velocities),[0,0.98,0,0,0.98,0],"gravity velocities")
        try F.near(F.flat(final.positions),[2,3.0098,4,3,3.0098,4],"symplectic gravity positions")
        try F.near(evidence.initialMechanicalEnergy,1,"initial independent kinetic energy")
        try F.near(evidence.finalMechanicalEnergy,0.9604,"final independent kinetic energy")
        try F.near(evidence.externalWork,-0.0392,"gravity actual-displacement work")
        try F.near(evidence.originalEnergyResidual,-0.0004,"original gravity energy residual")
        try F.require(evidence.acceptedSubsteps == 1 && evidence.attempts == 1 && evidence.numericalWork == work,"original gravity work/attempt publication")
        let p0 = O.momentum(rest,F.flat(s.velocities),mass: [1,1],angular: false)
        let p1 = O.momentum(F.flat(final.positions),F.flat(final.velocities),mass: [1,1],angular: false)
        try F.near(zip(p1,p0).map { $0.0-$0.1 },[0,-0.04,0],"gravity linear impulse")
        let l0 = O.momentum(rest,F.flat(s.velocities),mass: [1,1],angular: true)
        let l1 = O.momentum(F.flat(final.positions),F.flat(final.velocities),mass: [1,1],angular: true)
        try F.near(zip(l1,l0).map { $0.0-$0.1 },[0.16,0,-0.1],"gravity angular impulse at translated origin")
        let forceLoads = try F.loads(chain,forces: [2,0,0,2,0,0]); var forceWork = try F.work()
        let (forced,forcedEvidence) = try F.accepted(service.evolve(chain,state: try F.state(chain),loads: forceLoads,duration: 0.01,policy: policy,work: &forceWork),"held force")
        try F.near(F.flat(forced.velocities),[0.02,0,0,0.02,0,0],"held force changes real motion")
        try F.near(forcedEvidence.externalWork,0.0008,"held force actual work")
        let stretched = try F.state(chain,[2,3,4,3.2,3,4]), supportLoads = try F.loads(chain,fixed: [true,false])
        let supportPolicy = try F.policy(energy: 0.0001); var supportWork = try F.work()
        let (supported,supportEvidence) = try F.accepted(service.evolve(chain,state: stretched,loads: supportLoads,duration: 0.001,policy: supportPolicy,work: &supportWork),"stationary support")
        try F.near(F.flat(supported.velocities),[0,0,0,-0.012,0,0],"supported free-node velocity")
        try F.near(F.flat(supported.positions),[2,3,4,3.199988,3,4],"supported original fixed position")
        try F.near(F.flat(supportEvidence.accumulatedSupportImpulse),[-0.012,0,0,0,0,0],"physical support impulse")
        try F.near(supportEvidence.finalMechanicalEnergy,30*0.199988*0.199988+0.5*0.012*0.012,"supported original potential plus kinetic")
        try F.near(supportEvidence.externalWork,0,"stationary support performs no work")
        try F.near(O.momentum(F.flat(supported.positions),F.flat(supported.velocities),mass: [1,1],angular: true),[0,-0.048,0.036],"supported angular impulse at translated origin")
    }
    private func dragAndTransactionalRollback() throws(E) {
        let chain = try F.chain([0,0,0,1,0,0],secondMoment: 0,damping: 2)
        let s = try F.state(chain,velocity: [0,1,0,0,1,0]), loads = try F.loads(chain), policy = try F.policy()
        let service: any CableEvolving = BoundedCableEvolution(); var work = try F.work()
        let (final,evidence) = try F.accepted(service.evolve(chain,state: s,loads: loads,duration: 0.01,policy: policy,work: &work),"uniform drag")
        try F.near(F.flat(final.velocities),[0,0.98,0,0,0.98,0],"explicit drag velocity")
        try F.near(F.flat(final.positions),[0,0.0098,0,1,0.0098,0],"explicit drag drift")
        try F.near(evidence.dampingWorkLoss,0.0392,"actual-displacement drag work loss")
        try F.near(evidence.externalWork,0,"drag not conflated with prescribed work")
        try F.near(evidence.originalEnergyResidual,-0.0004,"original drag energy residual")
        var rejectedWork = try F.work()
        do throws(NumericalError) { try rejectedWork.chargeOperations(17) } catch { throw .numerical(error) }
        let result = service.evolve(chain,state: s,loads: loads,duration: 0.1,policy: policy,work: &rejectedWork)
        let retained = try F.rejected(result,original: s,cause: .acceptanceFailed,"late original global energy refusal")
        try F.require(retained == rejectedWork && retained.iterations == 11 && retained.operations > 17,"all failed and locally accepted attempts retained")
        var expectedFinal = 1.0
        for _ in 0..<8 { expectedFinal *= 0.975*0.975 }
        var expectedLoss = 0.0, velocitySquared = 1.0
        for _ in 0..<8 { expectedLoss += 0.04875*velocitySquared; velocitySquared *= 0.975*0.975 }
        try F.require(abs(expectedFinal-1+expectedLoss) > 0.001,"independent accumulated residual violates unchanged final gate")
        let oneAttempt = try F.policy(attempts: 1); var attemptWork = try F.work()
        let attemptResult = service.evolve(chain,state: s,loads: loads,duration: 0.1,policy: oneAttempt,work: &attemptWork)
        _ = try F.rejected(attemptResult,original: s,cause: .attemptLimit,"bounded retry refusal")
        try F.require(attemptWork.iterations == 1 && attemptWork.operations > 0,"failed trial charged once")
    }
    private func resourceAndIdentityRefusals() throws(E) {
        let chain = try F.chain([0,0,0,1,0,0],secondMoment: 0), state = try F.state(chain), policy = try F.policy()
        let assembler: any CableAssembling = ObjectiveCableAssembler(), evolver: any CableEvolving = BoundedCableEvolution()
        for (storage,operations,cause) in [(0,10_000_000,CableError.numerical(.resourceLimit(resource: .scalarStorage,limit: 0))),
                                         (20_000,0,CableError.numerical(.resourceLimit(resource: .arithmeticOperations,limit: 0)))] {
            var work = try F.work(storage: storage,operations: operations)
            try F.expect(cause,"original assembly work refusal") { () throws(CableError) in
                _ = try assembler.assemble(chain,state: state,derivativeOrder: .forceAndTangent,policy: policy,work: &work)
            }
            if storage == 0 { try F.require(work.operations > 0 && work.peakScalarStorage == 0,"metadata charged before storage refusal") }
        }
        let loads = try F.loads(chain); var iterationWork = try F.work(iterations: 0)
        _ = try F.rejected(evolver.evolve(chain,state: state,loads: loads,duration: 0.01,policy: policy,work: &iterationWork),original: state,
            cause: .numerical(.resourceLimit(resource: .iterations,limit: 0)),"original iteration refusal")
        try F.require(iterationWork.iterations == 0 && iterationWork.operations > 0,"admission work retained on iteration refusal")
        let wrongFrame = try F.model { () throws(ModelError) in try EntityID(kind: .frame,key: "wrong-cable-frame") }
        let changed = [try F.state(chain,frame: wrongFrame),try F.state(chain,revision: 12),try F.state(chain,identifiers: [2,1])]
        for s in changed {
            var work = try F.work()
            try F.expect(.layoutMismatch,"frame revision/order refusal") { () throws(CableError) in
                _ = try assembler.assemble(chain,state: s,derivativeOrder: .forceOnly,policy: policy,work: &work)
            }
        }
        let duplicate = try F.chain(identifiers: [1,1,3]), duplicateState = try F.state(duplicate); var duplicateWork = try F.work()
        try F.expect(.duplicateNode,"duplicate identified node") { () throws(CableError) in
            _ = try assembler.assemble(duplicate,state: duplicateState,derivativeOrder: .forceOnly,policy: policy,work: &duplicateWork)
        }
        let collapsedState = try F.state(chain,[0,0,0,0,0,0]); var collapseWork = try F.work()
        try F.expect(.degenerateSegment(index: 0),"collapsed current geometry") { () throws(CableError) in
            _ = try assembler.assemble(chain,state: collapsedState,derivativeOrder: .forceOnly,policy: policy,work: &collapseWork)
        }
        let collapsedRest = try F.chain([0,0,0,0,0,0],secondMoment: 0), collapsedReferenceState = try F.state(collapsedRest); var referenceWork = try F.work()
        try F.expect(.degenerateSegment(index: 0),"collapsed reference geometry") { () throws(CableError) in
            _ = try assembler.assemble(collapsedRest,state: collapsedReferenceState,derivativeOrder: .forceOnly,policy: policy,work: &referenceWork)
        }
        let restricted = try F.chain([0,0,0,1,0,0],secondMoment: 0,strain: 0.01), strained = try F.state(restricted,[0,0,0,1.2,0,0]); var strainWork = try F.work()
        try F.expect(.outsideAxialDomain(index: 0),"original axial domain") { () throws(CableError) in
            _ = try assembler.assemble(restricted,state: strained,derivativeOrder: .forceOnly,policy: policy,work: &strainWork)
        }
        try F.expect(.unsupportedTwist,"director-free torsion refusal") { () throws(CableError) in
            _ = try DiscreteCable(frame: chain.frame,revision: chain.revision,source: chain.source,nodes: chain.nodes,material: chain.material,formulation: .torsionalRod)
        }
        let smallMetadata = try F.policy(metadata: 1); var metadataWork = try F.work()
        try F.expect(.capacityExceeded,"metadata bounded before equality") { () throws(CableError) in
            _ = try assembler.assemble(chain,state: state,derivativeOrder: .forceOnly,policy: smallMetadata,work: &metadataWork)
        }
        try F.require(metadataWork.operations == 1,"bounded metadata prefix retains original work")
        let three = try F.chain(), threeState = try F.state(three), nodePolicy = try F.policy(nodes: 2); var nodeWork = try F.work()
        try F.expect(.capacityExceeded,"node capacity") { () throws(CableError) in
            _ = try assembler.assemble(three,state: threeState,derivativeOrder: .forceOnly,policy: nodePolicy,work: &nodeWork)
        }
        var tinyWork = try F.work()
        _ = try F.rejected(evolver.evolve(chain,state: state,loads: loads,duration: 1e-9,policy: policy,work: &tinyWork),original: state,cause: .minimumSubstep,"duration floor")
        let movingFixed = try F.state(chain,velocity: [1,0,0,0,0,0]), fixedLoads = try F.loads(chain,fixed: [true,false]); var fixedWork = try F.work()
        _ = try F.rejected(evolver.evolve(chain,state: movingFixed,loads: fixedLoads,duration: 0.01,policy: policy,work: &fixedWork),original: movingFixed,cause: .invalidInput,"stationary support admission")
    }
    private func cancellation() throws(E) {
        let chain = try F.chain(), state = try F.state(chain), policy = try F.policy(cancelled: { true }), loads = try F.loads(chain)
        var work = try F.work(); do throws(NumericalError) { try work.chargeOperations(17) } catch { throw .numerical(error) }
        let before = work, assembler: any CableAssembling = ObjectiveCableAssembler(), evolver: any CableEvolving = BoundedCableEvolution()
        try F.expect(.cancelled,"public assembly cancellation") { () throws(CableError) in
            _ = try assembler.assemble(chain,state: state,derivativeOrder: .forceAndTangent,policy: policy,work: &work)
        }
        _ = try F.rejected(evolver.evolve(chain,state: state,loads: loads,duration: 0.01,policy: policy,work: &work),original: state,cause: .cancelled,"public evolution cancellation")
        try F.require(work == before,"cancellation preserves prior charged work")
    }
    public func taskCancellationEntry() throws(DiscreteCablesQualificationError) -> @Sendable () throws(DiscreteCablesQualificationError) -> Void {
        let chain = try F.chain(), state = try F.state(chain), loads = try F.loads(chain), policy = try F.policy()
        return { () throws(DiscreteCablesQualificationError) in
            var work = try F.work(); let assembler: any CableAssembling = ObjectiveCableAssembler(), evolver: any CableEvolving = BoundedCableEvolution()
            try F.expect(.cancelled,"actual Task assembly cancellation") { () throws(CableError) in
                _ = try assembler.assemble(chain,state: state,derivativeOrder: .forceOnly,policy: policy,work: &work)
            }
            _ = try F.rejected(evolver.evolve(chain,state: state,loads: loads,duration: 0.01,policy: policy,work: &work),original: state,cause: .cancelled,"actual Task evolution cancellation")
            try F.require(work.operations == 0 && work.iterations == 0,"Task cancellation before new work")
        }
    }
}
