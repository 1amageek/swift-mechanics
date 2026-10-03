public enum CompilationCode: Equatable, Sendable {
    case invalidInput, invalidPolicy, capacityExceeded, integerOverflow, cancelled, duplicateIdentity,
         danglingReference, invalidRoot, multipleParents, unsupportedClosedLoop, disconnectedTree,
         producerValidationFailure, invalidInertia, incompatibleBodyMode, incompatibleCoordinateAuthority,
         staleRevision, invalidCoordinates, inconsistentInitialPose, missingRepresentation,
         approximationForbidden, unsupportedCapability, duplicateRegistration, unknownSchema,
         invalidLawDomain, invalidValidatorEvidence, validatorBudgetExceeded, wrongModel,
         incompatibleMigration, resetRequired, mismatchedTransition
}
