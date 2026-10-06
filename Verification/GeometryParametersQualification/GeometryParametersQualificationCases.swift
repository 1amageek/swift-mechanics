import SwiftMechanics

public enum GeometryParametersQualificationCases {
    private typealias F = GeometryParametersQualificationFixture
    private typealias O = GeometryParametersQualificationOracle

    public static func rootTranslation() throws {
        let f = try F(), d = try Vector3(0.7, -1.1, 0.4)
        let target = GeometryParameterTarget.fixedRoot(body: f.tree.bodies[0].id, frame: f.tree.bodies[0].frame)
        let bindings = [try f.binding(1, target: target, chart: .translation(reference: f.tree.bodies[0].referencePose, perMeter: d)),
                        try f.binding(2, target: target, chart: .translation(reference: f.tree.bodies[0].referencePose, perMeter: d))]
        let product = try f.product(bindings, direction: [2, -0.5])
        let expected = try d.scaled(by: 1.5)
        for body in product.bodies {
            try O.vector(body.translation, expected, "SI world translation")
            try O.matrix(body.rotationMatrix, .zero, "Translation does not rotate")
            try O.motion(body.velocity, SpatialMotion(angular: .zero, linear: .zero), "Translation velocity")
            try O.motion(body.acceleration, SpatialMotion(angular: .zero, linear: .zero), "Translation acceleration")
            try O.motion(body.accelerationBias, SpatialMotion(angular: .zero, linear: .zero), "Translation bias")
        }
        try O.vector(product.frames[0].translation, .zero, "World frame held fixed")
        for column in product.geometricColumns { try O.motion(column, SpatialMotion(angular: .zero, linear: .zero), "Translation J") }
        try O.finiteDifferences(f, bindings: bindings, direction: [2, -0.5], product: product)
    }

    public static func rootRotation() throws {
        let f = try F(), eta = try Vector3(0.3, -0.5, 0.8), rate = 1.3
        let binding = try f.binding(3, target: .fixedRoot(body: f.tree.bodies[0].id, frame: f.tree.bodies[0].frame),
            chart: .rotation(reference: f.tree.bodies[0].referencePose, bodyPerRadian: eta))
        let product = try f.product([binding], direction: [rate])
        let t = try eta.scaled(by: rate)
        let hat = try Matrix3(0, -t.z, t.y, t.z, 0, -t.x, -t.y, t.x, 0)
        try O.matrix(product.bodies[0].rotationMatrix, f.tree.bodies[0].referencePose.rotation.matrix().multiplied(by: hat), "Literal right-body dR")
        try O.vector(product.bodies[0].translation, .zero, "Root rotation fixes root translation")
        try O.finiteDifferences(f, bindings: [binding], direction: [rate], product: product)
        try O.require(product.bodies[3].accelerationBias.linear.magnitude() > 1e-4, "Root rotation exercises moving bias")
    }

    public static func parentAnchor() throws { try anchor(parent: true) }
    public static func childAnchor() throws { try anchor(parent: false) }
    private static func anchor(parent: Bool) throws {
        let f = try F(), joint = f.tree.joints[0]
        let actual = parent ? joint.parentAnchor : joint.childAnchor
        guard case .fixed(let reference) = actual.placement else { throw GeometryParametersQualificationError.assertion("Original fixed anchor") }
        let target = GeometryParameterTarget.fixedAnchor(joint: joint.id, frame: actual.frame)
        let bindings = [try f.binding(4, target: target, chart: .translation(reference: reference, perMeter: Vector3(-0.3, 0.6, 0.2))),
                        try f.binding(5, target: target, chart: .rotation(reference: reference, bodyPerRadian: Vector3(0.4, 0.2, -0.7)))]
        let product = try f.product(bindings, direction: [-0.8, 1.1])
        try O.finiteDifferences(f, bindings: bindings, direction: [-0.8, 1.1], product: product)
        try O.require(product.bodies[3].velocity.linear.magnitude() > 1e-4 && product.bodies[3].accelerationBias.linear.magnitude() > 1e-4,
                      "Anchor geometry exercises transported motion and bias")
    }

