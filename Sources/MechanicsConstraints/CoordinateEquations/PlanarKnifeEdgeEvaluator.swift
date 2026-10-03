import CMechanicsMath
import MechanicsCore
import MechanicsNumerics

public struct PlanarKnifeEdgeEvaluator: KnifeEdgeEvaluating {
    public init() {}
    public func evaluate(layout: ConstraintCoordinateLayout, rowID: UInt64, position: [Double], velocity: [Double],
                         policy: ConstraintEvaluationPolicy, work: inout NumericalWork) throws(ConstraintError) -> VelocityConstraintSample {
        try ConstraintArithmetic.check(policy)
        guard policy.maximumCoordinates >= 3, layout.scales.count == 3, position.count == 3, velocity.count == 3,
              layout.revision == policy.expectedLayoutRevision else { throw .invalidDimensions }
        try ConstraintArithmetic.storage(8,&work); try ConstraintArithmetic.charge(30,&work)
        guard layout.dimensions[0] == .length, layout.dimensions[1] == .length, layout.dimensions[2] == .angle,
              layout.scales[0].isFinite, layout.scales[0] > 0, layout.scales[0] == layout.scales[1], layout.scales[2] == 1 else { throw .invalidInput }
        for i in 0..<3 {
            guard position[i].isFinite, velocity[i].isFinite else { throw .invalidInput }
            for j in 0..<i { guard layout.coordinateIDs[i] != layout.coordinateIDs[j] else { throw .invalidInput } }
        }
        let theta=position[2], sine=sm_sin(theta), cosine=sm_cos(theta)
        let ux=velocity[0]*layout.timeScale/layout.scales[0], uy=velocity[1]*layout.timeScale/layout.scales[1], omega=velocity[2]*layout.timeScale
        let bias=try ConstraintArithmetic.finite(-omega*(cosine*ux+sine*uy))
        try ConstraintArithmetic.check(policy)
        return VelocityConstraintSample(layout:layout,rowIDs:[rowID],rows:[-sine,cosine,0],drift:[0],accelerationBias:[bias],isIntegrable:false)
    }
}
