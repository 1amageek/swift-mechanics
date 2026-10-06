import SwiftMechanics

public enum ArticulatedDynamicsQualificationCases {
    public static func require(_ condition: Bool, _ message: String) throws(ArticulatedDynamicsQualificationError) {
        guard condition else { throw .assertion(message) }
    }
    public static func close(_ actual: Double, _ expected: Double, _ message: String) throws(ArticulatedDynamicsQualificationError) {
        try require(actual.isFinite && expected.isFinite && abs(actual-expected)<=1e-9*max(1,abs(expected)),message)
    }
    private static func close(_ actual: [Double], _ expected: [Double], _ message: String) throws(ArticulatedDynamicsQualificationError) {
        try require(actual.count==expected.count,message+" shape")
        for i in expected.indices { try close(actual[i],expected[i],message+" coordinate") }
    }
    private static func close(_ actual: Vector3, _ expected: Vector3, _ message: String) throws(ArticulatedDynamicsQualificationError) {
        try close(actual.x,expected.x,message+" x");try close(actual.y,expected.y,message+" y");try close(actual.z,expected.z,message+" z")
    }
    private static func original(_ result: ArticulatedDynamicsResult, _ acceleration: [Double], kinetic: Double, rate: Double) throws {
        try close(result.acceleration,acceleration,"independent analytical ABA acceleration")
        try close(result.energy.kineticEnergy,kinetic,"independent analytical kinetic energy")
        try close(result.energy.kineticEnergyRate,rate,"independent analytical kinetic rate")
        try close(result.energy.requiredVirtualPower,rate,"original physical virtual power")
        try close(result.energy.requiredPrescribedPower,0,"fixed source has no prescribed power")
        try require(result.originalResidual.normalizedInfinityNorm<=result.originalResidual.threshold,"original Newton-Euler acceptance")
        try require(result.recursiveOperations>0 && result.work.operations>result.recursiveOperations && result.work.iterations>0,
            "actual recursion and independent acceptance consume original ledgers")
    }
    private static func expect(_ message: String, matching: (ArticulatedDynamicsFailure)->Bool,
                               operation: () throws(ArticulatedDynamicsFailure)->Void) throws {
        do throws(ArticulatedDynamicsFailure) { try operation() }
        catch { try require(matching(error) && !error.failedSupplierWorkUnavailable,message+" original typed failure/known work");return }
        throw ArticulatedDynamicsQualificationError.unexpectedSuccess(message)
    }
    public static func offsetPendulumGravityAndPower() throws {
        let input=try ArticulatedDynamicsQualificationFixtures.pendulum(gravity:true,damping:true)
        let service:any ArticulatedDynamicsSolving=ReferenceArticulatedDynamics()
        var work=try ArticulatedDynamicsQualificationFixtures.work(), loads=try ArticulatedDynamicsQualificationFixtures.loads()
        let result=try service.forward(input,driveForce:[0],policy:ArticulatedDynamicsQualificationFixtures.policy(1),loadWork:&loads,work:&work)
        try original(result,[-26.0/3],kinetic:6,rate:-52)
        try close(result.originalSystem.massMatrix,[3],"independent COM parallel-axis inertia")
        try close(result.originalSystem.inertialBias,[0],"centripetal wrench has zero hinge generalized torque")
        try close(result.energy.linearMomentum,Vector3(0,4,0),"independent COM linear momentum")
        try close(result.energy.angularMomentum,Vector3(0,0,6),"independent COM plus orbital angular momentum")
        try require(result.energy.potentialEnergy==0 && result.energy.dissipatedPower==12,"original gravity/passive energy metadata")
        try require(loads.consumed>0 && result.loadWork.consumed==loads.consumed,"recursive and oracle gravity retain separate load ledger")
        try require(input.snapshot.bodies[1].motion.acceleration.angular.z==99 && abs(result.acceleration[0]-99)>1,
            "supplied source acceleration cannot be substituted for recursive forward result")
    }
    public static func serialHingeBiasAndPower() throws {
        let input=try ArticulatedDynamicsQualificationFixtures.serialHinges(), service:any ArticulatedDynamicsSolving=ReferenceArticulatedDynamics()
        var work=try ArticulatedDynamicsQualificationFixtures.work(), loads=try ArticulatedDynamicsQualificationFixtures.loads()
        let result=try service.forward(input,driveForce:[-23,16],policy:ArticulatedDynamicsQualificationFixtures.policy(2),loadWork:&loads,work:&work)
        try original(result,[1,1],kinetic:30,rate:9)
        try close(result.originalSystem.massMatrix,[20,5,5,5],"independent two-link mass matrix")
        try close(result.originalSystem.inertialBias,[-48,6],"independent nonzero serial Coriolis terms")
        try close(result.originalResidual.originalGeneralizedInertialForce,[-23,16],"independent original generalized Newton-Euler force")
        try close(result.energy.linearMomentum,Vector3(-9,8,0),"independent two-link COM momentum")
        try close(result.energy.angularMomentum,Vector3(0,0,30),"independent two-link angular momentum")
    }
    public static func serialPrismaticCoupling() throws {
        let f=ArticulatedDynamicsQualificationFixtures.self
        let rm=try f.mass(1), am=try f.mass(2), bm=try f.mass(3)
        let root=try f.body("prism-root",rm), a=try f.body("prism-a",am), b=try f.body("prism-b",bm)
        let j1=try f.joint("prism-one",parent:root,child:a,specification:.prismatic(axis:.unitX))
        let j2=try f.joint("prism-two",parent:a,child:b,specification:.prismatic(axis:.unitX))
        let input=try f.input(bodies:[root,a,b],joints:[j1,j2],masses:[rm,am,bm],q:[0.3,0.4],v:[1,2],suppliedAcceleration:[55,88])
        var work=try f.work(), loads=try f.loads()
        let service:any ArticulatedDynamicsSolving=ReferenceArticulatedDynamics()
        let result=try service.forward(input,driveForce:[13,9],policy:f.policy(2),loadWork:&loads,work:&work)
        try original(result,[2,1],kinetic:14.5,rate:31)
        try close(result.originalSystem.massMatrix,[5,3,3,3],"independent serial prism coupling")
        try close(result.energy.linearMomentum,Vector3(11,0,0),"independent serial prism momentum")
        try close(result.energy.angularMomentum,.zero,"collinear prism momentum has no orbital torque")
    }
    public static func branchedTreeWithFixedCarrier() throws {
        let f=ArticulatedDynamicsQualificationFixtures.self
        let rm=try f.mass(1), carrierMass=try f.mass(7), am=try f.mass(2,.unitX), bm=try f.mass(3)
        let root=try f.body("branch-root",rm), carrier=try f.body("branch-carrier",carrierMass)
        let a=try f.body("branch-a",am), b=try f.body("branch-b",bm)
        let fixed=try f.joint("branch-fixed",parent:root,child:carrier,specification:.fixed,
            anchor:RigidTransform(rotation:.identity,translation:Vector3(2,3,1)))
        let hinge=try f.joint("branch-hinge",parent:carrier,child:a,specification:.revolute(axis:.unitZ))
        let prism=try f.joint("branch-prism",parent:carrier,child:b,specification:.prismatic(axis:.unitY))
        let input=try f.input(bodies:[root,carrier,a,b],joints:[fixed,hinge,prism],masses:[rm,carrierMass,am,bm],q:[0,0],v:[2,-1])
        var work=try f.work(), loads=try f.loads()
        let result=try ReferenceArticulatedDynamics().forward(input,driveForce:[6,12],policy:f.policy(2),loadWork:&loads,work:&work)
        try original(result,[2,4],kinetic:7.5,rate:0)
        try close(result.originalSystem.massMatrix,[3,0,0,3],"independent branched mass blocks across fixed carrier")
        try close(result.energy.linearMomentum,Vector3(0,1,0),"independent branch COM momentum")
        try close(result.energy.angularMomentum,Vector3(-1,0,8),"fixed carrier offset preserves orbital angular momentum")
        try require(input.snapshot.tree.bodies.count==4 && input.snapshot.tree.layout.velocityCount==2,
            "original fixed intermediate body is retained without invented coordinate")
    }
    public static func rotatedScrewAndFramedWrench() throws {
        let f=ArticulatedDynamicsQualificationFixtures.self
        let rm=try f.mass(1), tensor=try Matrix3(4,1,0.5,1,5,0.7,0.5,0.7,6)
        let cm=try f.mass(2,Vector3(0.2,-0.3,0.4),tensor:tensor), root=try f.body("screw-root",rm), child=try f.body("screw-child",cm)
        let anchor=RigidTransform(rotation:try UnitQuaternion(axis:.unitY,angle:Double.pi/2),translation:try Vector3(1,2,-1))
        let joint=try f.joint("screw",parent:root,child:child,specification:.screw(axis:.unitZ,pitchMetersPerRadian:0.5),anchor:anchor)
        let base=try f.input(bodies:[root,child],joints:[joint],masses:[rm,cm],q:[0.7],v:[2],suppliedAcceleration:[-70])
        let bodyLoad=try BodyWrenchContribution(body:child.id,frame:child.frame,referencePoint:cm.centerOfMass,
            wrench:SpatialWrench(torque:Vector3(0,0,3),force:Vector3(0,0,2)),channel:.actuator)
        let pose=base.snapshot.bodies[1].motion.pose
        let worldLoad=try BodyWrenchContribution(body:child.id,frame:base.snapshot.tree.worldFrame,
            referencePoint:pose.translation.adding(pose.rotation.rotating(cm.centerOfMass)),
            wrench:SpatialWrench(torque:pose.rotation.rotating(Vector3(0,0,3)),force:pose.rotation.rotating(Vector3(0,0,2))),channel:.actuator)
        var work=try f.work(), loads=try f.loads()
        let policy=try f.policy(1,complete:false), service:any ArticulatedDynamicsSolving=ReferenceArticulatedDynamics()
        for load in [bodyLoad,worldLoad] {
            let input=try RigidDynamicsInput(snapshot:base.snapshot,velocity:base.velocity,inertias:base.inertias,gravity:nil,bodyWrenches:[load])
            let result=try service.forward(input,driveForce:[2.76],policy:policy,loadWork:&loads,work:&work)
            try original(result,[1],kinetic:13.52,rate:13.52)
            try close(result.originalSystem.massMatrix,[6.76],"independent screw COM plus pitch inertia")
            try close(result.originalSystem.forces.actuator,[4],"independent framed wrench generalized effort")
            let omega=try pose.rotation.rotating(Vector3(0,0,2)), offset=try pose.rotation.rotating(cm.centerOfMass)
            let momentum=try Vector3(1,0,0).adding(omega.cross(offset)).scaled(by:2)
            let spin=try pose.rotation.rotating(tensor.applying(to:Vector3(0,0,2)))
            let angular=try spin.adding(pose.translation.adding(offset).cross(momentum))
            try close(result.energy.linearMomentum,momentum,"independent noncommuting rotated COM momentum")
            try close(result.energy.angularMomentum,angular,"independent rotated tensor plus orbital angular momentum")
            try require(result.energy.potentialEnergy==nil && result.energy.dissipatedPower==nil,
                "unknown actuator energy metadata remains unavailable")
        }
    }
    public static func inverseMassAndPhysicalNormalization() throws {
        let f=ArticulatedDynamicsQualificationFixtures.self
        let known=try GeneralizedForceContribution(values:[100,-70],channel:.applied,potentialEnergy:0,dissipatedPower:0)
        let input=try f.serialHinges(generalized:[known]), service:any ArticulatedDynamicsSolving=ReferenceArticulatedDynamics()
        var work=try f.work(), loads=try f.loads()
        let result=try service.inverseMassProduct(input,rightHandSide:[25,10],policy:f.policy(2,scales:[0.2,3],energy:7,time:0.4),loadWork:&loads,work:&work)
        try original(result,[1,1],kinetic:30,rate:9)
        try close(result.originalResidual.originalGeneralizedInertialForce,[25,10],"mass-only query excludes original velocity bias from lhs")
        try close(result.originalSystem.inertialBias,[-48,6],"mass-only result retains actual original source bias")
        try close(result.originalSystem.forces.applied,[100,-70],"mass-only result retains original known load source")
        let direct=try service.forward(input,driveForce:[-123,86],policy:f.policy(2,scales:[4,0.1],energy:3,time:2),loadWork:&loads,work:&work)
        try original(direct,[1,1],kinetic:30,rate:9)
    }
    public static func typedRefusalsAndWorkPrefixes() throws {
        let f=ArticulatedDynamicsQualificationFixtures.self, input=try f.pendulum(), service:any ArticulatedDynamicsSolving=ReferenceArticulatedDynamics()
        let policy=try f.policy(1), capacityPolicy=try f.policy(1,bodies:1), zeroPolicy=try f.policy(0)
        var work=try f.work(), loads=try f.loads()
        try expect("capacity",matching:{if case .capacityExceeded=$0.cause{return true};return false}) { () throws(ArticulatedDynamicsFailure) in
            _=try service.forward(input,driveForce:[0],policy:capacityPolicy,loadWork:&loads,work:&work)
        }
        try expect("rhs shape",matching:{if case .invalidShape=$0.cause{return true};return false}) { () throws(ArticulatedDynamicsFailure) in
            _=try service.forward(input,driveForce:[],policy:policy,loadWork:&loads,work:&work)
        }
        let wrongVelocity=try RigidDynamicsInput(snapshot:input.snapshot,velocity:[3],inertias:input.inertias,gravity:nil)
        try expect("original velocity mismatch",matching:{if case .velocityMismatch=$0.cause{return true};return false}) { () throws(ArticulatedDynamicsFailure) in
            _=try service.forward(wrongVelocity,driveForce:[0],policy:policy,loadWork:&loads,work:&work)
        }
        let wrongInertia=try RigidDynamicsInput(snapshot:input.snapshot,velocity:input.velocity,inertias:[input.inertias[1],input.inertias[0]],gravity:nil)
        try expect("original inertia identity",matching:{if case .sourceMismatch=$0.cause{return true};return false}) { () throws(ArticulatedDynamicsFailure) in
            _=try service.forward(wrongInertia,driveForce:[0],policy:policy,loadWork:&loads,work:&work)
        }
        let nonuniform=try RigidDynamicsInput(snapshot:input.snapshot,velocity:input.velocity,inertias:input.inertias,
            gravity:AffineGravity(frame:input.snapshot.tree.worldFrame,accelerationAtOrigin:.zero,gradient:.identity))
        try expect("nonuniform gravity",matching:{if case .unsupportedDomain=$0.cause{return true};return false}) { () throws(ArticulatedDynamicsFailure) in
            _=try service.forward(nonuniform,driveForce:[0],policy:policy,loadWork:&loads,work:&work)
        }
        let reaction=try BodyWrenchContribution(body:input.snapshot.tree.bodies[1].id,frame:input.snapshot.tree.worldFrame,
            referencePoint:.zero,wrench:SpatialWrench(torque:.zero,force:.zero),channel:.contact)
        let contact=try RigidDynamicsInput(snapshot:input.snapshot,velocity:input.velocity,inertias:input.inertias,gravity:nil,bodyWrenches:[reaction])
        try expect("reaction domain",matching:{if case .unsupportedDomain=$0.cause{return true};return false}) { () throws(ArticulatedDynamicsFailure) in
            _=try service.forward(contact,driveForce:[0],policy:policy,loadWork:&loads,work:&work)
        }
        let unknownFrame=try f.id(.frame,"unrelated-load-frame")
        let foreign=try BodyWrenchContribution(body:input.snapshot.tree.bodies[1].id,frame:unknownFrame,
            referencePoint:.zero,wrench:SpatialWrench(torque:.zero,force:.zero),channel:.applied)
        let foreignInput=try RigidDynamicsInput(snapshot:input.snapshot,velocity:input.velocity,inertias:input.inertias,gravity:nil,bodyWrenches:[foreign])
        try expect("original load frame",matching:{if case .frameMismatch=$0.cause{return true};return false}) { () throws(ArticulatedDynamicsFailure) in
            _=try service.forward(foreignInput,driveForce:[0],policy:policy,loadWork:&loads,work:&work)
        }
        let root=input.snapshot.tree.bodies[0], child=input.snapshot.tree.bodies[1]
        let masses=input.inertias.map { $0.properties }
        let floating=try f.input(bodies:[root,child],joints:input.snapshot.tree.joints,masses:masses,
            q:[0,0,0,1,0,0,0,0],v:[0,0,0,0,0,0,0],rootBase:.spatialFloating)
        let floatingPolicy=try f.policy(7)
        try expect("floating source refusal",matching:{if case .unsupportedDomain=$0.cause{return true};return false}) { () throws(ArticulatedDynamicsFailure) in
            _=try service.forward(floating,driveForce:[0,0,0,0,0,0,0],policy:floatingPolicy,loadWork:&loads,work:&work)
        }
        let sphericalJoint=try f.joint("spherical-refusal",parent:root,child:child,specification:.spherical)
        let spherical=try f.input(bodies:[root,child],joints:[sphericalJoint],masses:masses,q:[1,0,0,0],v:[0,0,0])
        let sphericalPolicy=try f.policy(3)
        try expect("multi-axis joint refusal",matching:{if case .unsupportedDomain=$0.cause{return true};return false}) { () throws(ArticulatedDynamicsFailure) in
            _=try service.forward(spherical,driveForce:[0,0,0],policy:sphericalPolicy,loadWork:&loads,work:&work)
        }
        let pivotPolicy=try f.policy(1,pivot:4)
        try expect("scaled scalar pivot",matching:{if case .singularJoint(let joint,let value,let threshold)=$0.cause{return joint==input.snapshot.tree.joints[0].id && abs(value-3)<1e-9 && threshold==4};return false}) { () throws(ArticulatedDynamicsFailure) in
            _=try service.forward(input,driveForce:[0],policy:pivotPolicy,loadWork:&loads,work:&work)
        }
        var operations=try f.work(operations:2)
        try expect("arithmetic prefix",matching:{if case .numerical(.resourceLimit(resource:.arithmeticOperations,limit:2))=$0.cause{return true};return false}) { () throws(ArticulatedDynamicsFailure) in
            _=try service.forward(input,driveForce:[0],policy:policy,loadWork:&loads,work:&operations)
        }
        try require(operations.operations==2,"failed source preparation retains charged two-operation prefix")
        var storage=try f.work(scalars:483)
        try expect("storage admission",matching:{if case .numerical(.resourceLimit(resource:.scalarStorage,limit:483))=$0.cause{return true};return false}) { () throws(ArticulatedDynamicsFailure) in
            _=try service.forward(input,driveForce:[0],policy:policy,loadWork:&loads,work:&storage)
        }
        var iteration=try f.work(iterations:0)
        try expect("iteration prefix",matching:{if case .numerical(.resourceLimit(resource:.iterations,limit:0))=$0.cause{return true};return false}) { () throws(ArticulatedDynamicsFailure) in
            _=try service.forward(input,driveForce:[0],policy:policy,loadWork:&loads,work:&iteration)
        }
        try require(iteration.operations>0 && iteration.iterations==0,"failed reverse traversal retains preparation work")
        let gravityInput=try f.pendulum(gravity:true)
        var exhaustedLoads=try f.loads(limit:0)
        try expect("original load budget",matching:{if case .loads(.workExhausted)=$0.cause{return true};return false}) { () throws(ArticulatedDynamicsFailure) in
            _=try service.forward(gravityInput,driveForce:[0],policy:policy,loadWork:&exhaustedLoads,work:&work)
        }
        var cancelled=try f.work()
        let cancellation=try f.policy(1,cancelled:{true})
        try expect("caller cancellation",matching:{if case .cancelled=$0.cause{return true};return false}) { () throws(ArticulatedDynamicsFailure) in
            _=try service.forward(input,driveForce:[0],policy:cancellation,loadWork:&loads,work:&cancelled)
        }
        try require(cancelled.operations==0,"cancelled query returns no fabricated progress")
        let rootMass=try f.mass(1), zeroRoot=try f.body("zero-root",rootMass)
        let zero=try f.input(bodies:[zeroRoot],joints:[],masses:[rootMass],q:[],v:[])
        try expect("V0 refusal",matching:{if case .unsupportedDomain=$0.cause{return true};return false}) { () throws(ArticulatedDynamicsFailure) in
            _=try service.forward(zero,driveForce:[],policy:zeroPolicy,loadWork:&loads,work:&work)
        }
    }
}
