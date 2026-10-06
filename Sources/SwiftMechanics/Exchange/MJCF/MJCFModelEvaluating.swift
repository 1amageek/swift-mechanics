public protocol MJCFModelEvaluating: Sendable {
    func sample(_ model: MJCFImportedModel, state: CompiledKinematicState, controls: [Double], tolerance: NumericalTolerance,
                work: inout MJCFWork, actuationWork: inout ActuationWork, numericalWork: inout NumericalWork) throws(MJCFError) -> MJCFModelSample
}
