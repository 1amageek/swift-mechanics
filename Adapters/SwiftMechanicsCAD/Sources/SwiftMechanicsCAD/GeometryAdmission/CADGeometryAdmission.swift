import CADCore
import CADGeometry
import CADIR
import CADKernel
import CADModeling
import SwiftMechanics

public final class CADGeometryAdmission: CADInvoluteGearQuerying {
    public let identity: CADSourceIdentity
    public let occurrences: [CADOccurrence]
    private let admission: _CADGeometryAdmissionToken

    init(admission: _CADGeometryAdmissionToken) {
        self.admission = admission
        identity = admission.identity
        occurrences = admission.occurrences
    }

    public func involuteGear(occurrenceID: String, expected: CADSourceIdentity,
                             work: inout CADAdapterWork) throws(CADAdapterError) -> CADInvoluteGearWitness {
        let occurrence = try checkedOccurrence(occurrenceID, expected: expected, work: &work)
        try resultAllowed()
        guard let node = admission.snapshot.document.designGraph.nodes[occurrence.sourceFeature],
              case .involuteGear(let feature) = node.operation else { throw .unsupportedSource }
        // Charge owned dimension records; original resolver work is not an adapter work guarantee.
        try work.charge(InvoluteGearFeature.Dimension.allCases.count)
        let dimensions = try cadCall {
            try feature.resolvedDimensions {
                try ParameterResolver().evaluate($0, parameters: admission.snapshot.parameters, variables: [:])
            }
        }
        let origin = try cadCall { try Vector3(feature.origin.x, feature.origin.y, feature.origin.z) }
        let worldOrigin = try cadCall { try occurrence.placement.transforming(point: origin) }
        let axis = try cadCall { try occurrence.placement.transforming(direction: .unitZ) }
        let zero = try cadCall { try occurrence.placement.transforming(direction: .unitX) }
        try work.poll()
        return CADInvoluteGearWitness(admission: _CADInvoluteGearAdmission(source: identity,
            occurrence: occurrence, feature: feature, dimensions: dimensions, localOrigin: origin,
            worldOrigin: worldOrigin, worldAxis: axis, worldToothZero: zero))
    }

    public func anchors(occurrenceID: String, expected: CADSourceIdentity,
                        work: inout CADAdapterWork) throws(CADAdapterError) -> [CADAnchorReference] {
        let occurrence = try checkedOccurrence(occurrenceID, expected: expected, work: &work)
        try work.charge(admission.snapshot.subshapes.entries.count)
        var result: [CADAnchorReference] = []
        for (subshape, topology) in admission.snapshot.subshapes.entries.sorted(by: { $0.key < $1.key }) {
            try work.charge()
            guard admission.ownership[occurrence.sourceBody]?.contains(topology) == true else { continue }
            guard result.count < admission.limits.maximumQueryResults else { throw .capacityExceeded }
            let stable = try cadCall { try admission.snapshot.stableSubshapeReference(for: subshape) }
            result.append(CADAnchorReference(source: identity, occurrenceID: occurrenceID,
                stableReference: stable, topology: topology))
        }
        try work.poll()
        return result
    }

    public func volume(occurrenceID: String, expected: CADSourceIdentity,
                       work: inout CADAdapterWork) throws(CADAdapterError) -> Double {
        let occurrence = try checkedOccurrence(occurrenceID, expected: expected, work: &work)
        try resultAllowed()
        let volume = try cadCall { try admission.snapshot.brep.volume(of: occurrence.sourceBody, tolerance: identity.tolerance) }
        try work.poll()
        return volume
    }

    /// nearestTo is an SI point in the original CAD definition frame.
    public func surfaceAnchor(_ anchor: CADAnchorReference, nearestTo: Vector3,
                              expected: CADSourceIdentity, options: SurfaceProjectionOptions,
                              work: inout CADAdapterWork) throws(CADAdapterError) -> CADSurfaceWitness {
        let occurrence = try checkedAnchor(anchor, expected: expected, work: &work)
        guard case .face = anchor.topology else { throw .wrongAnchor }
        try resultAllowed()
        let original = try cadCall {
            try SurfaceQueryEvaluator(tolerance: identity.tolerance).outwardFrame(
                nearestTo: Point3D(x: nearestTo.x, y: nearestTo.y, z: nearestTo.z),
                on: SurfaceReference(subshape: anchor.stableReference), in: admission.snapshot, options: options)
        }
        let point = try cadCall { try Vector3(original.point.x, original.point.y, original.point.z) }
        let normal = try cadCall { try Vector3(original.outwardNormal.x, original.outwardNormal.y, original.outwardNormal.z) }
        let worldPoint = try cadCall { try occurrence.placement.transforming(point: point) }
        let worldNormal = try cadCall { try occurrence.placement.transforming(direction: normal) }
        try work.poll()
        return CADSurfaceWitness(anchor: anchor, occurrence: occurrence, original: original,
            localPoint: point, localOutwardNormal: normal, worldPoint: worldPoint, worldOutwardNormal: worldNormal)
    }

