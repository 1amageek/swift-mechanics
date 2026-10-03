import MechanicsModel

public enum JointError: Error, Equatable, Sendable {
    case invalidAxis
    case invalidJointGeometry
    case invalidPolicy
    case invalidCoordinateCount
    case nonFiniteState
    case invalidTimeStep
    case chartSingularity
    case identityKindMismatch
    case duplicateIdentity(EntityID)
    case danglingBody(EntityID)
    case unknownBody(EntityID)
    case unknownFrame(EntityID)
    case invalidRoot
    case multipleParents(EntityID)
    case cycle
    case disconnectedTree
    case mixedDimensions
    case nonplanarGeometry
    case stateRevisionMismatch
    case missingDerivativeData(EntityID)
    case staleDerivativeData(EntityID)
    case unknownDerivativeData(EntityID)
    case capacityExceeded
    case integerOverflow
}
