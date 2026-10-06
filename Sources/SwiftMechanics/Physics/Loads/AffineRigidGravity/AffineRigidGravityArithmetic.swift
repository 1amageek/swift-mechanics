internal enum AffineRigidGravityArithmetic {
    static func core<T>(_ operation: () throws(CoreError) -> T) throws(AffineRigidGravityFailure) -> T {
        do throws(CoreError) { return try operation() } catch { throw .core(error) }
    }

    static func loads<T>(_ operation: () throws(LoadError) -> T) throws(AffineRigidGravityFailure) -> T {
        do throws(LoadError) { return try operation() } catch { throw .loads(error) }
    }

    static func finite(_ value: Double) throws(AffineRigidGravityFailure) -> Double {
        guard value.isFinite else { throw .nonFiniteResult }
        return value
    }

    static func metadata(_ text: String, policy: AffineRigidGravityPolicy,
                         work: inout LoadWork) throws(AffineRigidGravityFailure) {
        var count = 0
        for _ in text.utf8 {
            guard count < policy.maximumIdentityBytes else { throw .loads(.capacityExceeded) }
            try loads { () throws(LoadError) in try work.charge(1) }
            count += 1
        }
    }

    static func traceProduct(_ a: Matrix3, _ b: Matrix3) throws(AffineRigidGravityFailure) -> Double {
        try finite(a.m00*b.m00+a.m01*b.m10+a.m02*b.m20
                   + a.m10*b.m01+a.m11*b.m11+a.m12*b.m21
                   + a.m20*b.m02+a.m21*b.m12+a.m22*b.m22)
    }

    static func secondMoment(_ inertia: Matrix3) throws(AffineRigidGravityFailure) -> Matrix3 {
        let half = try finite(inertia.m00/2+inertia.m11/2+inertia.m22/2)
        let q = try core { () throws(CoreError) in
            try Matrix3(half-inertia.m00, -inertia.m01, -inertia.m02,
                        -inertia.m10, half-inertia.m11, -inertia.m12,
                        -inertia.m20, -inertia.m21, half-inertia.m22)
        }
        let scale = q.maximumMagnitude
        guard scale > 0 else { throw .nonphysicalSecondMoment }
        // Division preserves tiny finite scales; no reciprocal or diagonal shift is introduced.
        let n = try core { () throws(CoreError) in
            try Matrix3(q.m00/scale,q.m01/scale,q.m02/scale,q.m10/scale,q.m11/scale,q.m12/scale,
                        q.m20/scale,q.m21/scale,q.m22/scale)
        }
        guard n.m00 >= 0, n.m11 >= 0, n.m22 >= 0,
              n.m00*n.m11-n.m01*n.m10 >= 0, n.m00*n.m22-n.m02*n.m20 >= 0,
              n.m11*n.m22-n.m12*n.m21 >= 0,
              try core({ () throws(CoreError) in try n.determinant() }) >= 0 else {
            throw .nonphysicalSecondMoment
        }
        return q
    }
}
