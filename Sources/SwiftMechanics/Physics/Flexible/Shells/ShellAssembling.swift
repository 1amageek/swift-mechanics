public protocol ShellAssembling: Sendable {
    func assemble(_ plate: RectangularShellPlate, state: ShellNodalState, admission: ShellAdmission,
                  work: inout NumericalWork) throws(ShellError) -> ShellAssembly
}
