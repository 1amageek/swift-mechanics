import CADIR
import SwiftMechanics

/// Owned deterministic provenance bytes; original source and physical owners supply every value.
struct CADGearRecipeEncoding {
    private(set) var bytes: [UInt8] = []
    private var metadata = 0
    private let maximumBytes: Int
    private let maximumMetadataBytes: Int
    init(maximumBytes: Int, maximumMetadataBytes: Int) {
        self.maximumBytes = maximumBytes; self.maximumMetadataBytes = maximumMetadataBytes
    }
    @available(macOS 15, *)
    static func encode(_ binding: CADGearPairBinding, equations: NonlinearMechanismEquation,
                       runtime: CADGearRuntimePolicy, work: inout CADAdapterWork)
        throws(CADGearReinitializationError) -> [UInt8] {
        var value = Self(maximumBytes: runtime.maximumRecipeBytes, maximumMetadataBytes: runtime.maximumMetadataBytes)
        try value.text("mechanics.cad.gears.recipe.v1", work: &work)
        let source = binding.geometry.identity
        for text in [source.providerPin, source.documentID.description, source.fingerprint.algorithm,
                     source.fingerprint.value, source.units.length.rawValue, source.units.angle.rawValue] {
            try value.text(text, work: &work)
        }
        guard source.designRevision.value >= 0, source.parameterRevision.value >= 0 else { throw .staleSource }
        try value.integer(UInt64(source.designRevision.value), work: &work)
        try value.integer(UInt64(source.parameterRevision.value), work: &work)
        for scalar in [source.tolerance.distance, source.tolerance.angle, source.tolerance.relative] { try value.scalar(scalar, work: &work) }
        for gear in [binding.first, binding.second] {
            let occurrence = gear.occurrence
            for text in [occurrence.id, occurrence.sourceFeature.description, occurrence.sourceBody.description,
                         occurrence.body.key, occurrence.frame.key, occurrence.material.id.description,
                         occurrence.material.name] { try value.text(text, work: &work) }
            try value.pose(occurrence.placement, work: &work)
            try value.scalar(occurrence.density, work: &work)
            try value.integer(UInt64(gear.toothCount), work: &work)
            try value.integer(UInt64(gear.maximumSegments), work: &work)
            try value.integer(gear.doubleHelical ? 1 : 0, work: &work)
            for dimension in InvoluteGearFeature.Dimension.allCases {
                guard let scalar = gear.dimensions[dimension] else { throw .incompatibleRecipe }
                try value.text(dimension.rawValue, work: &work); try value.scalar(scalar, work: &work)
            }
            for vector in [gear.localOrigin, gear.worldOrigin, gear.worldAxis, gear.worldToothZero] {
                try value.vector(vector, work: &work)
            }
        }
        for shaft in [binding.request.first, binding.request.second] {
            try value.text(shaft.occurrenceID, work: &work); try value.text(shaft.joint.key, work: &work)
            try value.scalar(shaft.mountingPhase, work: &work)
        }
        for face in [binding.firstEndFace, binding.secondEndFace] {
            let selected = face.anchor.stableReference.subshapeID
            guard selected.ordinal >= 0 else { throw .incompatibleRecipe }
            try value.text(selected.featureID.description, work: &work)
            try value.text(selected.role, work: &work); try value.integer(UInt64(selected.ordinal), work: &work)
            for vector in [face.localPoint, face.localOutwardNormal, face.worldPoint, face.worldOutwardNormal] {
                try value.vector(vector, work: &work)
            }
        }
        try value.scalar(binding.request.phase, work: &work); try value.scalar(binding.request.phaseScale, work: &work)
        try value.integer(binding.network.id, work: &work); try value.integer(binding.request.relationID, work: &work)
        try value.text("idealExternalSpur", work: &work)
        for text in [equations.descriptor.identity, equations.descriptor.chart, binding.model.stamp.identity] {
            try value.text(text, work: &work)
        }
        try value.integer(binding.model.stamp.revision, work: &work)
        let initial = binding.model.descriptor.initialState
        try value.scalar(initial.time, work: &work)
        for scalars in [initial.q, initial.v, initial.acceleration] {
            try value.integer(UInt64(scalars.count), work: &work)
            for scalar in scalars { try value.scalar(scalar, work: &work) }
        }
        return value.bytes
    }
    private mutating func reserve(_ count: Int, work: inout CADAdapterWork) throws(CADGearReinitializationError) {
        let next = bytes.count.addingReportingOverflow(count)
        guard count >= 0, !next.overflow, next.partialValue <= maximumBytes else { throw .capacityExceeded }
        do { try work.charge(count) } catch { throw .cad(error) }
    }
    private mutating func integer(_ number: UInt64, work: inout CADAdapterWork) throws(CADGearReinitializationError) {
        try reserve(8, work: &work)
        for shift in stride(from: 0, to: 64, by: 8) { bytes.append(UInt8(truncatingIfNeeded: number >> shift)) }
    }
    private mutating func scalar(_ number: Double, work: inout CADAdapterWork) throws(CADGearReinitializationError) {
        guard number.isFinite else { throw .invalidInput }
        try integer(number.bitPattern, work: &work)
    }
    private mutating func text(_ text: String, work: inout CADAdapterWork) throws(CADGearReinitializationError) {
        let next = metadata.addingReportingOverflow(text.utf8.count)
        guard !next.overflow, next.partialValue <= maximumMetadataBytes else { throw .capacityExceeded }
        try integer(UInt64(text.utf8.count), work: &work); try reserve(text.utf8.count, work: &work)
        metadata = next.partialValue; bytes.append(contentsOf: text.utf8)
    }
    private mutating func vector(_ vector: Vector3, work: inout CADAdapterWork) throws(CADGearReinitializationError) {
        for scalar in [vector.x, vector.y, vector.z] { try self.scalar(scalar, work: &work) }
    }
    private mutating func pose(_ pose: RigidTransform, work: inout CADAdapterWork) throws(CADGearReinitializationError) {
        try vector(pose.translation, work: &work)
        for scalar in [pose.rotation.w, pose.rotation.x, pose.rotation.y, pose.rotation.z] { try self.scalar(scalar, work: &work) }
    }
}
