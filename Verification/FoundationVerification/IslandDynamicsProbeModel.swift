import SwiftMechanics

/// Original compiled rotor/slider inputs, without constructing any issued island evidence.
final class IslandDynamicsProbeModel: Sendable {
    let model: CompiledMechanicalModel
    let constraints: QuadraticConstraintSystem
    let firstRotor: EntityID
    let secondRotor: EntityID
    let slider: EntityID
    let firstIndex: Int
    let secondIndex: Int
    let sliderIndex: Int
    let firstRotationalInertia: Double

    @inline(never)
    init(firstRotationalInertia: Double = 2) throws {
        let original = try ConstrainedImpactProbeModel()
        let compiled: CompiledMechanicalModel
        if firstRotationalInertia == 2 {
            compiled = original.model
        } else {
            compiled = try Self.recompile(original.model, body: original.firstRotor,
                rotationalInertia: firstRotationalInertia)
        }
        model = compiled
        constraints = original.constraints
        firstRotor = original.firstRotor
        secondRotor = original.secondRotor
        slider = original.striker
        firstIndex = original.firstRotorCoordinateIndex
        secondIndex = original.secondRotorCoordinateIndex
        sliderIndex = original.strikerCoordinateIndex
        self.firstRotationalInertia = firstRotationalInertia
    }

    func drive(first: Double = 2, second: Double = 2, slider: Double = 4) -> [Double] {
        var result = [Double](repeating: 0, count: 3)
        result[firstIndex] = first
        result[secondIndex] = second
        result[sliderIndex] = slider
        return result
    }

    /// Only public state inputs are authored; makeState/evaluate remain the compiler authority.
    func physical(firstPosition: Double = 0, secondPosition: Double = 0, sliderPosition: Double = 0.5,
                  firstVelocity: Double = 0, secondVelocity: Double = 0, sliderVelocity: Double = -1,
                  time: Double = 0.25, revision: UInt64? = nil) throws -> KinematicState {
        var q = [Double](repeating: 0, count: 3), v = q
        q[firstIndex] = firstPosition; q[secondIndex] = secondPosition; q[sliderIndex] = sliderPosition
        v[firstIndex] = firstVelocity; v[secondIndex] = secondVelocity; v[sliderIndex] = sliderVelocity
        return try KinematicState(revision: revision ?? model.stamp.revision, time: time,
            q: q, v: v, acceleration: [0, 0, 0])
    }

    @inline(never)
    private static func recompile(_ source: CompiledMechanicalModel, body: EntityID,
                                  rotationalInertia: Double) throws -> CompiledMechanicalModel {
        let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        var bodies = source.descriptor.bodies
        guard let index = bodies.firstIndex(where: { $0.id == body }),
              case .spatial(let record) = bodies[index], let original = record.inertia else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        let properties = try MassProperties3D(mass: 2, centerOfMass: .zero,
            inertiaAtCenter: Matrix3(rotationalInertia, 0, 0, 0, rotationalInertia, 0, 0, 0, rotationalInertia),
            policy: InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0))
        bodies[index] = .spatial(try BodyRecord3D(id: record.id, frame: record.frame, mode: record.mode,
            bodyToWorld: record.bodyToWorld, representations: record.representations,
            inertia: InertialRepresentation3D(properties: properties, provenance: original.provenance, quality: original.quality)))
        let d = source.descriptor
        let descriptor = try MechanicalDescriptor(identity: d.identity, revision: d.revision, bodies: bodies,
            joints: d.joints, root: d.root, rootBase: d.rootBase, rootAuthority: d.rootAuthority,
            worldFrame: d.worldFrame, initialState: d.initialState, representationRequirements: d.representationRequirements,
            features: d.features, extensions: d.extensions)
        let compiler: any MechanicalModelCompiling = ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions())
        return try compiler.compile(descriptor, policy: source.policy)
    }
}
