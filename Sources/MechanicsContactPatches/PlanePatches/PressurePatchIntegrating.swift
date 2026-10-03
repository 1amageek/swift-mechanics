import MechanicsCore
import MechanicsNumerics
public protocol PressurePatchIntegrating: Sendable {
    func integrate(_ compliant: PressureBody, against rigid: PatchRepresentation, origin: Vector3, policy: PatchPolicy,
                   workspace: inout PatchWorkspace, work: inout NumericalWork) throws(PatchError) -> PressurePatchResult
}
