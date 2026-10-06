import SwiftMechanics
internal struct IslandCompilerFault: MechanicalModelCompiling {
    func compile(_ descriptor:MechanicalDescriptor,policy:CompilationPolicy) throws(CompilationFailure) -> CompiledMechanicalModel {
        _=try ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()).compile(descriptor,policy:policy)
        throw .one(.invalidPolicy,.input,message:"Injected failure after genuine bounded compilation.")
    }
}