    public static func rawAxes() throws {
        let f = try F()
        let raw = [try Vector3(0, 0, 2), try Vector3(1, 2, -1), try Vector3(2, -1, 3)]
        let changes = [try Vector3(1, 2, 3), try Vector3(-0.4, 0.7, 0.2), try Vector3(0.3, -0.8, 0.5)]
        var bindings: [GeometryParameterBinding] = []
        for i in 0..<3 {
            bindings.append(try f.binding(UInt64(10+i), target: .jointAxis(joint: f.tree.joints[i].id, index: 0),
                chart: .normalizedAxis(rawReference: raw[i], rawPerUnit: changes[i])))
        }
        let product = try f.product(bindings, direction: [2, -0.9, 1.4])
        try O.require(product.normalizedAxes.count == 3, "Every normalized axis witness retained")
        try O.vector(product.normalizedAxes[0].normalizedAxis, .unitZ, "Nonunit original z axis")
        try O.vector(product.normalizedAxes[0].normalizedDirection, Vector3(1, 2, 0), "Literal transverse normalization derivative")
        for witness in product.normalizedAxes {
            try O.scalar(witness.normalizedAxis.dot(witness.normalizedDirection), 0, "Axis unit-sphere tangent")
        }
        try O.finiteDifferences(f, bindings: bindings, direction: [2, -0.9, 1.4], product: product)
    }

    public static func sourceRefusals() throws {
        let f = try F(), target = GeometryParameterTarget.fixedRoot(body: f.tree.bodies[0].id, frame: f.tree.bodies[0].frame)
        let chart = GeometryParameterChart.translation(reference: f.tree.bodies[0].referencePose, perMeter: .unitX)
        let valid = try f.binding(20, target: target, chart: chart)
        try failure(f.source([try f.binding(20, target: target, chart: chart, revision: 8)]), [1], { if case .derivativeUnavailable(.sourceMapping) = $0 { true } else { false } })
        try failure(f.source([try f.binding(20, target: target, chart: chart, provenance: SourceProvenance(source: "other-model", revision: 7))]), [1], { if case .derivativeUnavailable(.sourceMapping) = $0 { true } else { false } })
        let stale = try KinematicState(revision: 8, time: f.state.time, q: f.state.q, v: f.state.v, acceleration: f.state.acceleration)
        try failure(f.source([valid], state: stale), [1], { if case .derivativeUnavailable(.sourceMapping) = $0 { true } else { false } })
        try failure(f.source([try f.binding(21, target: .fixedRoot(body: f.tree.bodies[0].id, frame: F.id(.frame, "wrong")), chart: chart)]), [1], { if case .derivativeUnavailable(.sourceMapping) = $0 { true } else { false } })
        try failure(f.source([try f.binding(22, target: target, chart: .translation(reference: .identity, perMeter: .unitX))]), [1], { if case .derivativeUnavailable(.referenceChartMismatch) = $0 { true } else { false } })
        try failure(f.source([valid, valid]), [1, 1], { if case .invalidInput = $0 { true } else { false } })
        try failure(f.source([valid]), [], { if case .invalidShape = $0 { true } else { false } })
        try failure(f.source([valid]), [.infinity], { if case .invalidInput = $0 { true } else { false } })
        try failure(f.source([try f.binding(23, target: .topology(entity: f.tree.bodies[1].id), chart: chart)]), [1], { if case .derivativeUnavailable(.topologyChange) = $0 { true } else { false } })
        for raw in [Vector3.zero, try Vector3(0, 0, 1e-8)] {
            try failure(f.source([try f.binding(24, target: .jointAxis(joint: f.tree.joints[0].id, index: 0), chart: .normalizedAxis(rawReference: raw, rawPerUnit: .unitX))]), [1], { if case .derivativeUnavailable(.zeroOrBoundaryAxis) = $0 { true } else { false } })
        }
        try failure(f.source([try f.binding(25, target: .jointAxis(joint: f.tree.joints[0].id, index: 0), chart: .normalizedAxis(rawReference: .unitX, rawPerUnit: .unitY))]), [1], { if case .derivativeUnavailable(.referenceChartMismatch) = $0 { true } else { false } })
        try O.refusal("Unit mismatch", match: { if case .invalidInput = $0 { true } else { false } }) {
            _ = try GeometryParameterBinding(parameterID: 26, originalValue: 1, dimension: .angle, modelSource: f.provenance,
                parameterSource: f.provenance, treeRevision: 7, target: target, chart: chart)
        }
    }

