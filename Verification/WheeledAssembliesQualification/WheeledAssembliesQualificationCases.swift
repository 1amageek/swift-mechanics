import SwiftMechanics

public enum WheeledAssembliesQualificationCases {
    private typealias Fixture = WheeledAssembliesQualificationFixture
    private static func check(_ value: Bool, _ label: String) throws {
        guard value else {throw WheeledAssembliesQualificationError.assertion(label)}
    }
    private static func close(_ actual: Double, _ expected: Double, _ label: String) throws {
        try check(actual.isFinite && abs(actual-expected)<=1e-8*max(1,abs(expected)),label)
    }
    private static func vector(_ actual: Vector3, _ x: Double, _ y: Double, _ z: Double, _ label: String) throws {
        try close(actual.x,x,label+" X");try close(actual.y,y,label+" Y");try close(actual.z,z,label+" Z")
    }
    private static func acceleration(_ e: WheeledAssemblyEvaluation, _ f: Fixture, root: [Double] = [0,0,0,0,0,0],
                                     joints: [Double] = [0,0,0,0,0]) throws {
        var expected=root+[Double](repeating:0,count:5)
        for i in joints.indices {expected[f.velocities[i]]=joints[i]}
        try check(e.solution.acceleration.count==11,"actual acceleration shape")
        for i in expected.indices {try close(e.solution.acceleration[i],expected[i],"independent coordinate acceleration "+String(i))}
        try check(e.solution.originalPhysicalResidual.isAccepted,"original residual accepted")
        try close(e.instantaneousPowerResidual,0,"original instantaneous physical power")
    }
    private static func refuse(_ reason: WheeledAssemblyFailure.Refusal, _ operation: () throws(WheeledAssemblyFailure) -> Void) throws {
        do throws(WheeledAssemblyFailure) {try operation()}
        catch {
            guard case .refusal(let actual)=error, actual==reason else {throw WheeledAssembliesQualificationError.originalFailure(error)}
            return
        }
        throw WheeledAssembliesQualificationError.unexpectedSuccess("expected original assembly refusal")
    }
    public static func gravityAndOriginalMomentum() throws {
        let f=try Fixture(rootPosition:Vector3(0,0,3),rootVelocity:Vector3(2,0,1),gravityZ:-10)
        var w=try Fixture.work();let e=try f.assembly.query(state:f.state,driver:Fixture.driver(),road:f.road(),work:&w)
        try acceleration(e,f,root:[0,0,-10,0,0,0])
        try close(e.energy.kineticEnergy,40,"16kg translational kinetic energy")
        try close(e.storedEnergy,520,"gravity stored energy at z3")
        try close(e.energy.kineticEnergyRate,-160,"gravity physical work rate")
        try vector(e.energy.linearMomentum,32,0,16,"original total linear momentum")
        try vector(e.energy.angularMomentum,0,96,0,"original world-origin angular momentum")
        try vector(e.chassisInertialWrench.wrench.force,0,0,-100,"10kg chassis inertial force")
        try vector(e.externalForce,0,0,-160,"supplied gravity external force")
        try check(e.energy.potentialEnergy==nil,"unknown road potential remains unavailable")
    }
    public static func suppliedForceAndHeldEvolution() throws {
        let f=try Fixture(rootVelocity:Vector3(2,0,0));let road=try f.road(rear:Vector3(8,0,0),front:Vector3(8,0,0))
        var w=try Fixture.work();let e=try f.assembly.query(state:f.state,driver:Fixture.driver(),road:road,work:&w)
        try acceleration(e,f,root:[1,0,0,0,0,0]);try close(e.roadPower,32,"two supplied8N road force powers")
        try close(e.energy.kineticEnergyRate,32,"original supplied-force kinetic rate")
        try vector(e.chassisInertialWrench.wrench.force,10,0,0,"actual chassis force")
        let receipt=try f.assembly.step(state:f.state,driver:Fixture.driver(),road:road,dt:0.01,work:&w)
        try close(receipt.state.kinematic.state.q[0],0.02,"explicit start-rate root displacement")
        try close(receipt.state.kinematic.state.v[0],2.01,"actual acceleration root velocity increment")
        try close(receipt.estimatedRoadWork,0.3208,"held-force trapezoidal original work")
        try close(receipt.end.energy.kineticEnergy-receipt.start.energy.kineticEnergy,0.3208,"kinetic energy increment")
        try close(receipt.energyResidual,0,"original stored-work residual")
        try vector(receipt.linearMomentumResidual,0,0,0,"exact16N interval impulse")
        try vector(receipt.angularMomentumResidual,0,0,0,"zero external moment interval")
        try check(receipt.state.sequence==1 && receipt.state.steering.sequence==1,"single successful history issuance")
        try check(f.state.sequence==0 && f.state.kinematic.state.time==0,"immutable source retained")
        try close(receipt.originalSteeringSourceWork,0,"original servo source work retained")
        try close(receipt.steeringWorkQuadratureDifference,0,"zero servo quadrature difference")
    }
    public static func springReactionAndSuppliedNormals() throws {
        let f=try Fixture(suspension:[0.1,-0.1]);var w=try Fixture.work()
        let e=try f.assembly.query(state:f.state,driver:Fixture.driver(),road:f.road(),work:&w)
        let a=20.0/13.06
        try acceleration(e,f,root:[0,0,0,0,a,0],joints:[-10.0/3-a,10.0/3+a,-a,0,-a])
        try close(try e.rearSuspension.total(),-10,"original rear spring effort")
        try close(try e.frontSuspension.total(),10,"original front spring effort")
        try close(e.storedEnergy,1,"two independent half-k-squared potentials")
        try vector(e.chassisInertialWrench.wrench.torque,0,10*a,0,"chassis physical pitch torque")
        try vector(e.externalForce,0,0,0,"internal springs generate no external force")
        let rear=try e.snapshot.body(f.configuration.topology.rearWheel).motion
        let front=try e.snapshot.body(f.configuration.topology.frontWheel).motion
        try close(rear.acceleration.linear.z,-10.0/3,"rear group Newton acceleration")
        try close(front.acceleration.linear.z,10.0/3,"front group Newton acceleration")
        try close(rear.acceleration.angular.y,0,"unforced rear wheel absolute spin")
        try close(front.acceleration.angular.y,0,"unforced front wheel absolute spin")
        let n=try Fixture();var nw=try Fixture.work()
        let normal=try n.assembly.query(state:n.state,driver:Fixture.driver(),road:n.road(rear:Vector3(0,0,3),front:Vector3(0,0,6)),work:&nw)
        try acceleration(normal,n,joints:[1,2,0,0,0])
        try close(normal.suppliedRearNormalForce,3,"explicit rear normal remains supplied")
        try close(normal.suppliedFrontNormalForce,6,"explicit front normal remains supplied")
        try vector(normal.externalForce,0,0,9,"actual external supplied normal sum")
    }
    public static func dampingAndInternalMomentum() throws {
        let f=try Fixture(suspensionRates:[0.2,-0.1]);var w=try Fixture.work()
        let e=try f.assembly.query(state:f.state,driver:Fixture.driver(),road:f.road(),work:&w);let a=1.5/13
        try acceleration(e,f,root:[0,0,0.05,0,a,0],joints:[-1.0/3-0.05-a,0.5/3-0.05+a,-a,0,-a])
        try close(e.energy.kineticEnergy,0.075,"unsprung velocity kinetic energy")
        try close(e.suspensionLossPower,0.25,"5 times sum of squared suspension rates")
        try close(e.energy.kineticEnergyRate,-0.25,"internal damping physical power")
        try vector(e.energy.linearMomentum,0,0,0.3,"unsprung original total momentum")
        try vector(e.energy.angularMomentum,0,0.9,0,"separated groups world-origin momentum")
        try vector(e.chassisInertialWrench.wrench.force,0,0,0.5,"equal-opposite spring damper force on chassis")
        let rear=try e.snapshot.body(f.configuration.topology.rearWheel).motion.acceleration.linear
        let front=try e.snapshot.body(f.configuration.topology.frontWheel).motion.acceleration.linear
        try close(10*e.solution.acceleration[2]+3*rear.z+3*front.z,0,"internal linear momentum derivative")
    }
    public static func shaftAndChassisReaction() throws {
        let f=try Fixture(spins:[2,0]);var w=try Fixture.work()
        let e=try f.assembly.query(state:f.state,driver:Fixture.driver(throttle:0.5),road:f.road(),work:&w)
        try acceleration(e,f,root:[0,0,0,0,-1,0],joints:[1,-1,14,0,1])
        try close(e.actuation.driveline.efforts[f.velocities[2]],13,"original affine shaft effort")
        try close(e.actuation.driveline.efforts[f.velocities[4]],0,"declared rear-only splitter")
        try close(e.actuation.driveline.balanceResidual,0,"original affine power residual")
        try close(e.motorPower,26,"shaft13Nm times spin2")
        try close(e.energy.kineticEnergy,2,"rear rotor kinetic energy")
        try close(e.energy.kineticEnergyRate,26,"original motor kinetic rate")
        try vector(e.energy.angularMomentum,0,2,0,"original rotor momentum")
        try vector(e.chassisInertialWrench.wrench.torque,0,-10,0,"actual chassis motor reaction")
        let r=try e.snapshot.body(f.configuration.topology.rearWheel).motion.acceleration.angular.y
        let fspin=try e.snapshot.body(f.configuration.topology.frontWheel).motion.acceleration.angular.y
        try close(r,13,"rear absolute rotor acceleration")
        try close(fspin,0,"unforced front absolute rotor acceleration")
        try close(13*e.solution.acceleration[4]+r+fspin,0,"internal motor angular momentum derivative")
    }
    public static func steeringAndOppositeSpinBrakes() throws {
        let f=try Fixture();var w=try Fixture.work()
        let e=try f.assembly.query(state:f.state,driver:Fixture.driver(steering:0.1),road:f.road(),work:&w)
        try acceleration(e,f,root:[0,0,0,0,0,-2.0/19],joints:[0,0,0,21.0/19,0])
        try close(e.actuation.steering.appliedEffort,2,"original positional servo command")
        try check(!e.actuation.steering.clipped,"explicit fixture servo is unclipped")
        try vector(e.chassisInertialWrench.wrench.torque,0,0,-20.0/19,"actual chassis steering reaction")
        let b=try Fixture(spins:[2,-3]);var bw=try Fixture.work()
        let brake=try b.assembly.query(state:b.state,driver:Fixture.driver(rearBrake:0.5,frontBrake:0.25),road:b.road(),work:&bw)
        try acceleration(brake,b,root:[0,0,0,0,1.0/13,0],joints:[-1.0/13,1.0/13,-27.0/13,0,12.0/13])
        try close(brake.actuation.rearBrakeTorque,-2,"positive-spin brake opposite torque")
        try close(brake.actuation.frontBrakeTorque,1,"negative-spin brake opposite torque")
        try close(brake.brakeLossPower,7,"independent brake positive loss")
        try close(brake.energy.kineticEnergy,6.5,"two rotor energies")
        try close(brake.energy.kineticEnergyRate,-7,"brake mechanical power")
        try vector(brake.energy.angularMomentum,0,-1,0,"opposite-spin original angular momentum")
    }
    public static func refusalsAndFailedTrialOwnership() throws {
        let f=try Fixture();let idle=try Fixture.driver(),road=try f.road(),brake=try Fixture.driver(rearBrake:1)
        var w=try Fixture.work()
        try refuse(.brakeAtZeroSpeed) { () throws(WheeledAssemblyFailure) in _=try f.assembly.query(state:f.state,driver:brake,road:road,work:&w) }
        let stale=try f.road(time:0.1)
        try refuse(.staleState) { () throws(WheeledAssemblyFailure) in _=try f.assembly.query(state:f.state,driver:idle,road:stale,work:&w) }
        let foreign=try f.road(frame:Fixture.id(.frame,"foreign"))
        try refuse(.unsupportedRoadPort) { () throws(WheeledAssemblyFailure) in _=try f.assembly.query(state:f.state,driver:idle,road:foreign,work:&w) }
        var cap=try Fixture.work(steps:0)
        try refuse(.workExhausted) { () throws(WheeledAssemblyFailure) in _=try f.assembly.step(state:f.state,driver:idle,road:road,dt:0.01,work:&cap) }
        try check(cap.steps==0 && cap.numerical.operations>0,"failed step cap keeps charged prefix")
        var calls=try Fixture.work(calls:0)
        try refuse(.workExhausted) { () throws(WheeledAssemblyFailure) in _=try f.assembly.initialize(configuration:f.configuration,
            state:f.state.kinematic,steering:f.state.steering,work:&calls) }
        try check(calls.modelCalls==0 && calls.numerical.operations>0,"failed model-call cap preserves work")
        var cancelled=try Fixture.work(cancelled:true)
        try refuse(.cancelled) { () throws(WheeledAssemblyFailure) in _=try f.assembly.query(state:f.state,driver:idle,road:road,work:&cancelled) }
        try check(cancelled.numerical.operations==0,"callback cancel before work")
        let crossing=try Fixture(spins:[0.01,0]);var cw=try Fixture.work()
        let crossingRoad=try crossing.road()
        try refuse(.brakeSpinCrossing) { () throws(WheeledAssemblyFailure) in _=try crossing.assembly.step(state:crossing.state,driver:brake,
            road:crossingRoad,dt:0.1,work:&cw) }
        try check(cw.steps==1 && crossing.state.sequence==0 && crossing.state.kinematic.state.time==0,"rejected brake retains source and charged trial")
        let spring=try Fixture(suspension:[0.1,-0.1]);var sw=try Fixture.work();let sr=try spring.road()
        var rejectedEnergy=false
        do throws(WheeledAssemblyFailure) { _=try spring.assembly.step(state:spring.state,driver:idle,road:sr,dt:0.01,work:&sw) }
        catch {
            guard case .residual(kind:.energyResidual,value:let value,scale:_) = error,value>0 else {throw WheeledAssembliesQualificationError.originalFailure(error)}
            rejectedEnergy=true
        }
        try check(rejectedEnergy,"explicit spring energy defect must fail")
        try check(sw.steps==1 && spring.state.sequence==0 && spring.state.cumulativeAbsoluteEnergyDefect==0,"energy rejection cannot publish accepted history")
        var tw=try Fixture.work();let failed=Fixture.implementation(WheeledAssembliesQualificationUnavailableDynamics())
        var supplierFailed=false
        do throws(WheeledAssemblyFailure) { _=try failed.query(state:f.state,driver:idle,road:road,work:&tw) }
        catch {
            guard case .dynamics(.supplierLedgerReplaced)=error else {throw WheeledAssembliesQualificationError.originalFailure(error)}
            supplierFailed=true
        }
        try check(supplierFailed,"unavailable original supplier error must fail")
        try check(tw.terminal && tw.numerical.operations>0,"terminal supplier retains known prefix")
        try refuse(.terminalSupplierFailure) { () throws(WheeledAssemblyFailure) in _=try f.assembly.query(state:f.state,driver:idle,road:road,work:&tw) }
        try check(f.state.sequence==0 && f.state.kinematic.state.time==0,"all rejected queries leave immutable accepted source")
    }
}
