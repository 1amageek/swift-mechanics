public protocol LoadMapping: Sendable {
    func point(_ load: FramedPointLoad, jacobian: PointJacobian, rate: [Double], work: inout LoadWork) throws(LoadError) -> GeneralizedLoad
    func wrench(_ wrench: SpatialWrench, load: FramedPointLoad, jacobian: KinematicJacobian,
                rate: [Double], work: inout LoadWork) throws(LoadError) -> [Double]
    func impulse(_ impulse: FramedImpulse, jacobian: KinematicJacobian, work: inout LoadWork) throws(LoadError) -> [Double]
}
