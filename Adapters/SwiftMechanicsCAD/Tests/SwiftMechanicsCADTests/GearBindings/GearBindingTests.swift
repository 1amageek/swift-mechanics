import Testing
import CADCore
import CADGeometry
import CADIR
import CADKernel
import SwiftMechanics
import SwiftMechanicsCAD

@Suite struct GearBindingTests {
    @Test func originalParameterResolutionAndSourceGates() throws {
        guard #available(macOS 15, *) else { return }
        let fixture = try GearBindingFixtures(document: GearBindingFixtures.source(parameters: true))
        let query: any CADInvoluteGearQuerying = fixture.geometry
        var work = try CADAdapterWork(maximumVisits: 100_000)
        let gear = try query.involuteGear(occurrenceID: "first", expected: query.identity, work: &work)
        #expect(gear.toothCount == 20)
        #expect(abs(try #require(gear.dimensions[.pitchRadius]) - 0.02) < 1e-14)
        #expect(abs(try #require(gear.dimensions[.pitchToothAngle]) - .pi / 20) < 1e-14)
        #expect(gear.dimensions.count == 10)
        #expect(gear.maximumSegments == 4096 && !gear.doubleHelical)
        #expect(gear.source == fixture.geometry.identity)
        #expect(gear.occurrence.frame == fixture.geometry.occurrences[0].frame)
        let i = query.identity
        let wrong = [CADFixtures.changed(i, pin: "wrong"), CADFixtures.changed(i, document: DocumentID()),
            CADFixtures.changed(i, design: i.designRevision.advanced()), CADFixtures.changed(i, parameters: i.parameterRevision.advanced()),
            CADFixtures.changed(i, fingerprint: CADDocumentSourceFingerprint(algorithm: i.fingerprint.algorithm, value: "changed")),
            CADFixtures.changed(i, units: .meters), CADFixtures.changed(i, tolerance: ModelingTolerance(distance: 2e-6, angle: 1e-9))]
        for expected in wrong {
            #expect(CADFixtures.refuses({ _ = try query.involuteGear(occurrenceID: "missing", expected: expected, work: &work) },
                matching: { if case .staleSource = $0 { true } else { false } }))
        }
        #expect(CADFixtures.refuses({ _ = try query.involuteGear(occurrenceID: "missing", expected: i, work: &work) },
            matching: { if case .missingOccurrence = $0 { true } else { false } }))
        let box = try CADFixtures.admit(CADFixtures.box())
        #expect(CADFixtures.refuses({ _ = try box.involuteGear(occurrenceID: "first", expected: box.identity, work: &work) },
            matching: { if case .unsupportedSource = $0 { true } else { false } }))
    }

    @Test func actualMotionAndIndependentMassWeightedLoadOracle() throws {
        guard #available(macOS 15, *) else { return }
        for nonidentity in [false, true] {
            let fixture = try GearBindingFixtures(nonidentity: nonidentity, q: [0.3, -0.15])
            let binding = try fixture.bind(), policy = try GearBindingFixtures.transmissionPolicy()
            #expect(binding.network.ports.map(\.coordinateIndex) == [0, 1])
            #expect(binding.network.ports.map(\.coordinateID) == [10, 20])
            #expect(binding.network.ports.allSatisfy { $0.frame == fixture.model.tree.worldFrame })
            #expect(binding.network.physicalRows[0].coefficients == [20, 40])
            let snapshot = try binding.model.evaluate(binding.state)
            let axis = binding.first.worldAxis
            let first = try snapshot.body(GearBindingFixtures.id(.body, "first"))
            let second = try snapshot.body(GearBindingFixtures.id(.body, "second"))
            #expect(try first.motion.velocity.angular.subtracting(axis.scaled(by: 2)).magnitude() < 1e-10)
            #expect(try second.motion.velocity.angular.subtracting(axis.scaled(by: -1)).magnitude() < 1e-10)
            #expect(try first.motion.pose.translation.subtracting(binding.first.worldOrigin).magnitude() < 1e-10)
            #expect(try second.motion.pose.translation.subtracting(binding.second.worldOrigin).magnitude() < 1e-10)
            let system = try fixture.system()
            #expect(abs(system.massMatrix[0] - 2) < 1e-9 && abs(system.massMatrix[3] - 3) < 1e-9)
            var e = try GearBindingFixtures.work()
            let evaluation = try QuadraticConstraintEvaluator().evaluate(binding.network.equations,
                position: binding.state.state.q, velocity: binding.state.state.v, time: 0,
                policy: ConstraintEvaluationPolicy(maximumCoordinates: 8, maximumRows: 8, expectedLayoutRevision: 1), work: &e)
            var w = try GearBindingFixtures.work(), d = try GearBindingFixtures.work(), r = try GearBindingFixtures.work(), l = try GearBindingFixtures.work()
            let motion = try MassWeightedMechanismSolver().acceleration(system,
                sample: VelocityConstraintSample(layout: binding.network.equations.layout, holonomic: evaluation),
                drive: [1, 0], policy: GearBindingFixtures.solvePolicy(), work: &w, dynamicsWork: &d, rankWork: &r, linearWork: &l)
            var diagnosisWork = try GearBindingFixtures.work()
            let result = try AffineMechanismTransmissionDiagnostics().diagnose(binding.network,
                position: binding.state.state.q, velocity: binding.state.state.v, motion: motion,
                policy: policy, work: &diagnosisWork)
            #expect(abs(motion.values[0] - 4.0 / 11) < 1e-9 && abs(motion.values[1] + 2.0 / 11) < 1e-9)
            #expect(abs(result.ports[0].generalizedEffort + 3.0 / 11) < 1e-9)
            #expect(abs(result.ports[1].generalizedEffort + 6.0 / 11) < 1e-9)
            #expect(try result.ports[0].wrenchAboutReferenceOrigin.torque.subtracting(axis.scaled(by: -3.0 / 11)).magnitude() < 1e-9)
            #expect(try result.ports[1].wrenchAboutReferenceOrigin.torque.subtracting(axis.scaled(by: -6.0 / 11)).magnitude() < 1e-9)
            #expect(abs(result.totalPower) < 1e-9)
            let kineticDerivative = 2 * 2 * motion.values[0] + 3 * (-1) * motion.values[1]
            #expect(abs(kineticDerivative - 2) < 1e-9)
            #expect(result.originalPhaseResidual < 1e-9 && result.originalSpeedResidual < 1e-9)
            #expect(motion.originalRowResidual < 1e-9 && motion.originalPhysicalResidual < 1e-9)
            for body in fixture.model.descriptor.bodies {
                if case .spatial(let source) = body { #expect(source.inertia?.properties.origin == .supplied) }
            }
        }
    }

    @Test func repeatedOriginalGearHasDistinctActualShafts() throws {
        guard #available(macOS 15, *) else { return }
        let fixture = try GearBindingFixtures(spacing: 0.04, v: [1, -1], repeated: true)
        let binding = try fixture.bind()
        #expect(binding.first.occurrence.sourceBody == binding.second.occurrence.sourceBody)
        #expect(binding.first.occurrence.body != binding.second.occurrence.body)
        #expect(binding.first.occurrence.frame != binding.second.occurrence.frame)
        #expect(binding.network.ports[0].joint != binding.network.ports[1].joint)
        #expect(binding.network.physicalRows[0].coefficients == [20, 20])
    }

    @Test func geometricAndFidelityFailuresNeverBind() throws {
        guard #available(macOS 15, *) else { return }
        let spacing = try GearBindingFixtures(spacing: 0.07)
        #expect(GearBindingFixtures.refuses({ _ = try spacing.bind() }, matching: { if case .incompatibleSpacing = $0 { true } else { false } }))
        let axis = try GearBindingFixtures(secondAxis: .unitX)
        #expect(GearBindingFixtures.refuses({ _ = try axis.bind() }, matching: { if case .incompatibleAxis = $0 { true } else { false } }))
        let module = try GearBindingFixtures(document: GearBindingFixtures.source(secondRadius: 0.042))
        #expect(GearBindingFixtures.refuses({ _ = try module.bind() }, matching: { if case .incompatibleModule = $0 { true } else { false } }))
        let helical = try GearBindingFixtures(document: GearBindingFixtures.source(twist: 0.2))
        #expect(GearBindingFixtures.refuses({ _ = try helical.bind() }, matching: { if case .unsupportedFidelity = $0 { true } else { false } }))
        #expect(GearBindingFixtures.refuses({ _ = try spacing.bind(spacing.request(fidelity: .toothResolved)) },
            matching: { if case .unsupportedFidelity = $0 { true } else { false } }))
    }

    @Test func sourceAnchorMountingAndOriginalPhaseRefuse() throws {
        guard #available(macOS 15, *) else { return }
        let fixture = try GearBindingFixtures()
        #expect(GearBindingFixtures.refuses({ _ = try fixture.bind(fixture.request(source:
            CADFixtures.changed(fixture.geometry.identity, pin: "wrong"))) }, matching: { if case .staleSource = $0 { true } else { false } }))
        let missing = try CADGearShaftRequest(occurrenceID: "first", joint: GearBindingFixtures.id(.joint, "missing"),
            endFace: fixture.first.endFace, mountingPhase: 0)
        #expect(GearBindingFixtures.refuses({ _ = try fixture.bind(fixture.request(first: missing)) }, matching: { if case .missingShaft = $0 { true } else { false } }))
        let mount = try CADGearShaftRequest(occurrenceID: "first", joint: fixture.first.joint,
            endFace: fixture.first.endFace, mountingPhase: 0.1)
        #expect(GearBindingFixtures.refuses({ _ = try fixture.bind(fixture.request(first: mount)) }, matching: { if case .incompatibleMountingPhase = $0 { true } else { false } }))
        let cross = CADAnchorReference(source: fixture.geometry.identity, occurrenceID: "first",
            stableReference: fixture.second.endFace.stableReference, topology: fixture.second.endFace.topology)
        let wrongAnchor = try CADGearShaftRequest(occurrenceID: "first", joint: fixture.first.joint, endFace: cross, mountingPhase: 0)
        #expect(GearBindingFixtures.refuses({ _ = try fixture.bind(fixture.request(first: wrongAnchor)) },
            matching: { if case .cad(.wrongAnchor) = $0 { true } else { false } }))
        #expect(GearBindingFixtures.refuses({ _ = try fixture.bind(fixture.request(second: fixture.first)) },
            matching: { if case .duplicateShaft = $0 { true } else { false } }))
        #expect(GearBindingFixtures.refuses({ _ = try fixture.bind(fixture.request(phase: 1)) },
            matching: { if case .transmission(.originalResidual) = $0 { true } else { false } }))
    }

    @Test func boundedCancellationRetainsOwnedFailurePrefix() throws {
        guard #available(macOS 15, *) else { return }
        let fixture = try GearBindingFixtures()
        for policy in [try GearBindingFixtures.policy(records: 0), try GearBindingFixtures.policy(metadata: 0)] {
            #expect(GearBindingFixtures.refuses({ _ = try fixture.bind(policy: policy) },
                matching: { if case .capacityExceeded = $0 { true } else { false } }))
        }
        let cancel = PollCancellation(successfulPolls: 1)
        var work = try CADAdapterWork(maximumVisits: 100_000, isCancelled: { cancel.cancelled() })
        var numerical = try GearBindingFixtures.work()
        #expect(GearBindingFixtures.refuses({ _ = try ReferenceCADGearBindingPreparer().bind(fixture.request(),
            geometry: fixture.geometry, model: fixture.model, state: fixture.state, layout: fixture.layout,
            policy: GearBindingFixtures.policy(), transmissionPolicy: GearBindingFixtures.transmissionPolicy(),
            work: &work, transmissionWork: &numerical) }, matching: { if case .cad(.cancelled) = $0 { true } else { false } }))
        #expect(work.visits == 1)
        var query = try CADAdapterWork(maximumVisits: 2)
        #expect(CADFixtures.refuses({ _ = try fixture.geometry.involuteGear(occurrenceID: "first",
            expected: fixture.geometry.identity, work: &query) }, matching: { if case .capacityExceeded = $0 { true } else { false } }))
        #expect(query.visits == 2)
    }

    @Test func actualModelStateFrameAndLayoutAssociationRefuse() throws {
        guard #available(macOS 15, *) else { return }
        let fixture = try GearBindingFixtures()
        let swappedFirst = try CADGearShaftRequest(occurrenceID: "first", joint: fixture.second.joint,
            endFace: fixture.first.endFace, mountingPhase: 0)
        let swappedSecond = try CADGearShaftRequest(occurrenceID: "second", joint: fixture.first.joint,
            endFace: fixture.second.endFace, mountingPhase: 0)
        #expect(GearBindingFixtures.refuses({ _ = try fixture.bind(fixture.request(first: swappedFirst, second: swappedSecond)) },
            matching: { if case .wrongOccurrence = $0 { true } else { false } }))
        let input = try fixture.request()
        let wrongModel = try CADGearPairRequest(freshSource: input.source,
            model: ModelStamp(identity: "other", revision: input.model.revision), first: input.first,
            second: input.second, phase: input.phase, phaseScale: input.phaseScale, networkID: input.networkID,
            relationID: input.relationID, minimumPosition: input.minimumPosition, maximumPosition: input.maximumPosition,
            minimumTime: input.minimumTime, maximumTime: input.maximumTime, fidelity: input.fidelity)
        #expect(GearBindingFixtures.refuses({ _ = try fixture.bind(wrongModel) }, matching: { if case .staleModel = $0 { true } else { false } }))
        var work = try CADAdapterWork(maximumVisits: 1_000_000), numerical = try GearBindingFixtures.work()
        let wrongLayout = try ConstraintCoordinateLayout(coordinateIDs: [10, 20], dimensions: [.length, .angle],
            scales: [2, 3], timeScale: 5, revision: 1)
        #expect(GearBindingFixtures.refuses({ _ = try ReferenceCADGearBindingPreparer().bind(input,
            geometry: fixture.geometry, model: fixture.model, state: fixture.state, layout: wrongLayout,
            policy: GearBindingFixtures.policy(), transmissionPolicy: GearBindingFixtures.transmissionPolicy(),
            work: &work, transmissionWork: &numerical) }, matching: { if case .unsupportedDomain = $0 { true } else { false } }))
        let changedState = try fixture.model.makeState(KinematicState(revision: 1, time: 0, q: [0.01, 0], v: [2, -1], acceleration: [0, 0]))
        #expect(GearBindingFixtures.refuses({ _ = try ReferenceCADGearBindingPreparer().bind(input,
            geometry: fixture.geometry, model: fixture.model, state: changedState, layout: fixture.layout,
            policy: GearBindingFixtures.policy(), transmissionPolicy: GearBindingFixtures.transmissionPolicy(),
            work: &work, transmissionWork: &numerical) }, matching: { if case .unsupportedDomain = $0 { true } else { false } }))
        for changedFrame in [false, true] {
            var occurrences: [CADOccurrenceRequest] = []
            for (index, occurrence) in fixture.geometry.occurrences.enumerated() {
                occurrences.append(CADOccurrenceRequest(id: occurrence.id, sourceFeature: occurrence.sourceFeature,
                    body: occurrence.body, frame: index == 0 && changedFrame ? try GearBindingFixtures.id(.frame, "wrong") : occurrence.frame,
                    placement: index == 0 && !changedFrame ? RigidTransform(rotation: .identity, translation: try Vector3(0.01, 0, 0)) : occurrence.placement,
                    material: occurrence.material))
            }
            let geometry = try CADFixtures.admit(fixture.document, requests: occurrences)
            #expect(GearBindingFixtures.refuses({ _ = try ReferenceCADGearBindingPreparer().bind(input,
                geometry: geometry, model: fixture.model, state: fixture.state, layout: fixture.layout,
                policy: GearBindingFixtures.policy(), transmissionPolicy: GearBindingFixtures.transmissionPolicy(),
                work: &work, transmissionWork: &numerical) }, matching: {
                    if changedFrame, case .wrongOccurrence = $0 { return true }
                    if !changedFrame, case .incompatiblePlacement = $0 { return true }
                    return false
                }))
        }
    }

    @Test func sourceEditRequiresFreshGeometryAndExplicitInitialization() throws {
        guard #available(macOS 15, *) else { return }
        let old = try GearBindingFixtures(), binding = try old.bind()
        var document = old.document
        for id in document.designGraph.order {
            var node = try #require(document.designGraph.nodes[id])
            guard case .involuteGear(var gear) = node.operation else { throw CADFixtures.FixtureFailure.missingFeature }
            gear.dimensions[.width] = .constant(.length(12, unit: .millimeter))
            node.operation = .involuteGear(gear)
            document.designGraph.nodes[id] = node
        }
        let fresh = try GearBindingFixtures(document: document)
        #expect(binding.geometry.identity.fingerprint != fresh.geometry.identity.fingerprint)
        #expect(GearBindingFixtures.refuses({ try binding.validating(source: fresh.geometry.identity, model: fresh.model.stamp) },
            matching: { if case .staleSource = $0 { true } else { false } }))
        #expect(GearBindingFixtures.refuses({ try binding.validating(source: binding.geometry.identity,
            model: ModelStamp(identity: binding.model.stamp.identity, revision: 2)) }, matching: { if case .staleModel = $0 { true } else { false } }))
        #expect(GearBindingFixtures.refuses({ _ = try fresh.bind(fresh.request(source: old.geometry.identity)) },
            matching: { if case .staleSource = $0 { true } else { false } }))
        let reinitialized = try fresh.bind()
        #expect(abs(try #require(reinitialized.first.dimensions[.width]) - 0.012) < 1e-14)
        var work = try CADAdapterWork(maximumVisits: 100_000)
        #expect(CADFixtures.refuses({ _ = try reinitialized.geometry.exactMassProperties(occurrenceID: "first",
            expected: reinitialized.geometry.identity, work: &work) }, matching: { if case .exactMomentsUnavailable = $0 { true } else { false } }))
    }
}
