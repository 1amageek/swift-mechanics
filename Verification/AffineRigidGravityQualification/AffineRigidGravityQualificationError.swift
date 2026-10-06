import SwiftMechanics

public enum AffineRigidGravityQualificationError: Error, Sendable {
    case assertion(String)
    case unexpectedSuccess(String)
    case unexpectedFailure(AffineRigidGravityFailure)
}
