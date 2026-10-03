import MechanicsNumerics
public protocol BeamAssembling: Sendable {
    func assemble(_ beam: UniformBeam, admission: BeamAdmission, work: inout NumericalWork) throws(BeamError) -> BeamAssembly
}
