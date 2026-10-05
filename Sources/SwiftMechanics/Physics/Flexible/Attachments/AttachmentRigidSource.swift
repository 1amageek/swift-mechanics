/// Immutable source owner; force proposals require this exact owner, not reused revision numbers.
public final class AttachmentRigidSource: Sendable {
    public let snapshot: KinematicSnapshot
    public let state: KinematicState
    public let evaluationPolicy: JointEvaluationPolicy

    /// Evaluates the actual tree and retains the exact tangent velocity that generated its snapshot.
    /// Quaternion coordinate derivatives in snapshot.coordinateRate are not generalized velocities.
    public init(tree: KinematicTree, state: KinematicState,
                policy: JointEvaluationPolicy) throws(AttachmentError) {
        let evaluator: any TreeKinematicsComputing = TreeKinematicsEvaluator()
        do {
            self.snapshot = try evaluator.evaluate(tree, state: state, policy: policy)
        } catch let error as JointError { throw .joint(error) }
        catch let error as CoreError { throw .core(error) }
        catch { throw .rigidSupplierFailure }
        self.state = state
        self.evaluationPolicy = policy
    }
}
