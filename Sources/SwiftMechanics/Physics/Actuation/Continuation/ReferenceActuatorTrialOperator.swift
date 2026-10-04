@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
public struct ReferenceActuatorTrialOperator: ActuatorTrialOperating, Sendable {
    public let codec:any ActuatorContinuationCoding
    public let drives:any DriveEvaluating
    public let registry:any ActuatorBindingLookingUp
    public init(codec:any ActuatorContinuationCoding,drives:any DriveEvaluating,registry:any ActuatorBindingLookingUp) { self.codec=codec;self.drives=drives;self.registry=registry }
    public func servo(law:ScalarServo,command:DriveCommand,dt:Double,tolerance:NumericalTolerance,trial:inout RuntimeTrial,control:inout RuntimeStepControl,
                      work:inout ActuationWork,numerical:inout NumericalWork) throws(RuntimeFailure) -> ActuatorResponse {
        try control.beginWorkBlock(units:1)
        let raw=try trial.contributor(law.binding.actuator.key),time=trial.timeSeconds,q=try trial.position(at:law.binding.positionIndex),v=try trial.velocity(at:law.binding.velocityIndex)
        let response:ActuatorResponse,payload:RuntimeContributorState
        do throws(ActuationError) {
            guard try registry.binding(id:law.binding.actuator.key,work:&work) == law.binding else { throw ActuationError.staleBinding }
            let state=try codec.decode(raw,binding:law.binding,work:&work)
            let sample=try ActuatorSample(binding:law.binding,time:time,position:q,velocity:v)
            response=try drives.step(law:law,state:state,sample:sample,command:command,dt:dt,energyTolerance:tolerance,work:&work,numerical:&numerical)
            payload=try codec.encode(response.state,work:&work)
        } catch { throw actuationRuntimeFailure(error,id:law.binding.actuator.key) }
        try control.beginWorkBlock(units:1)
        try trial.replaceContributor(payload)
        // Physical integrator owns q/v and trial time; caller must advance time to response.state.time before acceptance.
        return response
    }
}
