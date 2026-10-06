import Foundation
import CADCore
import CADGeometry
import CADTopology
import CADIR
import CADModeling
import CADKernel
import SwiftMechanics
import SwiftMechanicsCAD

struct CADFixtures {
    static let tolerance = ModelingTolerance.standard

    static func limits(features: Int = 4, expressionNodes: Int = 256, depth: Int = 32,
                       metadata: Int = 4096, topology: Int = 200_000,
                       results: Int = 20_000) throws -> CADGeometryLimits {
        try CADGeometryLimits(maximumFeatures: features, maximumParameters: 16,
            maximumOccurrences: 8, maximumExpressionNodes: expressionNodes,
            maximumExpressionDepth: depth, maximumMetadataBytes: metadata,
            maximumTopologyRecords: topology, maximumQueryResults: results)
    }

    static func box(_ width: Double = 2, featureID: FeatureID = FeatureID(),
                    documentID: DocumentID = DocumentID(), unit: LengthUnit = .meter,
                    units: UnitSystem = .meters) -> CADDocument {
        let primitive = BoxPrimitive(width: .constant(.length(width, unit: unit)),
            depth: .constant(.length(3, unit: unit)), height: .constant(.length(4, unit: unit)))
        let feature = FeatureNode(id: featureID, operation: .primitive(PrimitiveFeature(definition: .box(primitive))),
            outputs: [FeatureOutput(role: .body)])
        return CADDocument(id: documentID, units: units,
            designGraph: DesignGraph(nodes: [featureID: feature], order: [featureID]))
    }

    static func material(density: Double? = 7800) -> Material {
        Material(name: "steel", baseColor: ColorRGBA(r: 0.5, g: 0.5, b: 0.5, a: 1),
            metallic: 1, roughness: 0.5, opacity: 1, density: density)
    }

    static func request(_ document: CADDocument, id: String = "first",
                        placement: RigidTransform = .identity, material: Material? = nil) throws -> CADOccurrenceRequest {
        guard let feature = document.designGraph.order.first else { throw FixtureFailure.missingFeature }
        return CADOccurrenceRequest(id: id, sourceFeature: feature,
            body: try EntityID(kind: .body, key: id + "-body"),
            frame: try EntityID(kind: .frame, key: id + "-frame"),
            placement: placement, material: material ?? self.material())
    }

    static func admit(_ document: CADDocument, requests: [CADOccurrenceRequest]? = nil,
                      limits: CADGeometryLimits? = nil) throws -> CADGeometryAdmission {
        var work = try CADAdapterWork(maximumVisits: 2_000_000)
        let producer: any CADGeometryAdmitting = ReferenceCADGeometryAdmitter()
        return try producer.admit(document: document, occurrences: requests ?? [request(document)],
            tolerance: tolerance, limits: limits ?? self.limits(), work: &work)
    }

    static func changed(_ source: CADSourceIdentity, pin: String? = nil,
                        document: DocumentID? = nil, design: DocumentRevision? = nil,
                        parameters: DocumentRevision? = nil,
                        fingerprint: CADDocumentSourceFingerprint? = nil,
                        units: UnitSystem? = nil, tolerance: ModelingTolerance? = nil) -> CADSourceIdentity {
        CADSourceIdentity(providerPin: pin ?? source.providerPin, documentID: document ?? source.documentID,
            designRevision: design ?? source.designRevision, parameterRevision: parameters ?? source.parameterRevision,
            fingerprint: fingerprint ?? source.fingerprint, units: units ?? source.units,
            tolerance: tolerance ?? source.tolerance)
    }

    static func refuses(_ operation: () throws -> Void, matching: (CADAdapterError) -> Bool) -> Bool {
        do { try operation(); return false }
        catch let error as CADAdapterError { return matching(error) }
        catch { return false }
    }

    static func gear() throws -> CADDocument {
        let gear = InvoluteGearFeature(toothCount: 32, dimensions: [
            .baseRadius: .constant(.length(0.032 * cos(.pi / 9), unit: .meter)),
            .pitchRadius: .constant(.length(0.032, unit: .meter)),
            .tipRadius: .constant(.length(0.034, unit: .meter)),
            .rootRadius: .constant(.length(0.0295, unit: .meter)),
            .filletRadius: .constant(.length(0.00076, unit: .meter)),
            .pitchToothAngle: .constant(.angle(.pi / 32, unit: .radian)),
            .width: .constant(.length(0.01, unit: .meter)),
            .twistAngle: .constant(.angle(0, unit: .radian)),
            .profileError: .constant(.length(1e-7, unit: .meter)),
            .sweepError: .constant(.length(1e-6, unit: .meter))
        ], doubleHelical: false)
        var document = CADDocument(units: .meters)
        let feature = try FeatureNodeFactory.make(operation: .involuteGear(gear), in: document, tolerance: tolerance)
        document.designGraph = DesignGraph(nodes: [feature.id: feature], order: [feature.id])
        return document
    }

    enum FixtureFailure: Error { case missingFeature, missingAnchor }
}
