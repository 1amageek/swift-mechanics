public struct ExactScalarDifferentiator: ScalarDifferentiating {
    public init() {}
    public func evaluate(_ operation: SmoothScalarOperation, left: DirectionalScalar, right: DirectionalScalar?,
                         work: inout NumericalWork) throws(DerivativeError) -> DirectionalScalar {
        switch operation {
        case .add, .subtract, .multiply, .divide:
            guard let right else { throw .invalidShape }
            switch operation {
            case .add: return try DifferentialArithmetic.add(left,right,&work)
            case .subtract: return try DifferentialArithmetic.subtract(left,right,&work)
            case .multiply: return try DifferentialArithmetic.multiply(left,right,&work)
            default:
                guard right.value != 0 else { throw .derivativeUnavailable }
                try DifferentialArithmetic.charge(6,&work)
                let value=left.value/right.value
                return try DirectionalScalar(value:value,direction:(left.direction-value*right.direction)/right.value)
            }
        case .squareRoot:
            guard left.value > 0 else { throw .derivativeUnavailable }
            try DifferentialArithmetic.charge(4,&work)
            let value=left.value.squareRoot(); return try DirectionalScalar(value:value,direction:left.direction/(2*value))
        case .sine:
            try DifferentialArithmetic.charge(3,&work)
            return try DirectionalScalar(value:ScalarMath.sine(left.value),direction:ScalarMath.cosine(left.value)*left.direction)
        case .cosine:
            try DifferentialArithmetic.charge(4,&work)
            return try DirectionalScalar(value:ScalarMath.cosine(left.value),direction:-ScalarMath.sine(left.value)*left.direction)
        }
    }
}
