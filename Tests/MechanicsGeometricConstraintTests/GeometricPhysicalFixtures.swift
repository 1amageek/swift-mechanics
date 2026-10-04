import SwiftMechanics

internal enum GeometricPhysicalFixtures {
    static func policy(bodies: Int = 12, cancelled: Bool = false) throws -> GeometricPhysicalRowPolicy {
        try GeometricPhysicalRowPolicy(evaluation:GeometricFixtures.evaluation(cancelled:{ cancelled }),maximumBodies:bodies,
            originalComparisonTolerance:1e-10,projectionTolerance:NumericalTolerance(absolute:1e-10,relative:1e-10))
    }
    static func sliders(planar: Bool = true, floating: Bool = false) throws -> CompiledMechanicalModel {
        let joints = try [GeometricFixtures.joint("a",parent:"ground",child:"first",specification:.prismatic(axis:.unitX)),
            GeometricFixtures.joint("b",parent:"ground",child:"second",specification:.prismatic(axis:.unitX))]
        return try GeometricFixtures.compile(names:["ground","first","second"],poses:[.identity,.identity,GeometricFixtures.pose(2,0)],
            joints:joints,q:floating ? [0,0,0] : [],v:floating ? [0,0,0] : [],floating:floating,
            jointCoordinates:["a":([0],[0]),"b":([2],[0])],planar:planar)
    }
    static func distance(scale: Double = 2, target: GeometricAnalyticTarget? = nil) throws -> GeometricRelation {
        try GeometricRelation(kind:.distance,rowIDs:[91],
            first:GeometricFrameEndpoint(body:GeometricFixtures.id(.body,"first"),frame:GeometricFixtures.id(.frame,"first")),
            second:GeometricFrameEndpoint(body:GeometricFixtures.id(.body,"second"),frame:GeometricFixtures.id(.frame,"second")),
            target:target ?? GeometricAnalyticTarget(value:Vector3(2,0,0)),scale:scale)
    }
}
