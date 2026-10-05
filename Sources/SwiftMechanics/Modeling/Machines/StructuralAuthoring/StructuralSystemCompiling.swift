public protocol StructuralSystemCompiling: Sendable {
    func compile(_ draft: StructuralPhysicsDraft, compilationPolicy: CompilationPolicy,
                 policy: StructuralSystemPolicy, work: inout NumericalWork,
                 transmissionWork: inout NumericalWork, loadWork: inout LoadWork,
                 actuationWork: inout ActuationWork) throws(StructuralSystemFailure) -> StructuralMechanicalSystem
}
