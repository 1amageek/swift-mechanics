import SwiftMechanics

/// The qualified original physical model, retained without rebuilding its identities.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
struct SleepTopologyProbeModel: Sendable {
    let fixture: QuadraticColdProbeModel
    var model: CompiledMechanicalModel { fixture.model }
    var aJoint: EntityID { fixture.aJoint }
    var bJoint: EntityID { fixture.bJoint }
    var cJoint: EntityID { fixture.cJoint }
    var a: EntityID { fixture.a }
    var root: EntityID { fixture.root }
    var b: EntityID { fixture.b }
    var c: EntityID { fixture.c }
    var aPosition: Int { fixture.aPosition }
    var aVelocity: Int { fixture.aVelocity }
    var bPosition: Int { fixture.bPosition }
    var cPosition: Int { fixture.cPosition }
    var bVelocity: Int { fixture.bVelocity }
    var cVelocity: Int { fixture.cVelocity }
    var constraints: QuadraticConstraintSystem { fixture.constraints }
    var drive: [Double] { fixture.drive }

    @inline(never)
    init(mass: Double = 2) throws { fixture = try QuadraticColdProbeModel(mass: mass) }
}
