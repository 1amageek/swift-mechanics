import ParticleFlowsQualificationSupport

@main struct ParticleFlowsQualification {
    static func main() throws {
        try ParticleFlowsQualificationCases.kernelNormalization(); print("ParticleFlows kernel normalization passed")
        try ParticleFlowsQualificationCases.densityAndEOS(); print("ParticleFlows density and EOS passed")
        try ParticleFlowsQualificationCases.midpointMomentumEnergy(); print("ParticleFlows midpoint momentum and energy passed")
        try ParticleFlowsQualificationCases.viscosityAndHeat(); print("ParticleFlows viscosity and heat passed")
        try ParticleFlowsQualificationCases.prescribedGhostWork(); print("ParticleFlows prescribed ghost work passed")
        try ParticleFlowsQualificationCases.admissionAndTime(); print("ParticleFlows admission and time passed")
        try ParticleFlowsQualificationCases.exactWorkBounds(); print("ParticleFlows exact work bounds passed")
    }
}
