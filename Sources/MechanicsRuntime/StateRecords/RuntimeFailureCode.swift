public enum RuntimeFailureCode: Equatable, Sendable {
    case invalidInput, capacityExceeded, integerOverflow, invalidState, incompatibleModel, incompatibleContinuation,
         missingContributor, unknownContributor, duplicateContributor, invalidContributor, contributorBudgetExceeded,
         unsupportedDomain, unsupportedDeterminism, profilingUnavailable, corruptCheckpoint, truncatedCheckpoint,
         busy, closed, cancelled, invalidOwnerAccess, incompatibleMigration
}
