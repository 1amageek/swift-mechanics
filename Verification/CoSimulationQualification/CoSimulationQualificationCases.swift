import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct CoSimulationQualificationCases: CoSimulationQualifying, Sendable {
    public init() {}
    public func run(_ selected:CoSimulationQualificationCase) throws {
        switch selected {
        case .heldPhysical: try heldPhysical()
        case .pureDamper: try pureDamper()
        case .evidenceRollback: try evidenceRollback()
        case .secondRefusalRollback: try secondRefusalRollback()
        case .cumulativeCapacity: try cumulativeCapacity()
        case .admissionRefusals: try admissionRefusals()
        case .staleAndShutdown: try staleAndShutdown()
        case .reentry: try reentry()
        case .cancellationPoison: try cancellationPoison()
        }
    }
    public func taskCancellationEntry() throws -> @Sendable () throws -> Void {
        let active=try self.owner(configurations(),coupling:CoSimulationQualificationFixtures.coupling())
        let before=try active.snapshot()
        return {
            defer { _=active.shutdown() }
            let failure=try CoSimulationQualificationFixtures.failure("cancelled task admission") {
                _=try active.step(expectedTick:0,expectedTimeSeconds:0)
            }
            guard case .cancelled=failure.cause else { throw CoSimulationQualificationError.wrongFailure("Task cancellation") }
            try CoSimulationQualificationFixtures.unchanged(active.snapshot(),before,"Task leaves both original tuples")
            let status=active.status()
            try CoSimulationQualificationFixtures.demand(!status.busy && status.terminalFailure == nil &&
                status.completedOperationWork.attemptedMacros == 0 &&
                status.completedOperationWork.admittedNumericalOperations == before.work.admittedNumericalOperations,
                "Task cancellation before reservations")
        }
    }
    private func configurations(firstGate:CoSimulationQualificationGate?=nil,secondGate:CoSimulationQualificationGate?=nil,
                                secondEffort:Double=100) throws -> (CoSimulationParticipantConfiguration,CoSimulationParticipantConfiguration) {
        (try CoSimulationQualificationFixtures.configuration(identity:"cosim-first",mass:2,q:0,v:0.25,disturbance:0.5,gate:firstGate),
         try CoSimulationQualificationFixtures.configuration(identity:"cosim-second",mass:5,q:1,v:-0.125,disturbance:-0.25,effortLimit:secondEffort,gate:secondGate))
    }
    private func owner(_ configurations:(CoSimulationParticipantConfiguration,CoSimulationParticipantConfiguration),
                       coupling:CoSimulationCoupling,macros:UInt64=8) throws -> any CoSimulationOperating {
        try CoSimulationQualificationFixtures.make(first:configurations.0,second:configurations.1,coupling:coupling,
            budget:CoSimulationQualificationFixtures.budget(macros:macros))
    }
    private func heldPhysical() throws {
        let k=4.0,d=0.5,h=0.125,m1=2.0,m2=5.0,g1=0.5,g2 = -0.25
        let owner=try self.owner(configurations(),coupling:CoSimulationQualificationFixtures.coupling(stiffness:k,damping:d))
        defer { _=owner.shutdown() }
        let source=try owner.snapshot()
        // Independent constant-force mechanics; no coordinator evidence helper is consumed.
        let q1=source.first.accepted.checkpoint.physical.q[0],q2=source.second.accepted.checkpoint.physical.q[0]
        let v1=source.first.accepted.checkpoint.physical.v[0],v2=source.second.accepted.checkpoint.physical.v[0]
        let force=k*(q2-q1)+d*(v2-v1),a1=(force+g1)/m1,a2=(-force+g2)/m2
        let x1=q1+h*v1+0.5*a1*h*h,x2=q2+h*v2+0.5*a2*h*h,w1=v1+a1*h,w2=v2+a2*h
        let receipt=try owner.step(expectedTick:0,expectedTimeSeconds:0)
        let actual1=receipt.boundary.first.accepted.checkpoint.physical,actual2=receipt.boundary.second.accepted.checkpoint.physical
        try CoSimulationQualificationFixtures.close(receipt.firstHeldForceNewtons,force,"paired source force")
        try CoSimulationQualificationFixtures.close(receipt.secondStep.observation.controller.heldEffort,-force,"opposite held force")
        try CoSimulationQualificationFixtures.close(actual1.q[0],x1,"first physical q")
        try CoSimulationQualificationFixtures.close(actual2.q[0],x2,"second physical q")
        try CoSimulationQualificationFixtures.close(actual1.v[0],w1,"first physical v")
        try CoSimulationQualificationFixtures.close(actual2.v[0],w2,"second physical v")
        try CoSimulationQualificationFixtures.close(actual1.acceleration[0],a1,"first original acceleration")
        try CoSimulationQualificationFixtures.close(actual2.acceleration[0],a2,"second original acceleration")
        let delta1=x1-q1,delta2=x2-q2,interface=force*(delta1-delta2),external=g1*delta1+g2*delta2
        let kinetic=0.5*m1*(w1*w1-v1*v1)+0.5*m2*(w2*w2-v2*v2)
        let spring=0.5*k*((x2-x1)*(x2-x1)-(q2-q1)*(q2-q1))
        let r=v2-v1,a=a2-a1
        // Integrate d*(r+a*t)^2 explicitly, independent of endpoint Simpson form.
        let damping=d*(r*r*h+r*a*h*h+a*a*h*h*h/3)
        let p0=force*(v1-v2),p1=force*(w1-w2),integrated=h*p0+0.5*force*(a1-a2)*h*h
        try CoSimulationQualificationFixtures.close(receipt.exchangedWorkJoules,interface,"original interface work")
        try CoSimulationQualificationFixtures.close(receipt.fixedDisturbanceWorkJoules,external,"external work")
        try CoSimulationQualificationFixtures.close(kinetic,interface+external,"independent kinetic balance")
        try CoSimulationQualificationFixtures.close(receipt.firstStep.observation.controller.initialKineticEnergy,0.5*m1*v1*v1,"original initial K1")
        try CoSimulationQualificationFixtures.close(receipt.secondStep.observation.controller.endpointKineticEnergy,0.5*m2*w2*w2,"original endpoint K2")
        try CoSimulationQualificationFixtures.close(receipt.springEnergyChangeJoules,spring,"stored spring change")
        try CoSimulationQualificationFixtures.close(receipt.continuousDampingOracleJoules,damping,"continuous comparator")
        try CoSimulationQualificationFixtures.close(receipt.energyDefectJoules,interface+spring+damping,"unchanged explicit defect")
        try CoSimulationQualificationFixtures.close(receipt.startPowerWatts,p0,"start original power")
        try CoSimulationQualificationFixtures.close(receipt.endPowerWatts,p1,"end original power")
        try CoSimulationQualificationFixtures.close(receipt.meanPowerWatts,integrated/h,"integrated mean power")
        try CoSimulationQualificationFixtures.demand(receipt.boundary.tick == 1 && actual1.time == h && actual2.time == h,"equal clocks")
        try CoSimulationQualificationFixtures.demand(receipt.firstStep.integration.acceptedSteps == 1 && receipt.secondStep.integration.acceptedSteps == 1,"real RK4 endpoints")
        try CoSimulationQualificationFixtures.demand(receipt.boundary.work.recordedNumericalOperations > source.work.recordedNumericalOperations && receipt.boundary.work.recordedActuationWork > 0,"original charged work")
        try CoSimulationQualificationFixtures.unchanged(owner.snapshot(),receipt.boundary,"published original tuple")
    }
    private func pureDamper() throws {
        let first=try CoSimulationQualificationFixtures.configuration(identity:"damper-first",mass:2,q:0,v:0.5,disturbance:0)
        let second=try CoSimulationQualificationFixtures.configuration(identity:"damper-second",mass:5,q:1,v:-0.5,disturbance:0)
        let owner=try self.owner((first,second),coupling:CoSimulationQualificationFixtures.coupling(stiffness:0,damping:1))
        defer { _=owner.shutdown() }
        let receipt=try owner.step(expectedTick:0,expectedTimeSeconds:0)
        try CoSimulationQualificationFixtures.close(receipt.firstHeldForceNewtons,-1,"damper signed force")
        try CoSimulationQualificationFixtures.close(receipt.boundary.first.accepted.checkpoint.physical.v[0],0.4375,"damper first motion")
        try CoSimulationQualificationFixtures.close(receipt.boundary.second.accepted.checkpoint.physical.v[0],-0.475,"damper second motion")
        try CoSimulationQualificationFixtures.demand(receipt.exchangedWorkJoules < 0 && receipt.startPowerWatts < 0 && receipt.endPowerWatts < 0,"original damper passivity")
        try CoSimulationQualificationFixtures.demand(receipt.continuousDampingOracleJoules > 0 && receipt.energyDefectJoules != 0,"comparator is not invented exact held loss")
    }
    private func evidenceRollback() throws {
        let owner=try self.owner(configurations(),coupling:CoSimulationQualificationFixtures.coupling(absoluteEnergy:1e-10))
        defer { _=owner.shutdown() }
        let before=try owner.snapshot()
        var previous=before.work.admittedNumericalOperations
        for _ in 0..<2 {
            let failure=try CoSimulationQualificationFixtures.failure("strict original defect") { _=try owner.step(expectedTick:0,expectedTimeSeconds:0) }
            guard case .originalEvidenceRejected=failure.cause else { throw CoSimulationQualificationError.wrongFailure("strict defect") }
            try CoSimulationQualificationFixtures.demand(failure.firstPrefix?.restored == true && failure.secondPrefix?.restored == true,"both actual restarts")
            try CoSimulationQualificationFixtures.demand(failure.firstPrefix?.current == before.first.accepted && failure.secondPrefix?.current == before.second.accepted,"full original contributor/random restoration")
            try CoSimulationQualificationFixtures.demand(failure.firstPrefix?.lastKnown == before.first.accepted && failure.secondPrefix?.lastKnown == before.second.accepted,"known actual restored tuple")
            let after=try owner.snapshot()
            try CoSimulationQualificationFixtures.unchanged(after,before,"rejected macro publishes no motion")
            try CoSimulationQualificationFixtures.demand(after.work.admittedNumericalOperations > previous && owner.status().terminalFailure == nil,"recovery never resets work")
            previous=after.work.admittedNumericalOperations
        }
    }
    private func secondRefusalRollback() throws {
        let owner=try self.owner(configurations(secondEffort:1),coupling:CoSimulationQualificationFixtures.coupling())
        defer { _=owner.shutdown() }
        let before=try owner.snapshot()
        let failure=try CoSimulationQualificationFixtures.failure("second effort bound") { _=try owner.step(expectedTick:0,expectedTimeSeconds:0) }
        guard case .unsupportedDomain=failure.cause else { throw CoSimulationQualificationError.wrongFailure("second effort") }
        try CoSimulationQualificationFixtures.demand(failure.firstPrefix?.restored == true && failure.secondPrefix?.restored == true,"both restore after first commit")
        try CoSimulationQualificationFixtures.unchanged(owner.snapshot(),before,"second refusal complete tuple")
        try CoSimulationQualificationFixtures.demand(owner.status().terminalFailure == nil,"restored refusal not poisoned")
    }
    private func cumulativeCapacity() throws {
        let owner=try self.owner(configurations(),coupling:CoSimulationQualificationFixtures.coupling(),macros:1)
        defer { _=owner.shutdown() }
        let accepted=try owner.step(expectedTick:0,expectedTimeSeconds:0).boundary
        let failure=try CoSimulationQualificationFixtures.failure("cumulative macros") { _=try owner.step(expectedTick:1,expectedTimeSeconds:0.125) }
        guard case .capacity=failure.cause else { throw CoSimulationQualificationError.wrongFailure("macro budget") }
        let after=try owner.snapshot()
        try CoSimulationQualificationFixtures.unchanged(after,accepted,"capacity before mutation")
        try CoSimulationQualificationFixtures.demand(after.work.attemptedMacros == 1 && after.work.admittedNumericalOperations == accepted.work.admittedNumericalOperations,"failed budget preserves charged prefix")
    }
    private func admissionRefusals() throws {
        for exchange in [CoSimulationCoupling.Exchange.interpolated,.fixedPoint] {
            let failure=try CoSimulationQualificationFixtures.failure("exchange domain") { _=try CoSimulationQualificationFixtures.coupling(exchange:exchange) }
            guard case .unsupportedDomain=failure.cause else { throw CoSimulationQualificationError.wrongFailure("exchange") }
        }
        let delay=try CoSimulationQualificationFixtures.failure("delay") { _=try CoSimulationQualificationFixtures.coupling(delay:0.1) }
        guard case .unsupportedDomain=delay.cause else { throw CoSimulationQualificationError.wrongFailure("delay") }
        let configs=try configurations()
        let identity=try CoSimulationQualificationFixtures.failure("same owner identity") { _=try owner((configs.0,configs.0),coupling:CoSimulationQualificationFixtures.coupling()) }
        guard case .unsupportedDomain=identity.cause else { throw CoSimulationQualificationError.wrongFailure("owner identity") }
        let binding=configs.0.plant.port.binding
        let filtered=try ScalarServo(binding:binding,positionGain:4,velocityGain:2,integralGain:0,integralLimit:10,
            effortLimit:100,speedLimit:1000,positionDeadband:0,velocityDeadband:0,filterTimeConstant:0.1)
        let filter=try CoSimulationQualificationFixtures.failure("unadmitted force filter") {
            _=try CoSimulationParticipantConfiguration(identity:"filtered",maximumIdentityBytes:256,plant:configs.0.plant,
                controller:SampledController(servo:filtered,mode:.effort),clock:configs.0.clock,initialActuator:configs.0.initialActuator,
                seed:42,control:configs.0.control,observation:configs.0.observation,encoderBudget:configs.0.encoderBudget)
        }
        guard case .unsupportedDomain=filter.cause else { throw CoSimulationQualificationError.wrongFailure("filter domain") }
        let badClock=try CoSimulationParticipantConfiguration(identity:"clock-second",maximumIdentityBytes:256,plant:configs.1.plant,
            controller:configs.1.controller,clock:ControlClock(epochSeconds:0,periodSeconds:0.25,maximumTimeSeconds:1,maximumTicks:4),
            initialActuator:configs.1.initialActuator,seed:42,control:configs.1.control,observation:configs.1.observation,encoderBudget:configs.1.encoderBudget)
        let clock=try CoSimulationQualificationFixtures.failure("clock mismatch") { _=try owner((configs.0,badClock),coupling:CoSimulationQualificationFixtures.coupling()) }
        guard case .unsupportedDomain=clock.cause else { throw CoSimulationQualificationError.wrongFailure("clock") }
    }
    private func staleAndShutdown() throws {
        let owner=try self.owner(configurations(),coupling:CoSimulationQualificationFixtures.coupling())
        defer { _=owner.shutdown() }
        let before=try owner.snapshot()
        for (tick,time) in [(UInt64(1),0.0),(UInt64(0),0.125)] {
            let failure=try CoSimulationQualificationFixtures.failure("stale source") { _=try owner.step(expectedTick:tick,expectedTimeSeconds:time) }
            guard case .staleBoundary=failure.cause else { throw CoSimulationQualificationError.wrongFailure("source order") }
            try CoSimulationQualificationFixtures.unchanged(owner.snapshot(),before,"stale leaves tuple")
        }
        try CoSimulationQualificationFixtures.demand(owner.shutdown() == .closed && owner.shutdown() == .closed,"idempotent real shutdown")
        let closed=try CoSimulationQualificationFixtures.failure("closed owner") { _=try owner.snapshot() }
        guard case .closed=closed.cause else { throw CoSimulationQualificationError.wrongFailure("closed") }
    }
    private func reentry() throws {
        let gate=CoSimulationQualificationGate()
        let owner=try self.owner(configurations(firstGate:gate),coupling:CoSimulationQualificationFixtures.coupling())
        gate.install(owner);gate.arm(.reentry)
        defer { gate.clear();_=owner.shutdown() }
        _=try owner.step(expectedTick:0,expectedTimeSeconds:0)
        try CoSimulationQualificationFixtures.demand(gate.validReentryCount > 0,"actual original callback busy refusal")
        try CoSimulationQualificationFixtures.demand(!owner.status().busy && owner.status().terminalFailure == nil,"gate released after callback")
    }
    private func cancellationPoison() throws {
        let gate=CoSimulationQualificationGate()
        let owner=try self.owner(configurations(secondGate:gate),coupling:CoSimulationQualificationFixtures.coupling())
        defer { gate.clear();_=owner.shutdown() }
        let before=try owner.snapshot();gate.arm(.cancel)
        let failure=try CoSimulationQualificationFixtures.failure("second actual cancellation") { _=try owner.step(expectedTick:0,expectedTimeSeconds:0) }
        guard case .irrecoverablePrefix=failure.cause else { throw CoSimulationQualificationError.wrongFailure("cancelled restart") }
        try CoSimulationQualificationFixtures.demand(failure.firstPrefix?.restored == true && failure.secondPrefix?.restored == false,"both recovery attempts with persistent cancellation")
        try CoSimulationQualificationFixtures.demand(failure.firstPrefix?.current == before.first.accepted && failure.secondPrefix?.lastKnown != nil,"original recovery prefix evidence")
        try CoSimulationQualificationFixtures.demand(!failure.recoveryFailures.isEmpty && owner.status().terminalFailure != nil && !owner.status().busy,"poison publication")
        let poisoned=try CoSimulationQualificationFixtures.failure("poison remains") { _=try owner.snapshot() }
        guard case .poisoned=poisoned.cause else { throw CoSimulationQualificationError.wrongFailure("poison admission") }
    }
}
