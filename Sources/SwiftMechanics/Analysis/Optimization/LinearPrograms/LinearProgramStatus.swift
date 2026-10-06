public enum LinearProgramStatus: Sendable {
    case optimal(LinearOptimalCertificate)
    case infeasible(LinearInfeasibilityCertificate)
    case unbounded(LinearUnboundedCertificate)
}
