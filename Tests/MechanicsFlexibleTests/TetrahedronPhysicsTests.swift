import MechanicsCore
import MechanicsModel
import MechanicsMaterials
import MechanicsNumerics
import MechanicsFlexible
import Testing
@Suite(.timeLimit(.minutes(1)))
struct TetrahedronPhysicsTests {
    @Test func affineUniaxialPatchAndIndependentEnergy() throws {
        let mesh = try FlexibleFixtures.mesh(), f = try Matrix3(1.1,0,0,0,1,0,0,0,1)
        let result = try FlexibleFixtures.response(mesh,state:FlexibleFixtures.state(mesh,f:f))
        let e = 0.105, lambda = 1000.0-800/3, volume = 1.0/6
        let pxx = 1.1*((lambda+800)*e+800*e*e*e), pyy = lambda*e
        #expect(FlexibleFixtures.close(result.storedEnergy,volume*(0.5*(lambda+800)*e*e+200*e*e*e*e)))
        let expected = [-pxx*volume,-pyy*volume,-pyy*volume,pxx*volume,0,0,0,pyy*volume,0,0,0,pyy*volume]
        for i in 0..<12 { #expect(FlexibleFixtures.close(result.internalForce[i],expected[i])) }
        #expect(result.constitutiveWork.calls == 13)
        for axis in 0..<3 { #expect(abs(result.internalForce[axis]+result.internalForce[3+axis]+result.internalForce[6+axis]+result.internalForce[9+axis]) < 1e-10) }
        #expect(result.meshRevision == mesh.mesh.revision)
    }
    @Test func finiteObjectivityForceCovarianceAndRigidNullModes() throws {
        let mesh = try FlexibleFixtures.mesh(), f = try Matrix3(1.08,0.03,0.01,-0.02,0.98,0.04,0.02,-0.01,1.03)
        let rotation = try UnitQuaternion(axis:Vector3(1,2,3),angle:1.1).matrix()
        let original = try FlexibleFixtures.response(mesh,state:FlexibleFixtures.state(mesh,f:f))
        let rotated = try FlexibleFixtures.response(mesh,state:FlexibleFixtures.state(mesh,f:rotation.multiplied(by:f),translation:Vector3(3,-2,4)))
        #expect(FlexibleFixtures.close(original.storedEnergy,rotated.storedEnergy))
        for i in 0..<4 {
            let force = try Vector3(original.internalForce[3*i],original.internalForce[3*i+1],original.internalForce[3*i+2])
            let expected = try rotation.applying(to:force)
            #expect(FlexibleFixtures.close(rotated.internalForce[3*i],expected.x))
            #expect(FlexibleFixtures.close(rotated.internalForce[3*i+1],expected.y))
            #expect(FlexibleFixtures.close(rotated.internalForce[3*i+2],expected.z))
        }
        let rest = try FlexibleFixtures.response(mesh,state:FlexibleFixtures.state(mesh))
        let pure = try FlexibleFixtures.response(mesh,state:FlexibleFixtures.state(mesh,f:rotation,translation:Vector3(5,2,-1)))
        #expect(abs(pure.storedEnergy) < 1e-20)
        #expect(pure.internalForce.allSatisfy { abs($0) < 1e-9 })
        for axis in 0..<3 {
            var translation = [Double](repeating:0,count:12), spin = [Double](repeating:0,count:12)
            let omega: Vector3 = axis == 0 ? .unitX : (axis == 1 ? .unitY : .unitZ)
            for i in 0..<4 {
                translation[3*i+axis] = 1
                let velocity = try omega.cross(mesh.mesh.nodes[i].referencePosition)
                spin[3*i] = velocity.x; spin[3*i+1] = velocity.y; spin[3*i+2] = velocity.z
            }
            #expect(FlexibleFixtures.action(rest.tangent,spin).allSatisfy { abs($0) < 1e-9 })
            #expect(FlexibleFixtures.action(original.tangent,translation).allSatisfy { abs($0) < 1e-9 })
        }
    }
    @Test func energyGradientAndPrestressedDirectionalTangent() throws {
        let mesh = try FlexibleFixtures.mesh(), state = try FlexibleFixtures.state(mesh,f:Matrix3(1.1,0.04,0,0.02,0.95,0.03,0,0.01,1.02))
        let result = try FlexibleFixtures.response(mesh,state:state)
        let direction = [0.13,-0.11,0.07,-0.2,0.1,0.16,0.04,0.18,-0.09,0.02,-0.03,0.14], h = 1e-6
        var plus: [Vector3] = [], minus: [Vector3] = []
        for i in 0..<4 {
            let d = try Vector3(direction[3*i],direction[3*i+1],direction[3*i+2]).scaled(by:h)
            plus.append(try state.positions[i].adding(d)); minus.append(try state.positions[i].subtracting(d))
        }
        let a = try FlexibleFixtures.response(mesh,state:NodalState(frame:mesh.mesh.frame,meshRevision:1,nodeIdentifiers:state.nodeIdentifiers,positions:plus,velocities:state.velocities))
        let b = try FlexibleFixtures.response(mesh,state:NodalState(frame:mesh.mesh.frame,meshRevision:1,nodeIdentifiers:state.nodeIdentifiers,positions:minus,velocities:state.velocities))
        let tangentDirection = FlexibleFixtures.action(result.tangent,direction)
        var energyDirection = 0.0
        for i in 0..<12 { energyDirection += result.internalForce[i]*direction[i]; #expect(FlexibleFixtures.close(tangentDirection[i],(a.internalForce[i]-b.internalForce[i])/(2*h),tolerance:1e-6)) }
        #expect(FlexibleFixtures.close(energyDirection,(a.storedEnergy-b.storedEnergy)/(2*h),tolerance:1e-6))
        for i in 0..<12 { for j in 0..<12 { #expect(FlexibleFixtures.close(result.tangent[12*i+j],result.tangent[12*j+i])) } }
    }
    @Test func exactMassAndDampingConservation() throws {
        let mesh = try FlexibleFixtures.mesh(), velocity = try Vector3(2,-1,3), state = try FlexibleFixtures.state(mesh,velocity:velocity)
        let consistent = try FlexibleFixtures.response(mesh,state:state), lumped = try FlexibleFixtures.response(mesh,state:state,form:.rowSumLumped)
        #expect(consistent.totalReferenceMass == 1)
        for i in 0..<12 { for j in 0..<12 {
            let expected = i%3 != j%3 ? 0 : ((i/3 == j/3 ? 2.0 : 1.0)/20)
            #expect(FlexibleFixtures.close(consistent.mass[i*12+j],expected))
            #expect(FlexibleFixtures.close(lumped.mass[i*12+j],i == j ? 0.25 : 0))
            #expect(FlexibleFixtures.close(consistent.damping[i*12+j],3*expected))
        } }
        #expect(FlexibleFixtures.close(consistent.dissipatedPower,42))
        #expect(FlexibleFixtures.close(lumped.dissipatedPower,42))
        var vector = [Double](repeating:0,count:12)
        for i in 0..<12 { vector[i] = Double(i-4)/7 }
        let action = FlexibleFixtures.action(consistent.mass,vector)
        var kineticTwice = 0.0
        for i in 0..<12 { kineticTwice += vector[i]*action[i] }
        #expect(kineticTwice > 0)
    }
    @Test func centroidRefinementAffinePatchAndAssignmentPreservation() throws {
        let mesh = try FlexibleFixtures.mesh(), service: any TetrahedralMeshValidating = TetrahedralMeshValidator()
        var work = try FlexibleFixtures.work()
        let refined = try service.refine(mesh,revision:2,newNodeIdentifiers:[1000],newCellIdentifiers:[101,102,103,104],admission:FlexibleFixtures.admission(),work:&work)
        #expect(refined.mesh.nodes.count == 5 && refined.mesh.cells.count == 4)
        for i in 0..<4 { #expect(refined.mesh.nodes[i] == mesh.mesh.nodes[i]) }
        #expect(refined.mesh.nodes[4].boundaryGroup == nil)
        #expect(refined.mesh.source == mesh.mesh.source)
        for cell in refined.mesh.cells { #expect(cell.material == mesh.mesh.cells[0].material && cell.source == mesh.mesh.cells[0].source && cell.parentIdentifier == 50) }
        let f = try Matrix3(1.05,0.04,0,0,1.02,0.03,0,0,0.97)
        let base = try FlexibleFixtures.response(mesh,state:FlexibleFixtures.state(mesh,f:f))
        let child = try FlexibleFixtures.response(refined,state:FlexibleFixtures.state(refined,f:f))
        #expect(FlexibleFixtures.close(base.storedEnergy,child.storedEnergy))
        #expect(FlexibleFixtures.close(base.totalReferenceMass,child.totalReferenceMass))
        for i in 0..<12 { #expect(FlexibleFixtures.close(base.internalForce[i],child.internalForce[i])) }
        for i in 12..<15 { #expect(abs(child.internalForce[i]) < 1e-9) }
        #expect(refined.referenceCells.allSatisfy { FlexibleFixtures.close($0.volume,1.0/24) })
    }
}
