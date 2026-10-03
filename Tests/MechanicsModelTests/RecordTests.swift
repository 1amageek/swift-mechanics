import Testing
import MechanicsCore
@testable import MechanicsModel

@Suite struct RecordTests {
    @Test func identityRolesInstancesAndRevisions() throws {
        let first = try EntityID(kind: .body, key: "occurrence-a")
        let second = try EntityID(kind: .body, key: "occurrence-b")
        #expect(first != second)
        let frameWithSameKey = try EntityID(kind: .frame, key: "occurrence-a")
        #expect(first != frameWithSameKey)
        #expect(throws: ModelError.emptyIdentity) { try EntityID(kind: .joint, key: "") }
        for kind in [EntityKind.body, .frame, .joint, .collider, .material, .load, .actuator, .sensor] {
            #expect(try EntityID(kind: kind, key: "stable").kind == kind)
        }
        let reference = ModelReference(id: first, revision: 2)
        try reference.validating(revision: 2)
        #expect(throws: ModelError.revisionMismatch) { try reference.validating(revision: 3) }
    }

    @Test func representationSeparationMissingAndInvalidQuality() throws {
        let source = try SourceProvenance(source: "shared-part", revision: 8)
        let collision = try GeometryRepresentation(kind: .collisionGeometry, assetKey: "collision", provenance: source, quality: .exact)
        let firstDisplay = try GeometryRepresentation(kind: .displayGeometry, assetKey: "display-a", provenance: source, quality: .approximation(maximumDeviationMeters: 0.01))
        let secondDisplay = try GeometryRepresentation(kind: .displayGeometry, assetKey: "display-b", provenance: source, quality: .approximation(maximumDeviationMeters: 0.001))
        let first = try BodyRepresentations(displayGeometry: firstDisplay, collisionGeometry: collision)
        let second = try BodyRepresentations(displayGeometry: secondDisplay, collisionGeometry: collision)
        #expect(first.collisionGeometry == second.collisionGeometry)
        #expect(first.displayGeometry != second.displayGeometry)
        #expect(throws: ModelError.missingRepresentation) { try first.requiring(.geometricShape) }
        #expect(try first.requiring(.collisionGeometry) == collision)
        #expect(throws: ModelError.representationKindMismatch) { try BodyRepresentations(displayGeometry: collision) }
        #expect(throws: ModelError.invalidMetadata) { try GeometryRepresentation(kind: .displayGeometry, assetKey: "invalid", provenance: source, quality: .approximation(maximumDeviationMeters: -1)) }
        #expect(throws: ModelError.invalidMetadata) { try GeometryRepresentation(kind: .collisionGeometry, assetKey: "invalid", provenance: source, quality: .approximation(maximumDeviationMeters: .infinity)) }
        #expect(throws: ModelError.invalidMetadata) {
            try InertialApproximation(maximumMassErrorKilograms: -1, maximumCenterErrorMeters: 0,
                                      maximumInertiaElementErrorKilogramMetersSquared: 0)
        }
        let bound = try InertialApproximation(maximumMassErrorKilograms: 0.01, maximumCenterErrorMeters: 0.001,
                                             maximumInertiaElementErrorKilogramMetersSquared: 0.02)
        #expect(bound.maximumMassErrorKilograms == 0.01)
        #expect(throws: ModelError.emptyIdentity) { try SourceProvenance(source: "", revision: 0) }
    }

    @Test func bodyModesAndIndependentInertiaInBothDimensions() throws {
        let source = try SourceProvenance(source: "shared-part", revision: 1)
        let id = try EntityID(kind: .body, key: "body-a")
        let frame = try EntityID(kind: .frame, key: "body-frame")
        let representations = try BodyRepresentations()
        let policy = try InertiaValidationPolicy(symmetry: NumericalTolerance(absolute: 0, relative: 0), physicalityRelative: 0)
        let inertia = InertialRepresentation3D(properties: try MassProperties3D(mass: 1, centerOfMass: .zero, inertiaAtCenter: .identity, policy: policy), provenance: source, quality: .exact)
        let planarInertia = InertialRepresentation2D(properties: try MassProperties2D(mass: 1, centerX: 0, centerY: 0, polarInertiaAtCenter: 1), provenance: source, quality: .exact)
        let planarPose = try PlanarPose(x: 2, y: 3, angle: 0.4)
        for mode in [BodyMotionMode.dynamic, .static, .prescribedKinematic] {
            let spatial = try BodyRecord3D(id: id, frame: frame, mode: mode, bodyToWorld: .identity, representations: representations, inertia: mode == .dynamic ? inertia : nil)
            let planar = try BodyRecord2D(id: id, frame: frame, mode: mode, bodyToWorld: planarPose, representations: representations, inertia: mode == .dynamic ? planarInertia : nil)
            #expect(spatial.mode == mode && planar.mode == mode)
            #expect(mode.isForceDriven == (mode == .dynamic))
            #expect(mode.hasPrescribedMotion == (mode == .prescribedKinematic))
            #expect(mode.hasFixedMotion == (mode == .static))
            #expect(mode.permitsReactionObservation)
        }
        #expect(throws: ModelError.missingDynamicInertia) { try BodyRecord3D(id: id, frame: frame, mode: .dynamic, bodyToWorld: .identity, representations: representations, inertia: nil) }
        #expect(throws: ModelError.missingDynamicInertia) { try BodyRecord2D(id: id, frame: frame, mode: .dynamic, bodyToWorld: planarPose, representations: representations, inertia: nil) }
        #expect(throws: ModelError.identityKindMismatch) { try BodyRecord3D(id: frame, frame: id, mode: .static, bodyToWorld: .identity, representations: representations, inertia: nil) }
        let display = try GeometryRepresentation(kind: .displayGeometry, assetKey: "new-display", provenance: source, quality: .exact)
        let replacement = try BodyRecord3D(id: id, frame: frame, mode: .dynamic, bodyToWorld: .identity,
                                          representations: BodyRepresentations(displayGeometry: display), inertia: inertia)
        let otherOccurrence = try BodyRecord3D(id: EntityID(kind: .body, key: "body-b"), frame: frame, mode: .dynamic,
                                              bodyToWorld: .identity, representations: representations, inertia: inertia)
        #expect(replacement.inertia == otherOccurrence.inertia)
        #expect(replacement.id != otherOccurrence.id)
    }
}
