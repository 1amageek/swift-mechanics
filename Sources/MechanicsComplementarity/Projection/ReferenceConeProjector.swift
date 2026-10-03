import MechanicsNumerics

public struct ReferenceConeProjector: ConeProjecting, Sendable {
    public init() {}

    public func project(_ input: [Double], cone: ConeLayout, into output: inout [Double], work: inout NumericalWork) throws(ComplementarityError) {
        try complementarityNumerical { () throws(NumericalError) in try work.requireStorage(NumericalWork.sum(NumericalWork.product(2, input.count), cone.coefficientCount)) }
        try validate(input, cone: cone, work: &work)
        guard output.count == input.count else { throw .numerical(.invalidDimensions) }
        switch cone {
        case .nonnegativeOrthant:
            for i in input.indices {
                try complementarityCancelled()
                try charge(2, work: &work)
                output[i] = max(0, input[i])
            }
        case .associatedFrictionCones(let coefficients):
            for block in coefficients.indices {
                try complementarityCancelled()
                try charge(40, work: &work)
                let index = 3 * block, mu = coefficients[block], n = input[index]
                let r = try norm(input[index + 1], input[index + 2])
                let radius = try complementarityFinite(mu * n)
                if n >= 0, r <= radius {
                    output[index] = n; output[index + 1] = input[index + 1]; output[index + 2] = input[index + 2]
                } else {
                    let numerator = try complementarityFinite(n + mu * r)
                    if numerator <= 0 {
                        output[index] = 0; output[index + 1] = 0; output[index + 2] = 0
                    } else {
                        let projectedNormal = numerator / (1 + mu * mu)
                        let projectedRadius = try complementarityFinite(mu * projectedNormal)
                        output[index] = projectedNormal
                        if r == 0 {
                            output[index + 1] = 0; output[index + 2] = 0
                        } else {
                            output[index + 1] = try complementarityFinite(projectedRadius * (input[index + 1] / r))
                            output[index + 2] = try complementarityFinite(projectedRadius * (input[index + 2] / r))
                        }
                    }
                }
            }
        case .nonAssociatedCoulomb: throw .unsupportedLaw
        }
    }

    public func violation(_ input: [Double], cone: ConeLayout, dual: Bool, work: inout NumericalWork) throws(ComplementarityError) -> Double {
        try complementarityNumerical { () throws(NumericalError) in try work.requireStorage(NumericalWork.sum(input.count, cone.coefficientCount)) }
        try validate(input, cone: cone, work: &work)
        var result = 0.0
        switch cone {
        case .nonnegativeOrthant:
            for i in input.indices {
                try complementarityCancelled(); try charge(2, work: &work)
                result = max(result, -input[i])
            }
        case .associatedFrictionCones(let coefficients):
            for block in coefficients.indices {
                try complementarityCancelled(); try charge(24, work: &work)
                let index = 3 * block, n = input[index], mu = coefficients[block]
                let r = try norm(input[index + 1], input[index + 2])
                let violation: Double
                if dual { violation = try complementarityFinite(mu * r - n) }
                else { violation = max(-n, try complementarityFinite(r - mu * n)) }
                result = max(result, violation)
            }
        case .nonAssociatedCoulomb: throw .unsupportedLaw
        }
        return result
    }

    private func validate(_ input: [Double], cone: ConeLayout, work: inout NumericalWork) throws(ComplementarityError) {
        try complementarityCancelled()
        // Includes cone-domain comparisons and scanning finite input entries.
        let dimension: Int
        switch cone {
        case .nonnegativeOrthant(let n), .nonAssociatedCoulomb(let n): dimension = max(0, n)
        case .associatedFrictionCones(let coefficients):
            dimension = try complementarityNumerical { () throws(NumericalError) in try NumericalWork.product(3, coefficients.count) }
        }
        let cost = try complementarityNumerical { () throws(NumericalError) in try NumericalWork.product(6, max(input.count, dimension)) }
        try charge(cost, work: &work)
        guard input.count == (try cone.validatedDimension()) else { throw .numerical(.invalidDimensions) }
        guard input.allSatisfy({ $0.isFinite }) else { throw .numerical(.nonFiniteInput) }
    }

    private func norm(_ first: Double, _ second: Double) throws(ComplementarityError) -> Double {
        let scale = max(abs(first), abs(second))
        if scale == 0 { return 0 }
        let a = first / scale, b = second / scale
        return try complementarityFinite(scale * (a * a + b * b).squareRoot())
    }

    private func charge(_ count: Int, work: inout NumericalWork) throws(ComplementarityError) {
        try complementarityNumerical { () throws(NumericalError) in try work.chargeOperations(count) }
    }
}
