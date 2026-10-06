/// Instantaneous extended-body gravity; implementations do not advance or accept state.
public protocol AffineRigidGravityEvaluating: Sendable {
    func evaluate(_ input: AffineRigidGravityInput, policy: AffineRigidGravityPolicy,
                  work: inout LoadWork) throws(AffineRigidGravityFailure) -> AffineRigidGravityResponse

    /// Caller attests that this body's gravity is exclusively represented by this contribution.
    func staticBodyWrench(_ response: AffineRigidGravityResponse, otherGravityAppliedToBody: Bool,
                         work: inout LoadWork) throws(AffineRigidGravityFailure) -> BodyWrenchContribution
}