    public func edgeFrame(_ anchor: CADAnchorReference, parameter: Double,
                          expected: CADSourceIdentity,
                          work: inout CADAdapterWork) throws(CADAdapterError) -> CADEdgeWitness {
        let occurrence = try checkedAnchor(anchor, expected: expected, work: &work)
        guard case .edge = anchor.topology else { throw .wrongAnchor }
        try resultAllowed()
        let original = try cadCall {
            try EdgeQueryEvaluator(tolerance: identity.tolerance).frame(
                at: EdgeParameterReference(edge: EdgeReference(subshape: anchor.stableReference), parameter: parameter),
                in: admission.snapshot)
        }
        let point = try cadCall { try Vector3(original.point.x, original.point.y, original.point.z) }
        let tangent = try cadCall { try Vector3(original.tangent.x, original.tangent.y, original.tangent.z) }
        let worldPoint = try cadCall { try occurrence.placement.transforming(point: point) }
        let worldTangent = try cadCall { try occurrence.placement.transforming(direction: tangent) }
        try work.poll()
        return CADEdgeWitness(anchor: anchor, occurrence: occurrence, original: original,
            localPoint: point, localTangent: tangent, worldPoint: worldPoint, worldTangent: worldTangent)
    }

    // FIXME(INCOMPLETE_IMPLEMENTATION): The pinned CAD public producer supplies no full solid
    // first/second moments. This actual query refuses until CAD-owned exact moments and their
    // successful/failing public path are available; volume or mesh inertia is not completion.
    public func exactMassProperties(occurrenceID: String, expected: CADSourceIdentity,
                                    work: inout CADAdapterWork) throws(CADAdapterError) -> MassProperties3D {
        _ = try checkedOccurrence(occurrenceID, expected: expected, work: &work)
        throw .exactMomentsUnavailable
    }

    private func checkedOccurrence(_ id: String, expected: CADSourceIdentity,
                                   work: inout CADAdapterWork) throws(CADAdapterError) -> CADOccurrence {
        try work.charge()
        guard expected == identity else { throw .staleSource }
        for occurrence in occurrences {
            try work.charge()
            if occurrence.id == id { return occurrence }
        }
        throw .missingOccurrence
    }

    private func checkedAnchor(_ anchor: CADAnchorReference, expected: CADSourceIdentity,
                              work: inout CADAdapterWork) throws(CADAdapterError) -> CADOccurrence {
        let occurrence = try checkedOccurrence(anchor.occurrenceID, expected: expected, work: &work)
        guard anchor.source == identity else { throw .staleSource }
        guard admission.ownership[occurrence.sourceBody]?.contains(anchor.topology) == true else { throw .wrongAnchor }
        let current = try cadCall { try admission.snapshot.stableSubshapeReference(for: anchor.stableReference.subshapeID) }
        guard current == anchor.stableReference else { throw .wrongAnchor }
        let topology = try cadCall { try admission.snapshot.topologyReference(for: anchor.stableReference) }
        guard topology == anchor.topology else { throw .wrongAnchor }
        try work.poll()
        return occurrence
    }

    private func resultAllowed() throws(CADAdapterError) {
        guard admission.limits.maximumQueryResults > 0 else { throw .capacityExceeded }
    }
}

// Only the original retained geometry owner in this file can issue gear evidence.
struct _CADInvoluteGearAdmission: Sendable {
    let source: CADSourceIdentity
    let occurrence: CADOccurrence
    let feature: InvoluteGearFeature
    let dimensions: [InvoluteGearFeature.Dimension: Double]
    let localOrigin: Vector3
    let worldOrigin: Vector3
    let worldAxis: Vector3
    let worldToothZero: Vector3
    fileprivate init(source: CADSourceIdentity, occurrence: CADOccurrence, feature: InvoluteGearFeature,
                     dimensions: [InvoluteGearFeature.Dimension: Double], localOrigin: Vector3,
                     worldOrigin: Vector3, worldAxis: Vector3, worldToothZero: Vector3) {
        self.source = source; self.occurrence = occurrence; self.feature = feature
        self.dimensions = dimensions; self.localOrigin = localOrigin; self.worldOrigin = worldOrigin
        self.worldAxis = worldAxis; self.worldToothZero = worldToothZero
    }
}
