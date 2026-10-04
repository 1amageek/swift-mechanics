import CADCore
import CADIR
import CADKernel
import CADModeling
import CADTopology

public struct ReferenceCADGeometryAdmitter: CADGeometryAdmitting {
    public init() {}

    public func admit(document: CADDocument, occurrences: [CADOccurrenceRequest],
                      tolerance: ModelingTolerance, limits: CADGeometryLimits,
                      work: inout CADAdapterWork) throws(CADAdapterError) -> CADGeometryAdmission {
        var preflight = CADSourcePreflight(limits: limits)
        try preflight.validate(document, requests: occurrences, work: &work)
        try cadCall { try tolerance.validate() }
        try work.poll()
        let evaluated = try cadCall { try DocumentEvaluator(tolerance: tolerance).evaluateExact(document) }
        try work.poll()
        try checkTopology(evaluated, limits: limits, work: &work)
        try cadCall { try evaluated.brep.validate(level: .exact, tolerance: tolerance) }
        try cadCall { try evaluated.subshapes.validate(against: evaluated.brep, lineage: evaluated.lineage) }
        let fingerprint = try cadCall { try document.sourceFingerprint(tolerance: tolerance) }
        let identity = CADSourceIdentity(providerPin: CADSourceIdentity.supportedProviderPin,
            documentID: document.id, designRevision: document.designGraph.revision,
            parameterRevision: document.parameters.revision, fingerprint: fingerprint,
            units: document.units, tolerance: tolerance)
        var admitted: [CADOccurrence] = []
        var ownership: [BodyID: Set<TopologyReference>] = [:]
        for request in occurrences {
            try work.charge()
            var bodyID: BodyID?
            for (subshape, reference) in evaluated.subshapes.entries {
                try work.charge()
                if subshape.featureID == request.sourceFeature, case .body(let candidate) = reference {
                    guard bodyID == nil else { throw .ambiguousBody }
                    bodyID = candidate
                }
            }
            guard let bodyID, let body = evaluated.brep.bodies[bodyID] else { throw .missingBody }
            guard body.material == nil || body.material == request.material.id else { throw .contradictoryMaterial }
            guard let density = request.material.density else { throw .missingDensity }
            if ownership[bodyID] == nil {
                ownership[bodyID] = try ownedTopology(body, model: evaluated.brep, work: &work)
            }
            admitted.append(CADOccurrence(request: request, sourceBody: bodyID, density: density))
        }
        try work.poll()
        return CADGeometryAdmission(admission: _CADGeometryAdmissionToken(snapshot: evaluated,
            identity: identity, occurrences: admitted, ownership: ownership, limits: limits))
    }

    private func checkTopology(_ snapshot: EvaluatedDocument, limits: CADGeometryLimits,
                               work: inout CADAdapterWork) throws(CADAdapterError) {
        let b = snapshot.brep
        var count = 0
        for next in [b.bodies.count, b.shells.count, b.faces.count, b.loops.count,
                     b.edges.count, b.vertices.count, b.geometry.curves.count,
                     b.geometry.surfaces.count, snapshot.subshapes.entries.count, snapshot.lineage.count] {
            let sum = count.addingReportingOverflow(next)
            guard !sum.overflow, sum.partialValue <= limits.maximumTopologyRecords else { throw .capacityExceeded }
            count = sum.partialValue
        }
        // References are owned records as well as table entries.
        for shell in b.shells.values {
            try work.charge()
            let sum = count.addingReportingOverflow(shell.faceIDs.count)
            guard !sum.overflow, sum.partialValue <= limits.maximumTopologyRecords else { throw .capacityExceeded }
            count = sum.partialValue
        }
        for face in b.faces.values {
            try work.charge()
            let sum = count.addingReportingOverflow(face.loops.count)
            guard !sum.overflow, sum.partialValue <= limits.maximumTopologyRecords else { throw .capacityExceeded }
            count = sum.partialValue
        }
        for loop in b.loops.values {
            try work.charge()
            let sum = count.addingReportingOverflow(loop.coedges.count)
            guard !sum.overflow, sum.partialValue <= limits.maximumTopologyRecords else { throw .capacityExceeded }
            count = sum.partialValue
        }
        try work.charge(count)
    }

    private func ownedTopology(_ body: Body, model: BRepModel,
                               work: inout CADAdapterWork) throws(CADAdapterError) -> Set<TopologyReference> {
        var result: Set<TopologyReference> = [.body(body.id)]
        for shellID in body.shellIDs {
            try work.charge()
            guard let shell = model.shells[shellID] else { throw .wrongAnchor }
            for faceID in shell.faceIDs {
                try work.charge()
                guard let face = model.faces[faceID] else { throw .wrongAnchor }
                result.insert(.face(faceID))
                for loopID in face.loops {
                    try work.charge()
                    guard let loop = model.loops[loopID] else { throw .wrongAnchor }
                    for coedge in loop.coedges {
                        try work.charge()
                        guard let edge = model.edges[coedge.edgeID] else { throw .wrongAnchor }
                        result.insert(.edge(edge.id))
                        result.insert(.vertex(edge.startVertexID))
                        result.insert(.vertex(edge.endVertexID))
                    }
                }
            }
        }
        return result
    }
}

// Only this file can issue the immutable owner construction evidence.
struct _CADGeometryAdmissionToken: Sendable {
    let snapshot: EvaluatedDocument
    let identity: CADSourceIdentity
    let occurrences: [CADOccurrence]
    let ownership: [BodyID: Set<TopologyReference>]
    let limits: CADGeometryLimits

    fileprivate init(snapshot: EvaluatedDocument, identity: CADSourceIdentity,
                     occurrences: [CADOccurrence], ownership: [BodyID: Set<TopologyReference>],
                     limits: CADGeometryLimits) {
        self.snapshot = snapshot
        self.identity = identity
        self.occurrences = occurrences
        self.ownership = ownership
        self.limits = limits
    }
}
