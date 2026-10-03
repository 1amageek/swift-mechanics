import MechanicsNumerics

public protocol ConeProjecting: Sendable {
    func project(_ input: [Double], cone: ConeLayout, into output: inout [Double], work: inout NumericalWork) throws(ComplementarityError)
    func violation(_ input: [Double], cone: ConeLayout, dual: Bool, work: inout NumericalWork) throws(ComplementarityError) -> Double
}
