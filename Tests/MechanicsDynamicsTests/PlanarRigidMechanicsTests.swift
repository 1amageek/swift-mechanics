import SwiftMechanics
import Testing
import Foundation

@Suite struct PlanarRigidMechanicsTests {
    @Test(.timeLimit(.minutes(1))) func offsetCOMFreeBodyOriginalMassBiasForceAndEnergy() throws {
        let input=try PlanarDynamicsFixtures.free(gravity:PlanarDynamicsFixtures.gravity())
        var work=try DynamicsFixtures.work()
        let system=try PlanarDynamicsFixtures.assemble(input,work:&work)
        let m=3.0,polar=1.2,omega=1.1
        let rx=0.4*cos(0.6)+0.3*sin(0.6),ry=0.4*sin(0.6)-0.3*cos(0.6)
        let expected=[m,0,-m*ry,0,m,m*rx,-m*ry,m*rx,polar+m*(rx*rx+ry*ry)]
        for i in expected.indices { #expect(abs(system.massMatrix[i]-expected[i]) < 1e-10) }
        #expect(abs(system.inertialBias[0]+m*omega*omega*rx) < 1e-10)
        #expect(abs(system.inertialBias[1]+m*omega*omega*ry) < 1e-10)
        #expect(abs(system.inertialBias[2]) < 1e-10)
        let solved=try PlanarDynamicsFixtures.solver().forward(system,driveForce:[0,0,0],policy:DynamicsFixtures.policy(3,scales:[0.2,3,2],energy:7,time:0.4),work:&work)
        let a=[omega*omega*rx,-9+omega*omega*ry,0]
        for i in a.indices { #expect(abs(solved.acceleration[i]-a[i]) < 1e-9) }
        #expect(solved.system === system)
        guard case .planar(let source)=solved.system.input.source else { Issue.record("Planar physical source lost");return }
        #expect(source.inertias == input.inertias && source.snapshot.bodies == input.snapshot.bodies && source.velocity == input.velocity)
        let equations:any PhysicalRigidEquationComputing=RigidEquationKernel()
        let required=try equations.inertialWrench(system,body:input.inertias[0].body,acceleration:a,referencePointWorld:Vector3(1,-2,0),work:&work)
        #expect(abs(required.wrench.force.x) < 1e-10 && abs(required.wrench.force.y+27) < 1e-10)
        #expect(abs(required.wrench.torque.z+27*rx) < 1e-10)
        #expect(required.body == input.inertias[0].body && required.frame == input.snapshot.tree.worldFrame)
        let energy=try equations.energy(system,acceleration:a,angularMomentumReference:.zero,requireComplete:true,work:&work)
        let vx=0.7-omega*ry,vy = -0.4+omega*rx
        #expect(abs(energy.kineticEnergy-(m*(vx*vx+vy*vy)+polar*omega*omega)/2) < 1e-10)
        #expect(abs(energy.linearMomentum.x-m*vx) < 1e-10 && abs(energy.linearMomentum.y-m*vy) < 1e-10)
        #expect(abs(energy.angularMomentum.z-(polar*omega+(1+rx)*m*vy-(-2+ry)*m*vx)) < 1e-10)
        #expect(abs(energy.kineticEnergyRate+27*vy) < 1e-10 && energy.requiredPrescribedPower == 0)
        #expect(abs(energy.requiredVirtualPower-energy.kineticEnergyRate) < 1e-10)
        #expect(abs(energy.potentialEnergy! - 27*(-2+ry)) < 1e-10)
        let shifted=try equations.energy(system,acceleration:a,angularMomentumReference:Vector3(2,-1,3),requireComplete:true,work:&work)
        let expectedL=try energy.angularMomentum.subtracting(Vector3(2,-1,3).cross(energy.linearMomentum))
        #expect(try shifted.angularMomentum.subtracting(expectedL).magnitude() < 1e-10)
    }
    @Test(.timeLimit(.minutes(1))) func pendulumPolarInertiaAndOriginalQuery() throws {
        let input=try PlanarDynamicsFixtures.pendulum(),theta=0.4,speed=0.7
        let rx=0.6*cos(theta)-0.2*sin(theta),ry=0.6*sin(theta)+0.2*cos(theta)
        var work=try DynamicsFixtures.work();let system=try PlanarDynamicsFixtures.assemble(input,work:&work)
        let mass=0.7+2*(0.36+0.04),force = -20*rx
        #expect(abs(system.massMatrix[0]-mass) < 1e-11 && abs(system.inertialBias[0]) < 1e-10)
        #expect(abs(system.forces.gravity[0]-force) < 1e-10)
        let solver=PlanarDynamicsFixtures.solver(),policy=try DynamicsFixtures.policy(1)
        let inverse=try solver.inverse(system,acceleration:[0.8],policy:policy,work:&work)
        #expect(abs(inverse.driveForce[0]-(mass*0.8-force)) < 1e-10)
        let forward=try solver.forward(system,driveForce:inverse.driveForce,policy:policy,work:&work)
        #expect(abs(forward.acceleration[0]-0.8) < 1e-9)
        let product=try solver.inverseMassProduct(system,rightHandSide:[2],policy:policy,work:&work)
        #expect(abs(product.acceleration[0]-2/mass) < 1e-10 && product.originalPhysicalResidual.isAccepted)
        let kernel:any PhysicalRigidEquationComputing=RigidEquationKernel()
        var original=[Double.nan]
        try kernel.originalInertialForce(system,acceleration:[0.8],includeBias:true,into:&original,work:&work)
        #expect(abs(original[0]-mass*0.8) < 1e-10)
        let energy=try kernel.energy(system,acceleration:[0.8],angularMomentumReference:.zero,requireComplete:true,work:&work)
        #expect(abs(energy.kineticEnergy-mass*speed*speed/2) < 1e-10 && abs(energy.potentialEnergy!-20*ry) < 1e-10)
        #expect(abs(energy.kineticEnergyRate-mass*speed*0.8) < 1e-10)
    }
    @Test(.timeLimit(.minutes(1))) func twoLinkOriginalMassCoriolisGravityAndMixed() throws {
        var work=try DynamicsFixtures.work();let system=try PlanarDynamicsFixtures.assemble(PlanarDynamicsFixtures.twoLink(),work:&work)
        let m11=1+2*0.49+0.9+3*(4+0.64+3.2*cos(-0.6)),m12=0.9+3*(0.64+1.6*cos(-0.6)),m22=0.9+3*0.64
        let h=4.8*sin(-0.6),c1 = -h*(2*0.8*(-0.4)+0.16),c2=h*0.64
        let g1 = -10*(1.4*cos(0.3)+3*(2*cos(0.3)+0.8*cos(-0.3))),g2 = -24*cos(-0.3)
        #expect(abs(system.massMatrix[0]-m11) < 1e-10 && abs(system.massMatrix[1]-m12) < 1e-10 && abs(system.massMatrix[3]-m22) < 1e-10)
        #expect(system.massMatrix[1] == system.massMatrix[2])
        #expect(abs(system.inertialBias[0]-c1) < 1e-10 && abs(system.inertialBias[1]-c2) < 1e-10)
        #expect(abs(system.forces.gravity[0]-g1) < 1e-10 && abs(system.forces.gravity[1]-g2) < 1e-10)
        let drive=[m11*0.4-m12*0.6+c1-g1,m12*0.4-m22*0.6+c2-g2]
        let solver=PlanarDynamicsFixtures.solver(),policy=try DynamicsFixtures.policy(2)
        let mixed=try solver.mixed(system,partition:[.prescribedAcceleration(0.4),.prescribedDriveForce(drive[1])],policy:policy,work:&work)
        #expect(mixed.acceleration[0] == 0.4 && abs(mixed.acceleration[1]+0.6) < 1e-9)
        #expect(abs(mixed.driveForce[0]-drive[0]) < 1e-9 && mixed.driveForce[1] == drive[1])
        let allKnown=try solver.mixed(system,partition:[.prescribedAcceleration(0.4),.prescribedAcceleration(-0.6)],policy:policy,work:&work)
        #expect(allKnown.linearDiagnostics == nil)
        for i in drive.indices { #expect(abs(allKnown.driveForce[i]-drive[i]) < 1e-9) }
        let zero=try PlanarDynamicsFixtures.assemble(PlanarDynamicsFixtures.twoLink(acceleration:[0,0]),work:&work)
        #expect(zero.massMatrix == system.massMatrix)
        for i in 0..<2 { #expect(abs(zero.inertialBias[i]-system.inertialBias[i]) < 1e-10) }
        let energy=try RigidEquationKernel().energy(system,acceleration:[0.4,-0.6],angularMomentumReference:.zero,requireComplete:true,work:&work)
        #expect(abs(energy.kineticEnergy-(m11*0.64-0.64*m12+m22*0.16)/2) < 1e-10)
        #expect(abs(energy.potentialEnergy! - 10*(1.4*sin(0.3)+3*(2*sin(0.3)+0.8*sin(-0.3)))) < 1e-10)
    }
    @Test(.timeLimit(.minutes(1))) func actualPrescribedDriftPowerAndFramedLoads() throws {
        let load=try BodyWrenchContribution(body:DynamicsFixtures.id(.body,"plane-bob"),frame:DynamicsFixtures.id(.frame,"plane-bob-frame"),referencePoint:.zero,
            wrench:SpatialWrench(torque:Vector3(0,0,2),force:Vector3(3,0,0)),channel:.applied,potentialEnergy:0,dissipatedPower:0)
        let input=try PlanarDynamicsFixtures.pendulum(prescribed:true,loads:[load]);var work=try DynamicsFixtures.work()
        let system=try PlanarDynamicsFixtures.assemble(input,work:&work)
        let rx=0.6*cos(0.4)-0.2*sin(0.4),ry=0.6*sin(0.4)+0.2*cos(0.4),omega=0.7,polar=0.7,m=2.0
        #expect(abs(system.inertialBias[0]+6*ry) < 1e-10)
        #expect(abs(system.forces.applied[0]-2) < 1e-10)
        #expect(abs(system.forces.prescribedPower-12*cos(0.4)) < 1e-10)
        #expect(abs(system.forces.virtualPower-(2-20*rx)*omega) < 1e-10)
        let energy=try RigidEquationKernel().energy(system,acceleration:[0.5],angularMomentumReference:.zero,requireComplete:true,work:&work)
        let vx=4-omega*ry,vy=omega*rx,ax=3-0.5*ry-omega*omega*rx,ay=0.5*rx-omega*omega*ry
        #expect(abs(energy.kineticEnergy-(m*(vx*vx+vy*vy)+polar*omega*omega)/2) < 1e-10)
        #expect(abs(energy.requiredPrescribedPower-4*m*ax) < 1e-10)
        #expect(abs(energy.kineticEnergyRate-(m*(vx*ax+vy*ay)+polar*omega*0.5)) < 1e-10)
        #expect(abs(energy.kineticEnergyRate-energy.requiredVirtualPower-energy.requiredPrescribedPower) < 1e-10)
    }
    @Test(.timeLimit(.minutes(1))) func originalReferencePointCanCancelRawTransverseTorque() throws {
        let load=try BodyWrenchContribution(body:DynamicsFixtures.id(.body,"free-plane"),frame:DynamicsFixtures.id(.frame,"world"),referencePoint:Vector3(1.3,-2.2,2),
            wrench:SpatialWrench(torque:Vector3(-6,-4,1),force:Vector3(2,-3,0)),channel:.applied,potentialEnergy:0,dissipatedPower:0)
        var work=try DynamicsFixtures.work();let system=try PlanarDynamicsFixtures.assemble(PlanarDynamicsFixtures.free(loads:[load]),work:&work)
        #expect(abs(system.forces.applied[0]-2) < 1e-10 && abs(system.forces.applied[1]+3) < 1e-10)
        #expect(abs(system.forces.applied[2]-0.5) < 1e-10)
        #expect(abs(system.forces.actualPower-(2*0.7+(-3)*(-0.4)+0.5*1.1)) < 1e-10)
    }
}
