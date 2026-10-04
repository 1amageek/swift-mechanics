import SwiftMechanics

extension FoundationVerification {
    static func verifyPlanarFluids() throws {
        let grid = try PlanarProbeContext.grid(nx: 4, ny: 5), n = grid.count
        let state = try PlanarProbeContext.state(grid, u: [Double](repeating: 0.5, count: n), v: [Double](repeating: -0.25, count: n))
        var work = try PlanarProbeContext.work()
        let service: any PlanarFlowOperating = PlanarProbeContext.solver()
        let result = try service.step(state: state, source: PlanarProbeContext.source(0.1, -0.2), duration: 0.05, policy: PlanarProbeContext.policy(), work: &work)
        for k in 0..<n {
            try require(abs(result.state.u[k] - 0.505) < 1e-12 && abs(result.state.v[k] + 0.26) < 1e-12)
            try require(abs(PlanarProbeContext.divergence(result.state, at: k)) < 1e-9)
        }
        try require(result.state.sequence == 1 && abs(result.evidence.energyDefect) < 1e-9)
        var u = state.u; u[1] += 0.1
        let tentative = try PlanarProbeContext.state(grid, u: u, v: state.v)
        let projected = try service.project(state: tentative, duration: 0.05, policy: PlanarProbeContext.policy(), work: &work)
        for k in 0..<n { try require(abs(PlanarProbeContext.divergence(projected.state, at: k)) < 1e-9) }
        try require(projected.state.pressure[0] == 0 && projected.evidence.projectionLoss > 0 && projected.evidence.maximumPressureResidual < 1e-8)
        var refused = false
        do { _ = try service.step(state: state, source: PlanarProbeContext.source(), duration: 2, policy: PlanarProbeContext.policy(), work: &work) }
        catch { refused = true }
        try require(refused && state.sequence == 0 && state.time == 0)
    }
}
