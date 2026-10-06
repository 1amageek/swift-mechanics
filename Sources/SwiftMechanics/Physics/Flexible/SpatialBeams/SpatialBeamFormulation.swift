public enum SpatialBeamFormulation: Equatable, Sendable {
    case eulerBernoulli
    case timoshenko
    // FIXME(INCOMPLETE_IMPLEMENTATION): Finite rotation has no objective spatial element here.
    // SpatialBeamAssembling rejects this selection until finite-rotation strain, tangent,
    // inertia and field laws are implemented and behaviorally qualified together.
    case finiteRotation
}
