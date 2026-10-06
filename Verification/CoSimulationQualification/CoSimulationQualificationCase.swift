public enum CoSimulationQualificationCase: String, CaseIterable, Sendable {
    case heldPhysical, pureDamper, evidenceRollback, secondRefusalRollback, cumulativeCapacity
    case admissionRefusals, staleAndShutdown, reentry, cancellationPoison
}
