/// Source-bound prescribed-root partition and original mathematical validation.
public protocol PrescribedRootBindingProviding: Sendable {
    var knownCoordinates:[Int] { get }
    var dynamicCoordinates:[Int] { get }
    var rowIDs:[UInt64] { get }
    func sample(time:Double,work:inout NumericalWork) throws(GeometricConstraintError) -> PrescribedBaseMotionSample
    func validate(_ state:KinematicState,work:inout NumericalWork) throws(GeometricConstraintError)
}
