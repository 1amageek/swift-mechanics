
public struct ScalarJointPortEvaluator: ScalarJointPortEvaluating {
    public init() {}
    public func passive(_ manifold: JointManifold, position: Double, velocity: Double, law: ScalarJointLaw, wrap: JointWrapPolicy,
                        policy: ConstraintEvaluationPolicy, work: inout NumericalWork) throws(ConstraintError) -> ScalarJointResponse {
        try admit(manifold,position:position,velocity:velocity,wrap:wrap,policy:policy,work:&work)
        guard position >= law.minimumPosition, position <= law.maximumPosition else { throw .outsideDomain }
        try ConstraintArithmetic.charge(15,&work); try ConstraintArithmetic.storage(16,&work)
        let delta=position-law.referencePosition
        let effort=try ConstraintArithmetic.finite(-law.stiffness*delta-law.damping*velocity)
        let energy=try ConstraintArithmetic.finite(0.5*law.stiffness*delta*delta)
        let power=try ConstraintArithmetic.finite(-law.damping*velocity*velocity)
        let friction: JointFrictionResponse
        if law.coulombEffort == 0 { friction = .disabled }
        else if velocity == 0 { friction = .staticInterval(lowerEffort:-law.coulombEffort,upperEffort:law.coulombEffort) }
        else {
            let f=velocity > 0 ? -law.coulombEffort : law.coulombEffort
            friction = .sliding(effort:f,dissipativePower:try ConstraintArithmetic.finite(f*velocity))
        }
        try ConstraintArithmetic.check(policy)
        let dimension: PhysicalDimension=manifold.kind == .prismatic ? .length : .angle
        let effortDimension: PhysicalDimension=manifold.kind == .prismatic ? .force : PhysicalDimension(length:2,mass:1,time:-2,angle:-1)
        return ScalarJointResponse(smoothEffort:effort,potentialEnergy:energy,damperPower:power,friction:friction,coordinateDimension:dimension,effortDimension:effortDimension)
    }
    public func limits(_ manifold: JointManifold, position: Double, velocity: Double, lower: Double, upper: Double,
                       mode: JointLimitMode, impact: JointImpactPolicy, wrap: JointWrapPolicy,
                       policy: ConstraintEvaluationPolicy, work: inout NumericalWork) throws(ConstraintError) -> ScalarJointLimitResponse {
        try admit(manifold,position:position,velocity:velocity,wrap:wrap,policy:policy,work:&work)
        guard lower.isFinite, upper.isFinite, lower < upper else { throw .invalidInput }
        switch impact {
        case .none: break
        // FIXME(INCOMPLETE_IMPLEMENTATION): This callable limit port does not solve impact restitution. Dynamics/evolution must supply and verify the impulse law before this branch can succeed.
        case .impact: throw .unsupportedDomain
        }
        try ConstraintArithmetic.charge(2,&work); try ConstraintArithmetic.storage(16,&work)
        let lo=try ConstraintArithmetic.finite(position-lower), hi=try ConstraintArithmetic.finite(upper-position)
        var effort: Double?=nil, potential: Double?=nil, power: Double?=nil
        switch mode {
        case .rowsOnly: break
        case .compliant(let k, let c):
            guard k.isFinite, k > 0, c.isFinite, c >= 0 else { throw .invalidInput }
            try ConstraintArithmetic.charge(28,&work)
            let pl=max(-lo,0), pu=max(-hi,0)
            let dl=lo < 0 ? c*max(-velocity,0) : 0, du=hi < 0 ? c*max(velocity,0) : 0
            effort=try ConstraintArithmetic.finite(k*pl+dl-k*pu-du)
            potential=try ConstraintArithmetic.finite(0.5*k*(pl*pl+pu*pu))
            power=try ConstraintArithmetic.finite((dl-du)*velocity)
        }
        try ConstraintArithmetic.check(policy)
        return ScalarJointLimitResponse(lowerGap:lo,upperGap:hi,lowerJacobian:1,upperJacobian:-1,lowerGapRate:velocity,upperGapRate:-velocity,
            compliantEffort:effort,potentialEnergy:potential,dissipativePower:power)
    }
    private func admit(_ manifold: JointManifold, position: Double, velocity: Double, wrap: JointWrapPolicy,
                       policy: ConstraintEvaluationPolicy, work: inout NumericalWork) throws(ConstraintError) {
        try ConstraintArithmetic.check(policy); try ConstraintArithmetic.charge(4,&work)
        guard position.isFinite, velocity.isFinite else { throw .invalidInput }
        guard manifold.positionCount == 1, manifold.velocityCount == 1, manifold.kind == .revolute || manifold.kind == .prismatic else {
            // FIXME(INCOMPLETE_IMPLEMENTATION): Only scalar revolute/prismatic passive ports are implemented. Coupled/quaternion joint ports require their coordinate-rate/effort map and behavioral proof before success.
            throw .unsupportedDomain
        }
        switch wrap {
        case .unwrapped: break
        // FIXME(INCOMPLETE_IMPLEMENTATION): Periodic limits require a caller-selected branch/discontinuity event contract. This production scalar port refuses wrap substitution until that contract is implemented and verified.
        case .periodic: throw .unsupportedDomain
        }
    }
}
