import MechanicsCompiler
import MechanicsJoints

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol RuntimeWorldCreating: Sendable {
    associatedtype Session: RuntimeSessionOperating
    func create(model: CompiledMechanicalModel, configuration: RuntimeConfiguration, initialState: KinematicState,
                contributors: [RuntimeContributorState], rootSeed: UInt64, count: Int) throws(RuntimeFailure) -> [Session]
}
