/// The six section kinematic fields and original strain rows, each row-major 6 by 12.
internal struct SpatialBeamInterpolation {
    let kinematics: [Double]
    let strain: [Double]
    let slopes: [Double]
    let curvatureGradient: [Double]

    init(xi: Double, length l: Double, factors: [Double]) throws(SpatialBeamError) {
        var n = [Double](repeating: 0, count: 72), b = n
        var slope = [Double](repeating: 0, count: 24), gradient = slope
        let inv = try SpatialBeamAlgebra.positive(1 / l)
        n[0] = 1 - xi; n[6] = xi
        n[3 * 12 + 3] = 1 - xi; n[3 * 12 + 9] = xi
        b[0] = -inv; b[6] = inv
        b[3 * 12 + 3] = -inv; b[3 * 12 + 9] = inv
        for plane in 0..<2 {
            let s = factors[plane * 2], h = factors[plane * 2 + 1]
            let f = s * (3 * xi * xi - 2 * xi * xi * xi) + h * xi
            let fd = s * (6 * xi - 6 * xi * xi) + h
            let c = 6 * s * xi * (1 - xi)
            let t = 1 - 2 * xi
            let displacement = [1 - f, l * (xi - xi * xi / 2 - f / 2), f, l * (xi * xi / 2 - f / 2)]
            let rotation = [-c * inv, 1 - xi - c / 2, c * inv, xi - c / 2]
            let derivative = [-fd * inv, 1 - xi - fd / 2, fd * inv, xi - fd / 2]
            let curvature = [-6 * s * t * inv * inv, (-1 - 3 * s * t) * inv,
                             6 * s * t * inv * inv, (1 - 3 * s * t) * inv]
            let curvatureDerivative = [12 * s * inv * inv * inv, 6 * s * inv * inv,
                                       -12 * s * inv * inv * inv, 6 * s * inv * inv]
            let shear = [-h * inv, -h / 2, h * inv, -h / 2]
            let indices = plane == 0 ? [1, 5, 7, 11] : [2, 4, 8, 10]
            let displacementRow = plane + 1, rotationRow = plane == 0 ? 5 : 4
            let curvatureRow = rotationRow, rotationSign = plane == 0 ? 1.0 : -1.0
            let gradientRow = plane == 0 ? 1 : 0
            for k in 0..<4 {
                let sign = plane == 1 && (k == 1 || k == 3) ? -1.0 : 1.0
                let index = indices[k]
                n[displacementRow * 12 + index] = displacement[k] * sign
                n[rotationRow * 12 + index] = rotationSign * rotation[k] * sign
                b[(plane + 1) * 12 + index] = shear[k] * sign
                b[curvatureRow * 12 + index] = rotationSign * curvature[k] * sign
                slope[plane * 12 + index] = derivative[k] * sign
                gradient[gradientRow * 12 + index] = rotationSign * curvatureDerivative[k] * sign
            }
        }
        guard n.allSatisfy({ $0.isFinite }), b.allSatisfy({ $0.isFinite }),
              slope.allSatisfy({ $0.isFinite }), gradient.allSatisfy({ $0.isFinite }) else { throw .nonFiniteResult }
        kinematics = n; strain = b; slopes = slope; curvatureGradient = gradient
    }
}
