import MechanicsRuntime
import MechanicsNumerics

@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
public protocol MechanismBreaking: Sendable {
    func prepare(source:RuntimeAcceptedState,transition:DetachedLeafTransition,reaction:ConstrainedMotion,thresholdSI:Double,
                 eventID:UInt64,maximumEventBytes:Int,work:inout NumericalWork) throws(MechanismError) -> PreparedMechanismBreak?
    func publish(_ prepared:PreparedMechanismBreak,session:any RuntimeModelReplacing,configuration:RuntimeConfiguration,
                 contributors:[RuntimeContributorState],checkpoints:any RuntimeCheckpointHandling) throws(MechanismError) -> RuntimeAcceptedState
}
