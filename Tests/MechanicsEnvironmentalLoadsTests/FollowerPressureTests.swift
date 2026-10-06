import SwiftMechanics
import Testing
@Suite(.timeLimit(.minutes(1))) struct FollowerPressureTests {
    @Test func originalNodalForceMomentPowerAndEveryDerivative() throws {
        let service:any TrianglePressureEvaluating=TrianglePressureEvaluator()
        let points=[Vector3.zero,try Vector3(2,0,0),try Vector3(0,3,0)]
        var work=try EnvironmentalLoadFixture.work()
        func evaluate(_ p:[Vector3]) throws -> TrianglePressureResponse {
            try service.evaluate(pressure:4,body:EnvironmentalLoadFixture.body(),frame:EnvironmentalLoadFixture.frame(),vertices:p,
                velocities:[.unitZ,.unitZ,.unitZ],referencePoint:.zero,minimumTwiceArea:0,work:&work)
        }
        let r=try evaluate(points)
        let expectedNodeForce = try Vector3(0,0,-4)
        #expect(r.nodalLoads.count == 3 && r.nodalLoads.allSatisfy { $0.forces.active == expectedNodeForce })
        #expect(r.resultant.force == (try Vector3(0,0,-12)))
        #expect(r.resultant.torque == (try Vector3(-12,8,0)))
        #expect(r.mechanicalPower == -12)
        let h=1e-5
        for j in 0..<3 { for e in [Vector3.unitX,.unitY,.unitZ] {
            var plus=points, minus=points; plus[j]=try plus[j].adding(e.scaled(by:h)); minus[j]=try minus[j].subtracting(e.scaled(by:h))
            let fp=try evaluate(plus).nodalLoads[0].forces.active, fm=try evaluate(minus).nodalLoads[0].forces.active
            #expect(try EnvironmentalLoadFixture.close(fp.subtracting(fm).scaled(by:1/(2*h)),r.forceVertexDerivatives[j].applying(to:e),tolerance:1e-8))
        }}
        let sum=try r.forceVertexDerivatives[0].adding(r.forceVertexDerivatives[1]).adding(r.forceVertexDerivatives[2])
        #expect(sum == .zero)
    }
    @Test func degenerateAndWrongShapeFailures() throws {
        var work=try EnvironmentalLoadFixture.work()
        #expect(throws:LoadError.invalidShape) { try TrianglePressureEvaluator().evaluate(pressure:1,body:EnvironmentalLoadFixture.body(),frame:EnvironmentalLoadFixture.frame(),vertices:[.zero,.unitX,Vector3(2,0,0)],velocities:[.zero,.zero,.zero],referencePoint:.zero,minimumTwiceArea:0,work:&work) }
        #expect(throws:LoadError.invalidInput) { try TrianglePressureEvaluator().evaluate(pressure:1,body:EnvironmentalLoadFixture.body(),frame:EnvironmentalLoadFixture.frame(),vertices:[.zero,.unitX,.unitY],velocities:[],referencePoint:.zero,minimumTwiceArea:0,work:&work) }
    }
}
