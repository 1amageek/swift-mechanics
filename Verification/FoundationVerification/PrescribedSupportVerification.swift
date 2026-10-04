import SwiftMechanics

extension FoundationVerification {
    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    static func verifyPrescribedRootSupports() throws {
        let root = try PrescribedSupportProbeContext(PrescribedSupportProbeModel(slider: false))
        for time in [0.0, 0.2, 0.5] { try verifyRootSupportBalance(root, time: time) }
        let slider = try PrescribedSupportProbeContext(PrescribedSupportProbeModel(slider: true))
        try verifySliderSupportBalance(slider)
        let input = try root.input(time: 0.2, drive: [1, 0, 0])
        var refused = false
        do { _ = try root.recover(input) }
        catch PlanarPrescribedRootReactionError.unallocatableGeneralizedLoad { refused = true }
        try require(refused)
        print("AF26 prescribed support: original root effort, offset COM, slider cuts and unallocatable drive refusal passed")
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func verifyRootSupportBalance(_ context: PrescribedSupportProbeContext, time: Double) throws {
        guard let fixture = context.fixture.rootOnly else { throw FoundationVerificationError.analyticCheckFailed }
        let oracle = PrescribedRootProbeOracle(fixture, time: time)
        let input = try context.input(time: time)
        let report = try context.recover(input)
        try require(report.joints.isEmpty && report.originalRank.rank == 3)
        let support = report.support.supportOnRoot, opposite = report.support.rootOnSupport
        try require(abs(support.forceX-oracle.effort[0]) < 1e-8)
        try require(abs(support.forceY-oracle.effort[1]) < 1e-8)
        try require(abs(support.momentZ-oracle.effort[2]) < 1e-8)
        try require(abs(support.forceX+opposite.forceX) < 1e-12
            && abs(support.forceY+opposite.forceY) < 1e-12
            && abs(support.momentZ+opposite.momentZ) < 1e-12)
        try require(report.rootActuationEffort.count == 3)
        for index in oracle.effort.indices {
            try require(abs(report.rootActuationEffort[index]-oracle.effort[index]) < 1e-8)
        }
        try require(report.maximumScaledOriginalGeneralizedResidual < 1e-8
            && report.maximumScaledRootEffortResidual < 1e-8)
        try require(report.support.timeSeconds.bitPattern == time.bitPattern
            && report.support.temporalMeaning == .instantaneousContinuousForce)
        let rootFrame = fixture.model.descriptor.bodies[0].frame
        let local = try context.recover(input, frame: rootFrame)
        let pose = try input.dynamics.input.snapshot.body(fixture.model.descriptor.root).motion.pose
        let transformed = try pose.rotation.conjugated().rotating(Vector3(support.forceX, support.forceY, 0))
        try require(abs(local.support.supportOnRoot.forceX-transformed.x) < 1e-8
            && abs(local.support.supportOnRoot.forceY-transformed.y) < 1e-8
            && abs(local.support.supportOnRoot.momentZ-support.momentZ) < 1e-8)
    }

    @inline(never)
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    private static func verifySliderSupportBalance(_ context: PrescribedSupportProbeContext) throws {
        let input = try context.input(time: 0)
        let report = try context.recover(input)
        try require(report.joints.count == 1 && report.rootActuationEffort.count == 3)
        let support = report.support.supportOnRoot
        try require(abs(support.forceX) < 1e-8 && abs(support.forceY-3) < 1e-8 && abs(support.momentZ-4) < 1e-8)
        try require(abs(report.rootActuationEffort[0]) < 1e-8
            && abs(report.rootActuationEffort[1]-3) < 1e-8 && abs(report.rootActuationEffort[2]-4) < 1e-8)
        let cut = report.joints[0]
        try require(abs(cut.parentOnChild.forceX) < 1e-8 && abs(cut.parentOnChild.forceY-2) < 1e-8
            && abs(cut.parentOnChild.momentZ) < 1e-8)
        try require(abs(cut.childOnParent.forceY+2) < 1e-8)
        try require(abs(cut.referencePointWorld.x-2) < 1e-12 && abs(cut.referencePointWorld.y) < 1e-12)
        try require(abs(input.motion.motion.values[3]) < 1e-8)
    }
}
