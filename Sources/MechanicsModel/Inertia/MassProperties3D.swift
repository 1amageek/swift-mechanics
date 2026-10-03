import MechanicsCore

public struct MassProperties3D: Equatable, Sendable {
    public let origin: MassPropertyOrigin
    public let mass: Double
    public let centerOfMass: Vector3
    public let inertiaAtCenter: Matrix3

    public init(mass: Double, centerOfMass: Vector3, inertiaAtCenter input: Matrix3,
                policy: InertiaValidationPolicy, origin: MassPropertyOrigin = .supplied) throws {
        guard mass.isFinite, mass > 0 else { throw ModelError.invalidMass }
        let scale = input.maximumMagnitude
        guard try policy.symmetry.contains(error: input.m01 - input.m10, scale: scale),
              try policy.symmetry.contains(error: input.m02 - input.m20, scale: scale),
              try policy.symmetry.contains(error: input.m12 - input.m21, scale: scale) else {
            throw ModelError.asymmetricInertia
        }
        // Accepted symmetry roundoff is explicitly canonicalized by averaging.
        let a = input.m00, b = input.m01 / 2 + input.m10 / 2,
            c = input.m02 / 2 + input.m20 / 2, d = input.m11,
            e = input.m12 / 2 + input.m21 / 2, f = input.m22
        let canonical = try Matrix3(a, b, c, b, d, e, c, e, f)
        guard scale > 0 else { throw ModelError.nonPositiveInertia }
        let n = try Matrix3(a / scale, b / scale, c / scale, b / scale, d / scale, e / scale, c / scale, e / scale, f / scale)
        // Sylvester's criterion proves positive inertia on all three rotational DOF.
        guard n.m00 > 0, n.m00 * n.m11 - n.m01 * n.m01 > 0,
              try n.determinant() > 0 else { throw ModelError.nonPositiveInertia }
        let halfTrace = n.m00 / 2 + n.m11 / 2 + n.m22 / 2
        // A dimensionless diagonal shift bounds the negative eigenvalue itself;
        // tolerating each determinant independently would admit nonphysical slender tensors.
        let shift = policy.physicalityRelative
        let s = try Matrix3(halfTrace - n.m00 + shift, -n.m01, -n.m02,
                            -n.m01, halfTrace - n.m11 + shift, -n.m12,
                            -n.m02, -n.m12, halfTrace - n.m22 + shift)
        guard s.m00 >= 0, s.m11 >= 0, s.m22 >= 0,
              s.m00 * s.m11 - s.m01 * s.m01 >= 0,
              s.m00 * s.m22 - s.m02 * s.m02 >= 0,
              s.m11 * s.m22 - s.m12 * s.m12 >= 0,
              try s.determinant() >= 0 else { throw ModelError.nonphysicalInertia }
        self.origin = origin
        self.mass = mass
        self.centerOfMass = centerOfMass
        self.inertiaAtCenter = canonical
    }

    public func transformed(by transform: RigidTransform, policy: InertiaValidationPolicy) throws -> MassProperties3D {
        try MassProperties3D(mass: mass,
                             centerOfMass: transform.transforming(point: centerOfMass),
                             inertiaAtCenter: InertiaTransformer().rotated(inertiaAtCenter, by: transform.rotation),
                             policy: policy, origin: origin)
    }
}