    private static func failure(_ source: GeometryParameterSource, _ direction: [Double], _ match: (GeometryParameterError) -> Bool) throws {
        var work = try F.work(), calls = try DerivativeSupplierWork(maximumCalls: 100)
        try O.refusal("Source admission", match: match) {
            let supplier: any GeometryParameterDifferentiating = ExactGeometryParameterDifferentiator()
            _ = try supplier.direction(source, direction: direction, policy: F.policy(), supplierWork: &calls, work: &work)
        }
        try O.require(calls.calls == 0, "Admission refuses before original supplier")
    }

    public static func exactWorkAndCancellation() throws {
        let f = try F(), binding = try f.binding(30, target: .jointAxis(joint: f.tree.joints[0].id, index: 0),
            chart: .normalizedAxis(rawReference: Vector3(0, 0, 2), rawPerUnit: .unitX))
        let source = f.source([binding]), policy = try F.policy()
        let supplier: any GeometryParameterDifferentiating = ExactGeometryParameterDifferentiator()
        var work = try F.work(seeded: true), calls = try DerivativeSupplierWork(maximumCalls: 100)
        try calls.chargeCall()
        let product = try supplier.direction(source, direction: [1], policy: policy, supplierWork: &calls, work: &work)
        try O.require(work == product.numericalWork && calls == product.supplierWork && calls.calls == 2 + f.tree.bodies.count && work.iterations == 1,
                      "Exact seeded caller ledger, original supplier calls and no invented iterations")
        let reservation = 2048*f.tree.bodies.count + 128*f.tree.bodies.count*f.tree.layout.velocityCount + 128 + 2048
        try O.require(work.peakScalarStorage == reservation && work.operations > 11, "Original simultaneous scalar reservation")
        var exact = try F.work(operations: work.operations, storage: reservation, seeded: true)
        var exactCalls = try DerivativeSupplierWork(maximumCalls: calls.calls); try exactCalls.chargeCall()
        _ = try supplier.direction(source, direction: [1], policy: policy, supplierWork: &exactCalls, work: &exact)
        try O.require(exact.operations == work.operations && exact.peakScalarStorage == reservation && exactCalls.calls == calls.calls, "Exact work boundary accepts")
        var short = try F.work(operations: work.operations - 1, storage: reservation, seeded: true), shortCalls = try DerivativeSupplierWork(maximumCalls: 100)
        try shortCalls.chargeCall()
        try O.refusal("One-short arithmetic", match: { if case .numerical(.resourceLimit(resource: .arithmeticOperations, limit: _)) = $0 { true } else { false } }) {
            _ = try supplier.direction(source, direction: [1], policy: policy, supplierWork: &shortCalls, work: &short)
        }
        try O.require(short.operations >= 11 && short.operations <= work.operations - 1 && shortCalls.calls >= 1, "Failed arithmetic retains cumulative ledger")
        var storageShort = try F.work(storage: reservation - 1, seeded: true), untouched = try DerivativeSupplierWork(maximumCalls: 100)
        try O.refusal("One-short storage", match: { if case .numerical(.resourceLimit(resource: .scalarStorage, limit: _)) = $0 { true } else { false } }) {
            _ = try supplier.direction(source, direction: [1], policy: policy, supplierWork: &untouched, work: &storageShort)
        }
        try O.require(untouched.calls == 0 && storageShort.peakScalarStorage == 17, "Storage refuses before allocation/supplier")
        var callWork = try F.work(), boundedCalls = try DerivativeSupplierWork(maximumCalls: f.tree.bodies.count)
        try O.refusal("One-short supplier calls", match: { if case .scalar(.capacityExceeded) = $0 { true } else { false } }) {
            _ = try supplier.direction(source, direction: [1], policy: policy, supplierWork: &boundedCalls, work: &callWork)
        }
        try O.require(boundedCalls.calls == boundedCalls.maximumCalls, "Consumed supplier calls remain visible")
        var cancelledWork = try F.work(seeded: true), cancelledCalls = try DerivativeSupplierWork(maximumCalls: 100)
        let before = cancelledWork
        try O.refusal("Initial caller cancellation", match: { if case .cancelled = $0 { true } else { false } }) {
            _ = try supplier.direction(source, direction: [1], policy: F.policy(cancelled: { true }), supplierWork: &cancelledCalls, work: &cancelledWork)
        }
        try O.require(before == cancelledWork && cancelledCalls.calls == 0, "Cancellation preserves initial ledger")
        var capWork = try F.work(), capCalls = try DerivativeSupplierWork(maximumCalls: 100)
        try O.refusal("Body capacity", match: { if case .capacityExceeded = $0 { true } else { false } }) {
            _ = try supplier.direction(source, direction: [1], policy: F.policy(bodies: 1), supplierWork: &capCalls, work: &capWork)
        }
        try O.require(capCalls.calls == 0 && capWork.operations == 0, "Capacity precedes traversal")
        if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) {
            try lateCancellation(source)
        } else { throw GeometryParametersQualificationError.assertion("Mutex cancellation witness requires macOS15") }
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func lateCancellation(_ source: GeometryParameterSource) throws {
        let counter = GeometryParametersQualificationCancellation(cancelAt: Int.max)
        let supplier: any GeometryParameterDifferentiating = ExactGeometryParameterDifferentiator()
        var work = try F.work(), calls = try DerivativeSupplierWork(maximumCalls: 100)
        _ = try supplier.direction(source, direction: [1], policy: F.policy(cancelled: { counter.poll() }), supplierWork: &calls, work: &work)
        let last = GeometryParametersQualificationCancellation(cancelAt: counter.count)
        var failedWork = try F.work(), failedCalls = try DerivativeSupplierWork(maximumCalls: 100)
        try O.refusal("Final caller cancellation", match: { if case .cancelled = $0 { true } else { false } }) {
            _ = try supplier.direction(source, direction: [1], policy: F.policy(cancelled: { last.poll() }), supplierWork: &failedCalls, work: &failedWork)
        }
        try O.require(failedCalls.calls == calls.calls && failedWork.operations == work.operations && last.count == counter.count,
                      "Final cancellation retains actual completed arithmetic/calls and publishes no result")
    }

