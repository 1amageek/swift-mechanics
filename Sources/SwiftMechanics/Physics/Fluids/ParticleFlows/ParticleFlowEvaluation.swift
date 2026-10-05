internal struct ParticleFlowEvaluation {
    let state: ParticleFlowState
    let diagnostics: ParticleFlowDiagnostics
    let force: [Vector3]
    let densityRate: [Double]
    let heatRate: [Double]
    let soundSpeed: [Double]
}
