import MechanicsCore

public struct DetachedLeafPolicy: Sendable {
    public let maximumBodies:Int
    public let maximumCoordinates:Int
    public let translation:NumericalTolerance
    public let rotation:NumericalTolerance
    public let linearVelocity:NumericalTolerance
    public let angularVelocity:NumericalTolerance
    public let kineticEnergy:NumericalTolerance
    public let linearMomentum:NumericalTolerance
    public let angularMomentum:NumericalTolerance
    public let isCancelled:@Sendable () -> Bool
    public init(maximumBodies:Int,maximumCoordinates:Int,translation:NumericalTolerance,rotation:NumericalTolerance,
                linearVelocity:NumericalTolerance,angularVelocity:NumericalTolerance,kineticEnergy:NumericalTolerance,
                linearMomentum:NumericalTolerance,angularMomentum:NumericalTolerance,isCancelled:@escaping @Sendable () -> Bool = {false}) throws(MechanismError) {
        guard maximumBodies > 0,maximumCoordinates > 0 else { throw .invalidInput }
        self.maximumBodies=maximumBodies;self.maximumCoordinates=maximumCoordinates;self.translation=translation;self.rotation=rotation
        self.linearVelocity=linearVelocity;self.angularVelocity=angularVelocity;self.kineticEnergy=kineticEnergy
        self.linearMomentum=linearMomentum;self.angularMomentum=angularMomentum;self.isCancelled=isCancelled
    }
}