    public static func domainsAndSupplierFailure() throws {
        let fixed = try F(specifications: [.fixed])
        let product = try fixed.product([], direction: [])
        try O.require(product.supplierWork.calls == 3 && product.coordinateRate.isEmpty && product.geometricColumns.isEmpty, "Actual fixed-joint domain")
        for body in product.bodies {
            try O.vector(body.translation, .zero, "Empty direction translation")
            try O.matrix(body.rotationMatrix, .zero, "Empty direction rotation")
            try O.motion(body.accelerationBias, SpatialMotion(angular: .zero, linear: .zero), "Fixed bias derivative")
        }
        let floating = try F(specifications: [.fixed], rootBase: .spatialFloating)
        try failure(floating.source([]), [], { if case .derivativeUnavailable(.floatingRoot) = $0 { true } else { false } })
        let spherical = try F(specifications: [.spherical])
        try failure(spherical.source([]), [], { if case .derivativeUnavailable(.unsupportedJointChart) = $0 { true } else { false } })
        let moving = try F(specifications: [.fixed], movingParent: true)
        try failure(moving.source([]), [], { if case .derivativeUnavailable(.movingAnchor) = $0 { true } else { false } })
        let primal = try F(specifications: [.prismatic(axis: .unitX)])
        var work = try F.work(seeded: true), calls = try DerivativeSupplierWork(maximumCalls: 100)
        let supplier: any GeometryParameterDifferentiating = ExactGeometryParameterDifferentiator()
        try O.refusal("Actual JointMotionEvaluator scaling failure", match: {
            if case .joints(.nonFiniteState, failedSupplierWorkUnavailable: true) = $0 { true } else { false }
        }) {
            _ = try supplier.direction(primal.source([]), direction: [], policy: F.policy(length: 1e-320), supplierWork: &calls, work: &work)
        }
        try O.require(calls.calls == 1 && work.operations > 11 && work.peakScalarStorage > 17,
                      "Failed real supplier invocation recorded without fabricated arithmetic")
    }

    public static func actualTaskCancellation(_ source: GeometryParameterSource, policy: GeometryParameterPolicy,
                                              work: inout NumericalWork, supplierWork: inout DerivativeSupplierWork) throws {
        let supplier: any GeometryParameterDifferentiating = ExactGeometryParameterDifferentiator()
        let before = work
        try O.refusal("Actual cancelled task", match: { if case .cancelled = $0 { true } else { false } }) {
            _ = try supplier.direction(source, direction: [], policy: policy, supplierWork: &supplierWork, work: &work)
        }
        try O.require(work == before && supplierWork.calls == 0, "Task cancellation does not publish or consume work")
    }
}
