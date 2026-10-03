import MechanicsJoints
import MechanicsCore
import MechanicsNumerics
import MechanicsCompiler
public struct ReferenceDriveEvaluator: DriveEvaluating, Sendable {
    public init() {}
    public func step(law:ScalarServo,state:ActuatorState,sample:ActuatorSample,command:DriveCommand,dt:Double,
                     energyTolerance:NumericalTolerance,work:inout ActuationWork,numerical:inout NumericalWork) throws(ActuationError) -> ActuatorResponse {
        try state.preflight(sample:sample,dt:dt,kind:.servo,work:&work)
        guard law.binding == state.binding else { throw .staleBinding };guard command.mode == state.mode else { throw .incompatibleMode }
        try work.charge(12);try actuationNumerics { () throws(NumericalError) in try numerical.requireStorage(24);try numerical.chargeOperations(90) }
        let target=command.mode == .velocity ? actuationClip(command.value,law.speedLimit) : command.value
        let filtered:Double
        if law.filterTimeConstant == 0 { filtered=target }
        else { let ratio=try actuationFinite(dt/law.filterTimeConstant);filtered=try actuationFinite((state.secondary+ratio*target)/(1+ratio)) }
        let error:Double,base:Double
        switch command.mode {
        case .effort:error=0;base=filtered
        case .velocity:error=deadband(try actuationFinite(filtered-sample.velocity),law.velocityDeadband);base=try actuationFinite(law.velocityGain*error)
        case .position:error=deadband(try actuationFinite(filtered-sample.position),law.positionDeadband);base=try actuationFinite(law.positionGain*error-law.velocityGain*sample.velocity)
        }
        let increment=try actuationFinite(dt*law.integralGain*error)
        let candidate=command.mode == .effort ? state.primary : actuationClip(try actuationFinite(state.primary+increment),law.integralLimit)
        let requested=try actuationFinite(base+(command.mode == .effort ? 0 : candidate))
        let tentative=limited(requested,velocity:sample.velocity,law:law)
        let blocked=command.mode != .effort && ((requested > tentative && increment > 0) || (requested < tentative && increment < 0))
        let integral=blocked ? state.primary : candidate
        let actualRequest=try actuationFinite(base+(command.mode == .effort ? 0 : integral))
        let applied=limited(actualRequest,velocity:sample.velocity,law:law)
        let next=try state.advancing(primary:integral,secondary:filtered,dt:dt)
        let power=try actuationFinite(applied*sample.velocity),energy=try actuationFinite(power*dt)
        let ledger=try ActuatorEnergy(sourceWork:energy,mechanicalWork:energy,storedBefore:0,storedAfter:0,physicalLoss:0,numericalLoss:0,tolerance:energyTolerance)
        try work.charge(0)
        return try ActuatorResponse(state:next,requestedEffort:requested,appliedEffort:applied,power:power,requestedInput:command.value,appliedInput:filtered,
            clipped:requested != applied || target != command.value || blocked,energy:ledger)
    }
    private func deadband(_ value:Double,_ width:Double) -> Double { abs(value) <= width ? 0 : value }
    private func limited(_ effort:Double,velocity:Double,law:ScalarServo) -> Double {
        let clipped=actuationClip(effort,law.effortLimit)
        return abs(velocity) >= law.speedLimit && ((velocity > 0 && clipped > 0) || (velocity < 0 && clipped < 0)) ? 0 : clipped
    }
    public func prescribedVelocity(binding:ActuatorBinding,model:CompiledMechanicalModel,time:Double,requested:Double,speedLimit:Double,
                                   work:inout ActuationWork) throws(ActuationError) -> PrescribedVelocityCommand {
        guard time.isFinite,requested.isFinite,speedLimit.isFinite,speedLimit > 0 else { throw .invalidInput }
        try binding.validate(model:model,work:&work)
        for joint in model.descriptor.joints {
            try work.charge(1)
            if joint.record.id == binding.joint {
                guard joint.authority == .prescribedMotion else { throw .incompatibleAuthority }
                return PrescribedVelocityCommand(binding:binding,time:time,requestedVelocity:requested,appliedVelocity:actuationClip(requested,speedLimit))
            }
        }
        throw .staleBinding
    }
}
