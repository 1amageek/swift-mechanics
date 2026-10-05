internal enum ParticleFlowMath {
    static func finite(_ value: Double) throws(ParticleFlowError) -> Double {
        guard value.isFinite else { throw .nonFiniteArithmetic }; return value
    }
    static func add(_ a: Vector3, _ b: Vector3) throws(ParticleFlowError) -> Vector3 {
        do { return try a.adding(b) } catch { throw .core(error) }
    }
    static func sub(_ a: Vector3, _ b: Vector3) throws(ParticleFlowError) -> Vector3 {
        do { return try a.subtracting(b) } catch { throw .core(error) }
    }
    static func scale(_ a: Vector3, _ b: Double) throws(ParticleFlowError) -> Vector3 {
        do { return try a.scaled(by: b) } catch { throw .core(error) }
    }
    static func dot(_ a: Vector3, _ b: Vector3) throws(ParticleFlowError) -> Double {
        do { return try a.dot(b) } catch { throw .core(error) }
    }
    static func norm(_ a: Vector3) throws(ParticleFlowError) -> Double {
        do { return try a.magnitude() } catch { throw .core(error) }
    }
    static func charge(_ amount: Int, _ work: inout NumericalWork) throws(ParticleFlowError) {
        guard !Task.isCancelled else { throw .numerical(.cancelled) }
        do { try work.chargeOperations(amount) } catch { throw .numerical(error) }
    }
    static func row(_ work: inout NumericalWork) throws(ParticleFlowError) {
        do { try work.advanceIteration() } catch { throw .numerical(error) }
    }
    static func power(_ value: Double, _ exponent: Int, _ work: inout NumericalWork) throws(ParticleFlowError) -> Double {
        var n = exponent, factor = value, result = 1.0
        while n > 0 {
            try charge(4, &work)
            if n % 2 == 1 { result = try finite(result * factor) }
            n /= 2
            if n > 0 { factor = try finite(factor * factor) }
        }
        return result
    }
    static func gate(_ value: Double, _ equation: String, _ bound: ParticleFlowResidualScale) throws(ParticleFlowError) {
        let accepted: Bool
        do { accepted = try bound.tolerance.contains(error: value, scale: bound.scale) }
        catch { throw .core(error) }
        guard accepted else { throw .residualRejected(equation: equation, value: value) }
    }
    /// Computes (1+d)^n-1 and its positive remainder after subtracting n*d.
    /// Composition R(a+b)=R(a)+R(b)+T(a)*T(b) avoids cancellation near rho0.
    static func taitRemainder(_ deviation: Double, _ exponent: Int,
                              _ work: inout NumericalWork) throws(ParticleFlowError) -> (offset: Double, remainder: Double) {
        var n = exponent, offset = 0.0, remainder = 0.0
        var factorOffset = deviation, factorRemainder = 0.0
        while n > 0 {
            try charge(16, &work)
            if n % 2 == 1 {
                let product = try finite(offset * factorOffset)
                remainder = try finite(remainder + factorRemainder + product)
                offset = try finite(offset + factorOffset + product)
            }
            n /= 2
            if n > 0 {
                let square = try finite(factorOffset * factorOffset)
                factorRemainder = try finite(2 * factorRemainder + square)
                factorOffset = try finite(2 * factorOffset + square)
            }
        }
        return (offset, remainder)
    }
}
