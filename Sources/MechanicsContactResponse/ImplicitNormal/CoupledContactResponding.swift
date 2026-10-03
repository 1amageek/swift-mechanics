import MechanicsNumerics
import MechanicsContactLaws
public protocol CoupledContactResponding: Sendable {
    func solve(_ input: ContactResponseInput, policy: ContactResponsePolicy,
               responseWork: inout NumericalWork, dynamicsWork: inout NumericalWork, coneWork: inout NumericalWork,
               lawWork: inout ContactWork) throws(ContactResponseError) -> ContactResponseSolution
}
