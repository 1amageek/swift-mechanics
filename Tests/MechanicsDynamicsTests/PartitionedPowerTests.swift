import SwiftMechanics
import Testing
import Foundation

@Suite struct PartitionedPowerTests {
    @Test func originalPlanarCOMForceAndFullCoordinatePowerRemainPhysicalWithKnownRoot() throws {
        let input=try PlanarDynamicsFixtures.free(),policy=try DynamicsFixtures.policy(3)
        var work=try DynamicsFixtures.work(),system=try PlanarDynamicsFixtures.assemble(input,work:&work)
        let operation:any PhysicalPowerPartitioning=RigidEquationKernel(),a=[0.3,0.2,0.5]
        let result=try operation.partitionedPower(system,acceleration:a,knownCoordinates:[0,1,2],drive:[0,0,0],geometricReaction:[0,0,0],policy:policy,work:&work)
        let x=cos(0.6)*0.4-sin(0.6)*(-0.3),y=sin(0.6)*0.4+cos(0.6)*(-0.3),omega=1.1
        let vx=0.7-omega*y,vy = -0.4+omega*x
        let fx=3*(a[0]-a[2]*y-omega*omega*x),fy=3*(a[1]+a[2]*x-omega*omega*y)
        let effort=[fx,fy,1.2*a[2]+x*fy-y*fx],power=fx*vx+fy*vy+1.2*omega*a[2]
        for i in effort.indices { #expect(abs(result.rootActuationEffort[i]-effort[i]) < 1e-10) }
        #expect(abs(result.energy.kineticEnergy-(1.5*(vx*vx+vy*vy)+0.6*omega*omega)) < 1e-10)
        #expect(abs(result.knownCoordinatePower-power) < 1e-10 && abs(result.rootActuationPower-power) < 1e-10)
        #expect(result.dynamicCoordinatePower == 0 && result.anchorPrescribedPower == 0)
        #expect(result.system === system && result.acceleration == a)
        #expect(abs(result.energy.requiredVirtualPower-result.knownCoordinatePower) < 1e-10)
        #expect(result.energy.requiredPrescribedPower == 0)
    }
    @Test func knownCoordinateConflictDuplicateShapeWorkAndActualDynamicImbalanceFailExplicitly() throws {
        var work=try DynamicsFixtures.work()
        let system=try PlanarDynamicsFixtures.assemble(PlanarDynamicsFixtures.free(),work:&work),policy=try DynamicsFixtures.policy(3)
        let operation:any PhysicalPowerPartitioning=RigidEquationKernel()
        for known in [[0,0],[3]] {
            do throws(DynamicsError) { _=try operation.partitionedPower(system,acceleration:[0,0,0],knownCoordinates:known,drive:[0,0,0],geometricReaction:[0,0,0],policy:policy,work:&work);Issue.record("Invalid partition accepted") }
            catch { if case .invalidInput=error {} else { Issue.record("Wrong partition failure") } }
        }
        do throws(DynamicsError) { _=try operation.partitionedPower(system,acceleration:[0,0,0],knownCoordinates:[0],drive:[1,0,0],geometricReaction:[0,0,0],policy:policy,work:&work);Issue.record("Known drive conflict accepted") }
        catch { if case .invalidInput=error {} else { Issue.record("Wrong drive failure") } }
        do throws(DynamicsError) { _=try operation.partitionedPower(system,acceleration:[1,0,0],knownCoordinates:[],drive:[0,0,0],geometricReaction:[0,0,0],policy:policy,work:&work);Issue.record("Unbalanced dynamic force accepted") }
        catch { if case .physicalResidualRejected=error {} else { Issue.record("Wrong original balance failure") } }
        let tiny=try DynamicsFixtures.work(storage:1,operations:1)
        var exhausted=tiny
        do throws(DynamicsError) { _=try operation.partitionedPower(system,acceleration:[0,0,0],knownCoordinates:[0,1,2],drive:[0,0,0],geometricReaction:[0,0,0],policy:policy,work:&exhausted);Issue.record("Budget ignored") }
        catch { if case .numerical(.resourceLimit,_)=error {} else { Issue.record("Wrong capacity failure") } }
        #expect(exhausted.operations == 0)
    }
}
