public struct SubtreeReleasePolicy: Sendable {
    public let limits: DetachedLeafPolicy
    public init(maximumBodies: Int, maximumCoordinates: Int, translation: NumericalTolerance,
                rotation: NumericalTolerance, linearVelocity: NumericalTolerance, angularVelocity: NumericalTolerance,
                kineticEnergy: NumericalTolerance, linearMomentum: NumericalTolerance, angularMomentum: NumericalTolerance,
                isCancelled: @escaping @Sendable () -> Bool = { false }) throws(TopologyReleaseFailure) {
        do throws(MechanismError) {
            limits = try DetachedLeafPolicy(maximumBodies: maximumBodies, maximumCoordinates: maximumCoordinates,
                translation: translation, rotation: rotation, linearVelocity: linearVelocity, angularVelocity: angularVelocity,
                kineticEnergy: kineticEnergy, linearMomentum: linearMomentum, angularMomentum: angularMomentum, isCancelled: isCancelled)
        } catch { throw .invalidInput }
    }
}
