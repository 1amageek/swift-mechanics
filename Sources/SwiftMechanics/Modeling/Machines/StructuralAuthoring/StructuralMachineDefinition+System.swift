extension StructuralMachineDefinition {
    public func compileSystem(using compiler: any StructuralSystemCompiling,
        definitionPolicy: MachineDefinitionPolicy, compilationPolicy: CompilationPolicy,
        policy: StructuralSystemPolicy, work: inout NumericalWork, transmissionWork: inout NumericalWork,
        loadWork: inout LoadWork, actuationWork: inout ActuationWork
    ) throws(StructuralSystemFailure) -> StructuralMechanicalSystem {
        let draft: StructuralPhysicsDraft
        do { draft = try makePhysicsDraft(definitionPolicy: definitionPolicy, compilationPolicy: compilationPolicy) }
        catch { throw .definition(error) }
        return try compiler.compile(draft, compilationPolicy: compilationPolicy, policy: policy,
            work: &work, transmissionWork: &transmissionWork, loadWork: &loadWork, actuationWork: &actuationWork)
    }
}
