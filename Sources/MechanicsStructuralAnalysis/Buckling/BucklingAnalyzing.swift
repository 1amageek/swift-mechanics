import MechanicsFlexible
import MechanicsNumerics
public protocol BucklingAnalyzing: Sendable {
    func beam(_ assembly: BeamAssembly,fixedCoordinates: [Int],expectedRevision: UInt64,policy: StructuralPolicy,
              work: inout NumericalWork) throws(StructuralError) -> BeamBucklingResult
    func truss(_ model: NonlinearTruss,height: Double,expectedRevision: UInt64,policy: StructuralPolicy,
               work: inout NumericalWork) throws(StructuralError) -> TrussPoint
    func continueTruss(_ model: NonlinearTruss,heights: [Double],descending: Bool,expectedRevision: UInt64,
                       policy: StructuralPolicy,work: inout NumericalWork) throws(StructuralError) -> TrussContinuation
    func criticalTruss(_ model: NonlinearTruss,lowerHeight: Double,upperHeight: Double,positionTolerance: Double,
                       expectedRevision: UInt64,policy: StructuralPolicy,work: inout NumericalWork) throws(StructuralError) -> TrussCriticalPoint
    func nonlinearBeam(_ assembly: BeamAssembly,policy: StructuralPolicy,work: inout NumericalWork) throws(StructuralError) -> BeamBucklingResult
}
