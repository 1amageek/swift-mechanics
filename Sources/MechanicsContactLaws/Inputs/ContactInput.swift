import MechanicsCore
import MechanicsModel
public struct ContactInput: Sendable {
    public let identity: ContactIdentity
    public let basis: ContactBasis
    public let separation: Double
    public let relativeVelocity: Vector3
    public let relativeAngularVelocity: Vector3
    public let startTimeSeconds: Double
    public let timeStepSeconds: Double
    public init(identity: ContactIdentity, basis: ContactBasis, separation: Double,
                relativeVelocity: Vector3, relativeAngularVelocity: Vector3,
                startTimeSeconds: Double, timeStepSeconds: Double) throws(ContactLawError) {
        guard identity.frame == basis.frame else { throw .frameMismatch }
        guard separation.isFinite, startTimeSeconds.isFinite, startTimeSeconds >= 0,
              timeStepSeconds.isFinite, timeStepSeconds > 0 else { throw .invalidInput }
        self.identity=identity; self.basis=basis; self.separation=separation
        self.relativeVelocity=relativeVelocity; self.relativeAngularVelocity=relativeAngularVelocity
        self.startTimeSeconds=startTimeSeconds; self.timeStepSeconds=timeStepSeconds
    }
}
