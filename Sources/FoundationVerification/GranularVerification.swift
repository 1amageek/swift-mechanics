import MechanicsCore
import MechanicsModel
import MechanicsNumerics
import MechanicsCollision
import MechanicsContactLaws
import MechanicsRuntime
import MechanicsGranular

extension FoundationVerification {
    static func verifyGranular() throws {
        let initial = try GranularProbeContext.prepare(motions: [GranularMotion(position: Vector3(-0.49, 0, 0), velocity: .unitX), GranularMotion(position: Vector3(0.49, 0, 0), velocity: Vector3(-1, 0, 0))])
        var workspace = GranularWorkspace()
        let service: any GranularEvolving = ReferenceGranularEvolution()
        let result = try GranularProbeContext.step(initial, workspace: &workspace, service: service)
        try require(abs(result.contacts[0].response.compressiveNormalForce - 20) < 1e-9)
        try require(abs(result.state.motions[0].velocity.x - 0.98) < 1e-9 && abs(result.state.motions[1].velocity.x + 0.98) < 1e-9)
        try require(abs(result.evidence.kineticEnergyChange + 0.0396) < 1e-9 && result.evidence.originalWorkResidual < 1e-9)
        var work = try GranularProbeContext.numerical()
        let checkpoints: any GranularCheckpointing = ValueGranularCheckpoints()
        let checkpoint = try checkpoints.capture(result.state, policy: GranularProbeContext.policy(), work: &work)
        let restored = try checkpoints.restore(checkpoint, model: initial.model, policy: GranularProbeContext.policy(), work: &work)
        var other = GranularWorkspace()
        let next = try GranularProbeContext.step(result.state, workspace: &workspace)
        let replay = try GranularProbeContext.step(restored, workspace: &other)
        try require(GranularProbeContext.same(next.state, replay.state))
        var refused = false
        do { _ = try GranularProbeContext.step(initial, policy: GranularProbeContext.policy(neighbors: 0), workspace: &workspace) }
        catch { refused = true }
        try require(refused && initial.contacts[0].history.sequence == 0 && initial.steps == 0)
        let templates = [try GranularDistributionTemplate(weight: 1, radius: 0.1, density: 1000, material: GranularProbeContext.ref("sample", .material))]
        var calls = try GranularProbeContext.supplier()
        let sampler: any GranularSampling = SeededGranularSampler()
        let sampled = try sampler.sample(count: 2, templates: templates, random: initial.random, policy: GranularProbeContext.policy(), numericalWork: &work, supplierWork: &calls)
        try require(sampled.random.draws == initial.random.draws + 2 && sampled.samples.count == 2)
        try require(abs(sampled.samples[0].mass - (4.0 / 3.0) * Double.pi) < 1e-9)
    }
}
