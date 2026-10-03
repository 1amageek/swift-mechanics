import MechanicsNumerics
public protocol ContactWitnessAdapting: Sendable {
    func prepare(_ binding: WitnessContact, input: ContactResponseInput, policy: ContactResponsePolicy,
                 work: inout NumericalWork) throws(ContactResponseError) -> PreparedContact
}
