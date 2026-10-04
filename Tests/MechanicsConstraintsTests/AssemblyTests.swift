import SwiftMechanics
#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("No admitted scalar mathematics platform module is available.")
#endif
import Testing

@Suite(.timeLimit(.minutes(1)))
struct AssemblyTests {
    @Test func explicitLoopSeedsRetainBothCircleIntersectionBranches() throws {
        let system=try ConstraintFixtures.loops(), policy=try ConstraintFixtures.policy()
        let assembler: any ConstraintAssembling=WeightedConstraintAssembler()
        for sign in [-1.0,1.0] {
            var work=try ConstraintFixtures.work()
            let result=try assembler.assemble(system,initialPosition:[0.7,sign*0.6],time:0,policy:policy,work:&work)
            #expect(ConstraintFixtures.close(result.position[0],0.5))
            #expect(ConstraintFixtures.close(result.position[1],sign*0.75.squareRoot()))
            // Check both original distances independently of the producer's quadratic expansion.
            #expect(ConstraintFixtures.close(result.position[0]*result.position[0]+result.position[1]*result.position[1],1))
            #expect(ConstraintFixtures.close((result.position[0]-1)*(result.position[0]-1)+result.position[1]*result.position[1],1))
            #expect(result.originalResidual <= 1e-8); #expect(result.stationarityResidual <= 1e-8)
            #expect(result.rank.rank == 2); #expect(result.physicalIntroducedWork == nil)
        }
    }
    @Test func weightedAssemblyAndRedundantRowsPreserveAmbiguity() throws {
        let system=try ConstraintFixtures.system([ConstraintFixtures.affine(),ConstraintFixtures.affine(id:2,constant:-2,coefficients:[2,2])])
        var work=try ConstraintFixtures.work()
        let result=try WeightedConstraintAssembler().assemble(system,initialPosition:[0,0],time:0,policy:ConstraintFixtures.policy(metric:[1,4]),work:&work)
        #expect(ConstraintFixtures.close(result.position[0],0.8)); #expect(ConstraintFixtures.close(result.position[1],0.2))
        #expect(result.rank.rank == 1); #expect(result.rank.dependentRowIDs == [2]); #expect(!result.rank.reactionsUnique)
        #expect(ConstraintFixtures.close(result.geometricObjective,0.4))
    }
    @Test func weightedVelocityProjectionReportsOriginalRowsAndEnergy() throws {
        let layout=try ConstraintFixtures.layout()
        let sample=VelocityConstraintSample(layout:layout,rowIDs:[1,2],rows:[1,1,2,2],drift:[0,0],accelerationBias:[0,0],isIntegrable:true)
        var work=try ConstraintFixtures.work(), linear=try ConstraintFixtures.work()
        let assembler: any ConstraintAssembling=WeightedConstraintAssembler()
        let result=try assembler.projectVelocity(sample,initialVelocity:[1,0],policy:ConstraintFixtures.policy(metric:[1,4]),work:&work,linearWork:&linear)
        #expect(ConstraintFixtures.close(result.velocity[0],0.2)); #expect(ConstraintFixtures.close(result.velocity[1],-0.2))
        #expect(ConstraintFixtures.close(result.introducedKineticEnergy,-2))
        #expect(result.originalResidual <= 1e-8); #expect(result.rank.rank == 1); #expect(result.linearWork.operations > 0)
    }
    @Test func knifeEdgeProjectionRemovesLateralSpeedWithoutInventedReaction() throws {
        let layout=try ConstraintCoordinateLayout(coordinateIDs:[1,2,3],dimensions:[.length,.length,.angle],scales:[2,2,1],timeScale:3,revision:7)
        let theta=0.4, c=cos(theta), s=sin(theta), v=[2*c-s,2*s+c,0.7]
        var query=try ConstraintFixtures.work(), work=try ConstraintFixtures.work(), linear=try ConstraintFixtures.work()
        let sample=try PlanarKnifeEdgeEvaluator().evaluate(layout:layout,rowID:1,position:[0,0,theta],velocity:v,policy:ConstraintFixtures.evaluation(),work:&query)
        let result=try WeightedConstraintAssembler().projectVelocity(sample,initialVelocity:v,policy:ConstraintFixtures.policy(metric:[4,4,2]),work:&work,linearWork:&linear)
        #expect(ConstraintFixtures.close(result.velocity[0],2*c)); #expect(ConstraintFixtures.close(result.velocity[1],2*s)); #expect(ConstraintFixtures.close(result.velocity[2],0.7))
        #expect(ConstraintFixtures.close(result.introducedKineticEnergy,-22.5))
    }
}
