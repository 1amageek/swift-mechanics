public enum ModelError: Error, Equatable, Sendable {
    case emptyIdentity
    case identityKindMismatch
    case revisionMismatch
    case invalidMetadata
    case representationKindMismatch
    case missingRepresentation
    case invalidMass
    case invalidDensity
    case invalidDimensions
    case asymmetricInertia
    case nonPositiveInertia
    case nonphysicalInertia
    case invalidInertiaPolicy
    case emptyCompound
    case ambiguousOverlap(first: Int, second: Int)
    case missingDynamicInertia
    case invalidLayout
    case nonFiniteCoordinates
    case invalidQuaternion
}
