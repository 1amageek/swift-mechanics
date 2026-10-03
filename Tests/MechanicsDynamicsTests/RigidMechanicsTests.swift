import Testing
import MechanicsCore
import MechanicsModel
import MechanicsNumerics
import MechanicsJoints
import MechanicsLoads
import MechanicsDynamics
@Suite struct RigidMechanicsTests {
    @Test func rotatedAsymmetricFreeBodyEulerWithOffsetCOM() throws {
        var loadWork = try DynamicsFixtures.loadWork()
        let properties = try DynamicsFixtures.properties(mass:2,com:Vector3(0.5,0,0),inertia:Matrix3(2,0,0,0,3,0,0,0,4))
        let rotation = try UnitQuaternion(axis:.unitZ,angle:.pi/2), omega = try Vector3(1,2,3)
        let velocity = [1.0,2,3,1,2,3]
        let snapshot = try DynamicsFixtures.snapshot(bodies:[DynamicsFixtures.body("free",properties:properties)],joints:[],root:"free",base:.spatialFloating,
            q:[0.5,1,2,rotation.w,rotation.x,rotation.y,rotation.z],v:velocity,acceleration:[5,6,7,8,9,10])
        let input = try RigidDynamicsInput(snapshot:snapshot,velocity:velocity,inertias:[DynamicsFixtures.inertia("free",properties)],gravity:nil)
        var work = try DynamicsFixtures.work()
        let equations: any RigidEquationComputing = RigidEquationKernel(), solver: any RigidDynamicsSolving = DenseRigidDynamics()
        let system = try equations.assemble(input,admission:DynamicsFixtures.admission(),loadWork:&loadWork,work:&work)
        let result = try solver.forward(system,driveForce:[0,0,0,0,0,0],policy:DynamicsFixtures.policy(6),work:&work)
        let alphaBody = try Vector3(-3,2,-0.5), alphaWorld = try rotation.rotating(alphaBody), omegaWorld = try rotation.rotating(omega)
        let offset = try rotation.rotating(properties.centerOfMass)
        let originAcceleration = try alphaWorld.cross(offset).adding(omegaWorld.cross(omegaWorld.cross(offset))).scaled(by:-1)
        for i in 0..<3 { #expect(abs(result.acceleration[i] - [originAcceleration.x,originAcceleration.y,originAcceleration.z][i]) < 1e-9) }
        #expect(abs(result.acceleration[3]+3) < 1e-9 && abs(result.acceleration[4]-2) < 1e-9 && abs(result.acceleration[5]+0.5) < 1e-9)
        #expect(result.originalPhysicalResidual.isAccepted)
        let energy = try equations.energy(system,acceleration:result.acceleration,angularMomentumReference:.zero,requireComplete:true,work:&work)
        let comVelocity = try Vector3(1,2,3).adding(omegaWorld.cross(offset))
        let expectedKinetic = try properties.mass*comVelocity.dot(comVelocity)/2 + omega.dot(properties.inertiaAtCenter.applying(to:omega))/2
        #expect(abs(energy.kineticEnergy-expectedKinetic) < 1e-9)
        #expect(try energy.linearMomentum.subtracting(comVelocity.scaled(by:2)).magnitude() < 1e-9)
        #expect(abs(energy.kineticEnergyRate) < 1e-9)
        let inverse = try solver.inverse(system,acceleration:result.acceleration,policy:DynamicsFixtures.policy(6),work:&work)
        #expect(inverse.driveForce.allSatisfy({ abs($0) < 1e-9 }))
        #expect(snapshot.bodies[0].motion.acceleration.angular != .zero)
    }
    @Test func offsetCOMPendulumAnalyticEnergyAndPower() throws {
        var loadWork = try DynamicsFixtures.loadWork()
        let theta = 0.4, speed = 0.7, input = try DynamicsFixtures.pendulum()
        var work = try DynamicsFixtures.work()
        let equations: any RigidEquationComputing = RigidEquationKernel(), solver: any RigidDynamicsSolving = DenseRigidDynamics()
        let system = try equations.assemble(input,admission:DynamicsFixtures.admission(),loadWork:&loadWork,work:&work)
        #expect(abs(system.massMatrix[0]-6) < 1e-12 && abs(system.inertialBias[0]) < 1e-12)
        let rotation = try UnitQuaternion(axis:.unitZ,angle:theta), com = try rotation.rotating(.unitX)
        let gravity = -20*com.x
        #expect(abs(system.forces.gravity[0]-gravity) < 1e-12)
        let result = try solver.forward(system,driveForce:[0],policy:DynamicsFixtures.policy(1),work:&work)
        #expect(abs(result.acceleration[0]-gravity/6) < 1e-10)
        let energy = try equations.energy(system,acceleration:result.acceleration,angularMomentumReference:.zero,requireComplete:true,work:&work)
        #expect(abs(energy.kineticEnergy-3*speed*speed) < 1e-12)
        #expect(abs(energy.potentialEnergy! - 20*com.y) < 1e-12)
        #expect(abs(energy.kineticEnergyRate-gravity*speed) < 1e-9)
        #expect(abs(system.forces.actualPower-energy.kineticEnergyRate) < 1e-9)
        let inverse = try solver.inverse(system,acceleration:[0],policy:DynamicsFixtures.policy(1),work:&work)
        #expect(abs(inverse.driveForce[0]+gravity) < 1e-10)
        let massProduct = try solver.inverseMassProduct(system,rightHandSide:[12],policy:DynamicsFixtures.policy(1),work:&work)
        #expect(abs(massProduct.acceleration[0]-2) < 1e-10 && massProduct.originalPhysicalResidual.equation == .massOnly)
        let wrench = try equations.inertialWrench(system,body:DynamicsFixtures.id(.body,"pendulum"),acceleration:[1],referencePointWorld:.zero,work:&work)
        #expect(abs(wrench.wrench.torque.z-6) < 1e-10)
    }
    @Test func twoLinkIndependentMassCoriolisGravityAndMixed() throws {
        var loadWork = try DynamicsFixtures.loadWork()
        let input = try DynamicsFixtures.twoLink(acceleration:[99,-17]), q1 = 0.3, q2 = -0.6
        let r1 = try UnitQuaternion(axis:.unitZ,angle:q1).rotating(.unitX), r2 = try UnitQuaternion(axis:.unitZ,angle:q2).rotating(.unitX)
        let r12 = try UnitQuaternion(axis:.unitZ,angle:q1+q2).rotating(.unitX)
        let m11 = 1+2*0.7*0.7+0.9+3*(4+0.8*0.8+2*2*0.8*r2.x)
        let m12 = 0.9+3*(0.8*0.8+2*0.8*r2.x), m22 = 0.9+3*0.8*0.8
        let h = 3*2*0.8*r2.y, c1 = -h*(2*0.8*(-0.4)+0.16), c2 = h*0.64
        let g1 = -10*(2*0.7*r1.x+3*(2*r1.x+0.8*r12.x)), g2 = -10*3*0.8*r12.x
        var work = try DynamicsFixtures.work()
        let equations = RigidEquationKernel(), solver: any RigidDynamicsSolving = DenseRigidDynamics()
        let system = try equations.assemble(input,admission:DynamicsFixtures.admission(),loadWork:&loadWork,work:&work)
        #expect(abs(system.massMatrix[0]-m11) < 1e-10 && abs(system.massMatrix[1]-m12) < 1e-10 && abs(system.massMatrix[3]-m22) < 1e-10)
        #expect(system.massMatrix[1] == system.massMatrix[2])
        #expect(abs(system.inertialBias[0]-c1) < 1e-10 && abs(system.inertialBias[1]-c2) < 1e-10)
        #expect(abs(system.forces.gravity[0]-g1) < 1e-10 && abs(system.forces.gravity[1]-g2) < 1e-10)
        let expectedDrive = [m11*0.4-m12*0.6+c1-g1,m12*0.4-m22*0.6+c2-g2]
        let inverse = try solver.inverse(system,acceleration:[0.4,-0.6],policy:DynamicsFixtures.policy(2),work:&work)
        #expect(abs(inverse.driveForce[0]-expectedDrive[0]) < 1e-10 && abs(inverse.driveForce[1]-expectedDrive[1]) < 1e-10)
        let forward = try solver.forward(system,driveForce:expectedDrive,policy:DynamicsFixtures.policy(2,scales:[0.2,3],energy:5,time:0.7),work:&work)
        #expect(abs(forward.acceleration[0]-0.4) < 1e-9 && abs(forward.acceleration[1]+0.6) < 1e-9)
        let mixed = try solver.mixed(system,partition:[.prescribedAcceleration(0.4),.prescribedDriveForce(expectedDrive[1])],policy:DynamicsFixtures.policy(2),work:&work)
        #expect(mixed.acceleration[0] == 0.4 && abs(mixed.acceleration[1]+0.6) < 1e-9)
        #expect(abs(mixed.driveForce[0]-expectedDrive[0]) < 1e-9 && mixed.driveForce[1] == expectedDrive[1])
        let zeroInput = try DynamicsFixtures.twoLink(), zeroSystem = try equations.assemble(zeroInput,admission:DynamicsFixtures.admission(),loadWork:&loadWork,work:&work)
        #expect(zeroSystem.massMatrix == system.massMatrix)
        // The supplier obtains bias by subtracting J*a from actual acceleration; independence is numerical, not bitwise.
        for i in 0..<2 { #expect(abs(zeroSystem.inertialBias[i]-system.inertialBias[i]) < 1e-10) }
        let energy = try equations.energy(system,acceleration:[0.4,-0.6],angularMomentumReference:.zero,requireComplete:true,work:&work)
        #expect(abs(energy.kineticEnergy-(m11*0.64+2*m12*0.8*(-0.4)+m22*0.16)/2) < 1e-10)
        #expect(abs(energy.potentialEnergy! - 10*(2*0.7*r1.y+3*(2*r1.y+0.8*r12.y))) < 1e-10)
    }
    @Test func prescribedBiasAndFramedForceAccounting() throws {
        var loadWork = try DynamicsFixtures.loadWork()
        let load = try BodyWrenchContribution(body:DynamicsFixtures.id(.body,"pendulum"),frame:DynamicsFixtures.id(.frame,"pendulum-frame"),
            referencePoint:.zero,wrench:SpatialWrench(torque:.zero,force:Vector3(2,0,0)),channel:.applied)
        let input = try DynamicsFixtures.pendulum(prescribed:true,loads:[load]), theta = 0.4
        let com = try UnitQuaternion(axis:.unitZ,angle:theta).rotating(.unitX)
        var work = try DynamicsFixtures.work(); let equations = RigidEquationKernel()
        let system = try equations.assemble(input,admission:DynamicsFixtures.admission(),loadWork:&loadWork,work:&work)
        #expect(abs(system.inertialBias[0]+6*com.y) < 1e-10)
        #expect(abs(system.forces.applied[0]) < 1e-10)
        #expect(abs(system.forces.prescribedPower-8*com.x) < 1e-10)
        #expect(abs(system.forces.actualPower-system.forces.virtualPower-system.forces.prescribedPower) < 1e-10)
        let energy = try equations.energy(system,acceleration:[0],angularMomentumReference:.zero,requireComplete:false,work:&work)
        #expect(energy.potentialEnergy == nil && energy.dissipatedPower == nil)
        let driftExpected = 2*(3-0.7*0.7*com.x)*4
        #expect(abs(energy.requiredPrescribedPower-driftExpected) < 1e-10)
        #expect(abs(energy.kineticEnergyRate-energy.requiredVirtualPower-energy.requiredPrescribedPower) < 1e-10)
        #expect(abs(energy.requiredVirtualPower-system.inertialBias[0]*0.7) < 1e-10)
        #expect(throws:DynamicsError.energyUnavailable) { try equations.energy(system,acceleration:[0],angularMomentumReference:.zero,requireComplete:true,work:&work) }
        let shifted = try equations.energy(system,acceleration:[0],angularMomentumReference:.unitX,requireComplete:false,work:&work)
        #expect(try shifted.angularMomentum.subtracting(energy.angularMomentum.subtracting(Vector3.unitX.cross(energy.linearMomentum))).magnitude() < 1e-10)
    }
    @Test func admittedPassiveForceEnergyBalanceAndExplicitFieldTimeWork() throws {
        var loadWork = try DynamicsFixtures.loadWork(), work = try DynamicsFixtures.work()
        let base = try DynamicsFixtures.pendulum(), theta = 0.4, speed = 0.7
        let law = try PolynomialSpringDamper(coordinateKind:.rotation,restCoordinate:0,quadraticStiffness:3,linearDamping:2,maximumDisplacement:2,maximumRate:3)
        let response = try ScalarLoadEvaluator().evaluate(law,coordinate:theta,rate:speed,work:&loadWork)
        let passive = try GeneralizedForceContribution(values:[response.total()],channel:.applied,potentialEnergy:response.potentialEnergy,dissipatedPower:response.dissipatedPower)
        let gravity = try AffineGravity(frame:DynamicsFixtures.id(.frame,"world"),accelerationAtOrigin:Vector3(0,-10,0),uniformTimeDerivative:Vector3(0,2,0))
        let input = try RigidDynamicsInput(snapshot:base.snapshot,velocity:base.velocity,inertias:base.inertias,gravity:gravity,generalizedForces:[passive])
        let kernel = RigidEquationKernel(), system = try kernel.assemble(input,admission:DynamicsFixtures.admission(),loadWork:&loadWork,work:&work)
        let result = try DenseRigidDynamics().forward(system,driveForce:[0],policy:DynamicsFixtures.policy(1),work:&work)
        let energy = try kernel.energy(system,acceleration:result.acceleration,angularMomentumReference:.zero,requireComplete:true,work:&work)
        let com = try UnitQuaternion(axis:.unitZ,angle:theta).rotating(.unitX)
        #expect(abs(energy.potentialEnergy! - (20*com.y+3*theta*theta/2)) < 1e-9)
        #expect(abs(energy.dissipatedPower! - 2*speed*speed) < 1e-9)
        #expect(abs(energy.gravityExplicitPotentialTimeDerivative+4*com.y) < 1e-9)
        let fixedTimePotentialRate = 20*com.x*speed+3*theta*speed
        #expect(abs(energy.kineticEnergyRate+fixedTimePotentialRate+energy.dissipatedPower!) < 1e-9)
        #expect(abs(system.forces.applied[0]-(try response.total())) < 1e-9)
        #expect(system.assemblyLoadWork.consumed == 3)
    }

}
