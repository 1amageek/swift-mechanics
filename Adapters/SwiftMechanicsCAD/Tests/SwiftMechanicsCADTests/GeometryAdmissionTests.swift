import Testing
import CADCore
import CADGeometry
import CADTopology
import CADIR
import CADKernel
import SwiftMechanics
import SwiftMechanicsCAD

@Suite struct GeometryAdmissionTests {
    @Test func exactBoxAndRepeatedOccurrenceFrames() throws {
        let document = CADFixtures.box()
        let placement = RigidTransform(rotation: try UnitQuaternion(axis: .unitZ, angle: .pi / 2),
            translation: try Vector3(10, 20, 30))
        let admitted = try CADFixtures.admit(document, requests: [
            CADFixtures.request(document), CADFixtures.request(document, id: "second", placement: placement)])
        let query: any CADGeometryQuerying = admitted
        #expect(query.identity.providerPin == CADSourceIdentity.supportedProviderPin)
        #expect(query.occurrences.count == 2)
        #expect(query.occurrences[0].sourceBody == query.occurrences[1].sourceBody)
        #expect(query.occurrences[0].body != query.occurrences[1].body)
        #expect(query.occurrences[0].frame != query.occurrences[1].frame)
        #expect(query.occurrences[0].density == 7800)
        var work = try CADAdapterWork(maximumVisits: 100_000)
        #expect(abs(try query.volume(occurrenceID: "first", expected: query.identity, work: &work) - 24) < 1e-9)
        #expect(abs(try query.volume(occurrenceID: "second", expected: query.identity, work: &work) - 24) < 1e-9)
        let anchors = try query.anchors(occurrenceID: "second", expected: query.identity, work: &work)
        var positiveX: CADSurfaceWitness?
        var edgeSeen = false
        for anchor in anchors {
            switch anchor.topology {
            case .face:
                let witness = try query.surfaceAnchor(anchor, nearestTo: Vector3(2, 1.5, 2),
                    expected: query.identity, options: SurfaceProjectionOptions(), work: &work)
                if witness.localOutwardNormal.x > 0.99 { positiveX = witness }
            case .edge:
                let witness = try query.edgeFrame(anchor, parameter: 0, expected: query.identity, work: &work)
                #expect(abs(witness.localTangent.x * witness.localTangent.x +
                    witness.localTangent.y * witness.localTangent.y + witness.localTangent.z * witness.localTangent.z - 1) < 1e-9)
                #expect(abs(witness.worldTangent.x + witness.localTangent.y) < 1e-9)
                #expect(abs(witness.worldTangent.y - witness.localTangent.x) < 1e-9)
                edgeSeen = true
            default: break
            }
        }
        let face = try #require(positiveX)
        #expect(abs(face.localPoint.x - 2) < 1e-9)
        #expect(abs(face.worldPoint.x - 8.5) < 1e-9)
        #expect(abs(face.worldPoint.y - 22) < 1e-9)
        #expect(abs(face.worldPoint.z - 32) < 1e-9)
        #expect(abs(face.worldOutwardNormal.y - 1) < 1e-9)
        #expect(abs(face.worldOutwardNormal.x) < 1e-9)
        #expect(edgeSeen)
    }

    @Test func displayUnitsDoNotScaleExactGeometryTwiceAndFreshOwnerMatches() throws {
        let document = CADFixtures.box(unit: .millimeter, units: .millimeters)
        let original = try CADFixtures.admit(document)
        let fresh = try CADFixtures.admit(document)
        var work = try CADAdapterWork(maximumVisits: 100_000)
        #expect(original.identity == fresh.identity)
        #expect(abs(try original.volume(occurrenceID: "first", expected: fresh.identity, work: &work) - 24e-9) < 1e-18)
        let a = try original.anchors(occurrenceID: "first", expected: original.identity, work: &work)
        let b = try fresh.anchors(occurrenceID: "first", expected: fresh.identity, work: &work)
        #expect(a.map(\.stableReference) == b.map(\.stableReference))
        let cylinderID = FeatureID()
        let cylinder = FeatureNode(id: cylinderID,
            operation: .primitive(PrimitiveFeature(definition: .cylinder(CylinderPrimitive(
                radius: .constant(.length(1, unit: .meter)), height: .constant(.length(2, unit: .meter)))))),
            outputs: [FeatureOutput(role: .body)])
        let cylindrical = try CADFixtures.admit(CADDocument(units: .meters,
            designGraph: DesignGraph(nodes: [cylinderID: cylinder], order: [cylinderID])))
        #expect(abs(try cylindrical.volume(occurrenceID: "first", expected: cylindrical.identity, work: &work) - 2 * .pi) < 1e-9)
        #expect(CADFixtures.refuses({ _ = try original.exactMassProperties(occurrenceID: "first",
            expected: original.identity, work: &work) }, matching: { if case .exactMomentsUnavailable = $0 { true } else { false } }))
    }

    @Test func eachSourceIdentityFieldGatesQueryBeforeSelection() throws {
        let owner = try CADFixtures.admit(CADFixtures.box())
        let i = owner.identity
        let wrong = [
            CADFixtures.changed(i, pin: "other-pin"),
            CADFixtures.changed(i, document: DocumentID()),
            CADFixtures.changed(i, design: i.designRevision.advanced()),
            CADFixtures.changed(i, parameters: i.parameterRevision.advanced()),
            CADFixtures.changed(i, fingerprint: CADDocumentSourceFingerprint(algorithm: i.fingerprint.algorithm, value: "changed")),
            CADFixtures.changed(i, units: .millimeters),
            CADFixtures.changed(i, tolerance: ModelingTolerance(distance: 2e-6, angle: 1e-9))]
        var work = try CADAdapterWork(maximumVisits: 100_000)
        for expected in wrong {
            #expect(CADFixtures.refuses({ _ = try owner.anchors(occurrenceID: "missing", expected: expected, work: &work) },
                matching: { if case .staleSource = $0 { true } else { false } }))
        }
    }

    @Test func sameIDShapeEditOriginalResolverAcceptsButAdapterRefuses() throws {
        let feature = FeatureID(), document = DocumentID()
        let old = CADFixtures.box(featureID: feature, documentID: document)
        let changed = CADFixtures.box(3, featureID: feature, documentID: document)
        let first = try CADFixtures.admit(old), second = try CADFixtures.admit(changed)
        let rawFirst = try DocumentEvaluator(tolerance: CADFixtures.tolerance).evaluateExact(old)
        let rawSecond = try DocumentEvaluator(tolerance: CADFixtures.tolerance).evaluateExact(changed)
        var work = try CADAdapterWork(maximumVisits: 100_000)
        let anchors = try first.anchors(occurrenceID: "first", expected: first.identity, work: &work)
        guard let face = try anchors.first(where: { anchor in
            guard case .face = anchor.topology else { return false }
            let current = try rawSecond.stableSubshapeReference(for: anchor.stableReference.subshapeID)
            return current.geometrySignature != anchor.stableReference.geometrySignature
        }) else {
            throw CADFixtures.FixtureFailure.missingAnchor
        }
        #expect(try rawSecond.topologyReference(for: face.stableReference) == rawFirst.topologyReference(for: face.stableReference))
        #expect(first.identity.fingerprint != second.identity.fingerprint)
        #expect(CADFixtures.refuses({ _ = try second.surfaceAnchor(face, nearestTo: .zero,
            expected: first.identity, options: SurfaceProjectionOptions(), work: &work) },
            matching: { if case .staleSource = $0 { true } else { false } }))
        #expect(CADFixtures.refuses({ _ = try second.surfaceAnchor(face, nearestTo: .zero,
            expected: second.identity, options: SurfaceProjectionOptions(), work: &work) },
            matching: { if case .staleSource = $0 { true } else { false } }))
        let current = try rawSecond.stableSubshapeReference(for: face.stableReference.subshapeID)
        #expect(current.geometrySignature != face.stableReference.geometrySignature)
        let rewrapped = CADAnchorReference(source: second.identity, occurrenceID: face.occurrenceID,
            stableReference: face.stableReference, topology: face.topology)
        #expect(CADFixtures.refuses({ _ = try second.surfaceAnchor(rewrapped, nearestTo: .zero,
            expected: second.identity, options: SurfaceProjectionOptions(), work: &work) },
            matching: { if case .wrongAnchor = $0 { true } else { false } }))
    }

    @Test func crossBodyMissingAndForgedAnchorsRefuse() throws {
        var document = CADFixtures.box()
        let other = CADFixtures.box(5)
        let otherFeature = try #require(other.designGraph.order.first)
        let firstFeature = try #require(document.designGraph.order.first)
        document.designGraph.nodes[otherFeature] = other.designGraph.nodes[otherFeature]
        document.designGraph.order.append(otherFeature)
        let first = try CADFixtures.request(document)
        let second = CADOccurrenceRequest(id: "second", sourceFeature: otherFeature,
            body: try EntityID(kind: .body, key: "second"), frame: try EntityID(kind: .frame, key: "second"),
            placement: .identity, material: CADFixtures.material())
        let owner = try CADFixtures.admit(document, requests: [first, second])
        var work = try CADAdapterWork(maximumVisits: 100_000)
        let anchor = try #require(owner.anchors(occurrenceID: "first", expected: owner.identity, work: &work)
            .first(where: { if case .face = $0.topology { true } else { false } }))
        let cross = CADAnchorReference(source: owner.identity, occurrenceID: "second",
            stableReference: anchor.stableReference, topology: anchor.topology)
        #expect(CADFixtures.refuses({ _ = try owner.surfaceAnchor(cross, nearestTo: .zero,
            expected: owner.identity, options: SurfaceProjectionOptions(), work: &work) },
            matching: { if case .wrongAnchor = $0 { true } else { false } }))
        let missing = CADAnchorReference(source: owner.identity, occurrenceID: "first",
            stableReference: StableSubshapeReference(subshapeID: SubshapeID(featureID: firstFeature, role: "deleted", ordinal: 99),
                geometrySignature: anchor.stableReference.geometrySignature), topology: anchor.topology)
        #expect(CADFixtures.refuses({ _ = try owner.surfaceAnchor(missing, nearestTo: .zero,
            expected: owner.identity, options: SurfaceProjectionOptions(), work: &work) },
            matching: { if case .kernel = $0 { true } else { false } }))
        let forged = CADAnchorReference(source: owner.identity, occurrenceID: "first",
            stableReference: StableSubshapeReference(subshapeID: anchor.stableReference.subshapeID,
                geometrySignature: .vertex(point: .origin)), topology: anchor.topology)
        #expect(CADFixtures.refuses({ _ = try owner.surfaceAnchor(forged, nearestTo: .zero,
            expected: owner.identity, options: SurfaceProjectionOptions(), work: &work) },
            matching: { if case .wrongAnchor = $0 { true } else { false } }))
        #expect(CADFixtures.refuses({ _ = try owner.volume(occurrenceID: "missing", expected: owner.identity, work: &work) },
            matching: { if case .missingOccurrence = $0 { true } else { false } }))
    }

    @Test func invalidSourceAndOccurrenceMappingNeverPublish() throws {
        let document = CADFixtures.box()
        let request = try CADFixtures.request(document)
        #expect(CADFixtures.refuses({ _ = try CADFixtures.admit(document, requests: [request, request]) },
            matching: { if case .duplicateOccurrence = $0 { true } else { false } }))
        let second = CADOccurrenceRequest(id: "different", sourceFeature: request.sourceFeature,
            body: request.body, frame: request.frame, placement: .identity, material: request.material)
        #expect(CADFixtures.refuses({ _ = try CADFixtures.admit(document, requests: [request, second]) },
            matching: { if case .duplicateOccurrence = $0 { true } else { false } }))
        #expect(CADFixtures.refuses({ _ = try CADFixtures.admit(document, requests: [CADFixtures.request(document,
            material: CADFixtures.material(density: nil))]) }, matching: { if case .missingDensity = $0 { true } else { false } }))
        #expect(CADFixtures.refuses({ _ = try CADFixtures.admit(document, requests: [CADFixtures.request(document,
            material: CADFixtures.material(density: -1))]) }, matching: { if case .material = $0 { true } else { false } }))
        #expect(CADFixtures.refuses({ _ = try CADFixtures.admit(CADFixtures.box(-1)) },
            matching: { if case .feature = $0 { true } else { false } }))
        var suppressed = document
        var node = try #require(suppressed.designGraph.nodes[request.sourceFeature])
        node.isSuppressed = true
        suppressed.designGraph.nodes[request.sourceFeature] = node
        #expect(CADFixtures.refuses({ _ = try CADFixtures.admit(suppressed) },
            matching: { if case .unsupportedSource = $0 { true } else { false } }))
        node.isSuppressed = false
        node.inputs = [FeatureInput(featureID: request.sourceFeature, role: .body)]
        suppressed.designGraph.nodes[request.sourceFeature] = node
        #expect(CADFixtures.refuses({ _ = try CADFixtures.admit(suppressed) },
            matching: { if case .unsupportedSource = $0 { true } else { false } }))
    }

    @Test func ownedLimitsAndCancellationRefuseWithoutAdmission() throws {
        let document = CADFixtures.box()
        for limits in [try CADFixtures.limits(features: 0), try CADFixtures.limits(expressionNodes: 0),
                       try CADFixtures.limits(depth: 0), try CADFixtures.limits(metadata: 0),
                       try CADFixtures.limits(topology: 0)] {
            #expect(CADFixtures.refuses({ _ = try CADFixtures.admit(document, limits: limits) },
                matching: { if case .capacityExceeded = $0 { true } else { false } }))
        }
        var deep = document
        let featureID = try #require(document.designGraph.order.first)
        let expression = CADExpression.add(.constant(.length(1, unit: .meter)), .constant(.length(1, unit: .meter)))
        deep.designGraph.nodes[featureID] = FeatureNode(id: featureID,
            operation: .primitive(PrimitiveFeature(definition: .box(BoxPrimitive(width: expression,
                depth: .constant(.length(3, unit: .meter)), height: .constant(.length(4, unit: .meter)))))),
            outputs: [FeatureOutput(role: .body)])
        #expect(CADFixtures.refuses({ _ = try CADFixtures.admit(deep, limits: CADFixtures.limits(depth: 1)) },
            matching: { if case .capacityExceeded = $0 { true } else { false } }))
        var work = try CADAdapterWork(maximumVisits: 1)
        #expect(CADFixtures.refuses({ _ = try ReferenceCADGeometryAdmitter().admit(document: document,
            occurrences: [CADFixtures.request(document)], tolerance: CADFixtures.tolerance,
            limits: CADFixtures.limits(), work: &work) }, matching: { if case .capacityExceeded = $0 { true } else { false } }))
        #expect(work.visits == 1)
        var cancelled = try CADAdapterWork(maximumVisits: 100_000, isCancelled: { true })
        #expect(CADFixtures.refuses({ _ = try ReferenceCADGeometryAdmitter().admit(document: document,
            occurrences: [CADFixtures.request(document)], tolerance: CADFixtures.tolerance,
            limits: CADFixtures.limits(), work: &cancelled) }, matching: { if case .cancelled = $0 { true } else { false } }))
        #expect(cancelled.visits == 0)
        let owner = try CADFixtures.admit(document, limits: CADFixtures.limits(results: 0))
        var queryWork = try CADAdapterWork(maximumVisits: 100_000)
        #expect(CADFixtures.refuses({ _ = try owner.anchors(occurrenceID: "first", expected: owner.identity, work: &queryWork) },
            matching: { if case .capacityExceeded = $0 { true } else { false } }))
        #expect(CADFixtures.refuses({ _ = try owner.volume(occurrenceID: "first", expected: owner.identity, work: &cancelled) },
            matching: { if case .cancelled = $0 { true } else { false } }))
    }

    @Test func cancellationAfterPositiveWorkAndAfterActualQueryReturnsNoValue() throws {
        guard #available(macOS 15, *) else { return }
        let document = CADFixtures.box()
        let admissionCancellation = PollCancellation(successfulPolls: 1)
        var work = try CADAdapterWork(maximumVisits: 100_000,
            isCancelled: { admissionCancellation.cancelled() })
        #expect(CADFixtures.refuses({ _ = try ReferenceCADGeometryAdmitter().admit(document: document,
            occurrences: [CADFixtures.request(document)], tolerance: CADFixtures.tolerance,
            limits: CADFixtures.limits(), work: &work) }, matching: { if case .cancelled = $0 { true } else { false } }))
        #expect(work.visits == 1)
        let owner = try CADFixtures.admit(document)
        let queryCancellation = PollCancellation(successfulPolls: 2)
        var queryWork = try CADAdapterWork(maximumVisits: 100_000,
            isCancelled: { queryCancellation.cancelled() })
        // Two polls admit the identity and occurrence; the third follows original CAD volume.
        #expect(CADFixtures.refuses({ _ = try owner.volume(occurrenceID: "first", expected: owner.identity,
            work: &queryWork) }, matching: { if case .cancelled = $0 { true } else { false } }))
        #expect(queryWork.visits == 2)
    }

    @Test func genuineGearSourceUsesOriginalProfileAndSweep() throws {
        let document = try CADFixtures.gear()
        let owner = try CADFixtures.admit(document)
        let original = try DocumentEvaluator(tolerance: CADFixtures.tolerance).evaluateExact(document)
        let edgeQuery = EdgeQueryEvaluator(tolerance: CADFixtures.tolerance)
        var work = try CADAdapterWork(maximumVisits: 2_000_000)
        let anchors = try owner.anchors(occurrenceID: "first", expected: owner.identity, work: &work)
        var minimum = Double.infinity, maximum = -Double.infinity
        var faces = 0
        for anchor in anchors {
            if case .face = anchor.topology { faces += 1 }
            if case .edge = anchor.topology {
                let resolved = try edgeQuery.resolve(EdgeReference(subshape: anchor.stableReference), in: original)
                let witness = try owner.edgeFrame(anchor, parameter: resolved.startParameter,
                    expected: owner.identity, work: &work)
                #expect(abs(witness.localPoint.x - resolved.startPoint.x) < 1e-8)
                #expect(abs(witness.localPoint.y - resolved.startPoint.y) < 1e-8)
                #expect(abs(witness.localPoint.z - resolved.startPoint.z) < 1e-8)
                minimum = min(minimum, witness.localPoint.z)
                maximum = max(maximum, witness.localPoint.z)
            }
        }
        #expect(faces > 32)
        #expect(abs(minimum) < 1e-9)
        #expect(abs(maximum - 0.01) < 1e-9)
        #expect(CADFixtures.refuses({ _ = try owner.exactMassProperties(occurrenceID: "first", expected: owner.identity, work: &work) },
            matching: { if case .exactMomentsUnavailable = $0 { true } else { false } }))
    }
}
