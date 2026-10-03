import MechanicsCore
import MechanicsNumerics
public struct ReferenceLumpedActuatorEvaluator: LumpedActuatorEvaluating, Sendable {
    public init() {}
    public func motor(law:DCMotorLaw,state:ActuatorState,sample:ActuatorSample,voltage:Double,dt:Double,tolerance:NumericalTolerance,
                      work:inout ActuationWork,numerical:inout NumericalWork) throws(ActuationError) -> ActuatorResponse {
        try state.preflight(sample:sample,dt:dt,kind:.motor,work:&work)
        guard state.binding == law.binding else { throw .staleBinding }
        guard voltage.isFinite,abs(sample.velocity) <= law.maximumSpeed else { throw .outsideDomain }
        try work.charge(8);try actuationNumerics { () throws(NumericalError) in try numerical.requireStorage(24);try numerical.chargeOperations(100) }
        let input=actuationClip(voltage,law.maximumVoltage),w=sample.velocity,l=law.inductanceHenries,r=law.resistanceOhms,k=law.reciprocalConstant
        let denominator=try actuationFinite(l+dt*r)
        let current=try actuationFinite((l*state.primary+dt*(input-k*w))/denominator)
        guard abs(current) <= law.maximumCurrent else { throw .outsideDomain }
        let effort=try actuationFinite(k*current-law.viscousDamping*w),power=try actuationFinite(effort*w)
        let requestedCurrent=try actuationFinite((l*state.primary+dt*(voltage-k*w))/denominator)
        let requested=try actuationFinite(k*requestedCurrent-law.viscousDamping*w)
        let before=try actuationFinite(0.5*l*state.primary*state.primary),after=try actuationFinite(0.5*l*current*current)
        let physical=try actuationFinite(dt*(r*current*current+law.viscousDamping*w*w)),numericalLoss=try actuationFinite(0.5*l*(current-state.primary)*(current-state.primary))
        let ledger=try ActuatorEnergy(sourceWork:actuationFinite(input*current*dt),mechanicalWork:actuationFinite(power*dt),storedBefore:before,storedAfter:after,physicalLoss:physical,numericalLoss:numericalLoss,tolerance:tolerance)
        let next=try state.advancing(primary:current,secondary:0,dt:dt);try work.charge(0)
        return try ActuatorResponse(state:next,requestedEffort:requested,appliedEffort:effort,power:power,requestedInput:voltage,appliedInput:input,clipped:input != voltage,energy:ledger)
    }
    public func chamber(law:LinearChamberLaw,state:ActuatorState,sample:ActuatorSample,flow:Double,dt:Double,tolerance:NumericalTolerance,
                        work:inout ActuationWork,numerical:inout NumericalWork) throws(ActuationError) -> ActuatorResponse {
        try state.preflight(sample:sample,dt:dt,kind:.fluid,work:&work)
        guard state.binding == law.binding else { throw .staleBinding };guard flow.isFinite else { throw .invalidInput }
        try work.charge(8);try actuationNumerics { () throws(NumericalError) in try numerical.requireStorage(24);try numerical.chargeOperations(100) }
        let end=try actuationFinite(sample.position+sample.velocity*dt)
        guard abs(sample.position) <= law.maximumStroke,abs(end) <= law.maximumStroke,
              abs(try actuationFinite(law.area*sample.position/law.referenceVolume)) <= law.maximumRelativeVolumeChange,
              abs(try actuationFinite(law.area*end/law.referenceVolume)) <= law.maximumRelativeVolumeChange else { throw .outsideDomain }
        let input=actuationClip(flow,law.maximumFlow),c=law.compliance
        let denominator=try actuationFinite(c+dt*law.leakage)
        let pressure=try actuationFinite((c*state.primary+dt*(input-law.area*sample.velocity))/denominator)
        guard pressure >= 0,pressure <= law.maximumPressure else { throw .outsideDomain }
        let requestedPressure=try actuationFinite((c*state.primary+dt*(flow-law.area*sample.velocity))/denominator)
        let effort=try actuationFinite(law.area*pressure),power=try actuationFinite(effort*sample.velocity)
        let before=try actuationFinite(0.5*c*state.primary*state.primary),after=try actuationFinite(0.5*c*pressure*pressure)
        let physical=try actuationFinite(dt*law.leakage*pressure*pressure),numericalLoss=try actuationFinite(0.5*c*(pressure-state.primary)*(pressure-state.primary))
        let ledger=try ActuatorEnergy(sourceWork:actuationFinite(input*pressure*dt),mechanicalWork:actuationFinite(power*dt),storedBefore:before,storedAfter:after,physicalLoss:physical,numericalLoss:numericalLoss,tolerance:tolerance)
        let next=try state.advancing(primary:pressure,secondary:0,dt:dt);try work.charge(0)
        return try ActuatorResponse(state:next,requestedEffort:actuationFinite(law.area*requestedPressure),appliedEffort:effort,power:power,requestedInput:flow,appliedInput:input,clipped:input != flow,energy:ledger)
    }
    public func muscle(law:SelectedMuscleLaw,state:ActuatorState,sample:ActuatorSample,activation:Double,dt:Double,tolerance:NumericalTolerance,
                       work:inout ActuationWork,numerical:inout NumericalWork) throws(ActuationError) -> ActuatorResponse {
        try state.preflight(sample:sample,dt:dt,kind:.muscle,work:&work)
        guard state.binding == law.binding else { throw .staleBinding };guard activation.isFinite else { throw .invalidInput }
        try work.charge(8);try actuationNumerics { () throws(NumericalError) in try numerical.requireStorage(32);try numerical.chargeOperations(120) }
        let end=try actuationFinite(sample.position+sample.velocity*dt),low=law.optimalLength-law.lengthWidth,high=try actuationFinite(law.optimalLength+law.lengthWidth)
        guard sample.position >= low,sample.position <= high,end >= low,end <= high,
              sample.velocity >= -law.maximumShorteningSpeed,sample.velocity <= law.maximumLengtheningSpeed else { throw .outsideDomain }
        let input=min(1,max(0,activation)),ratio=try actuationFinite(dt/law.activationTimeConstant)
        let active=try actuationFinite((state.primary+ratio*input)/(1+ratio))
        let fl=max(0,1-abs(end-law.optimalLength)/law.lengthWidth),z=try actuationFinite(sample.velocity/law.maximumShorteningSpeed)
        let fv=sample.velocity <= 0 ? (1+z)/(1-z/law.hillCurvature) : (1+law.eccentricGain*z)/(1+z)
        let activeForce=try actuationFinite(law.maximumForce*active*fl*fv),stretch0=max(0,sample.position-law.slackLength),stretch1=max(0,end-law.slackLength)
        let passive=try actuationFinite(law.passiveStiffness*stretch1),effort=try actuationFinite(-activeForce-passive),power=try actuationFinite(effort*sample.velocity)
        let before=try actuationFinite(0.5*law.passiveStiffness*stretch0*stretch0),after=try actuationFinite(0.5*law.passiveStiffness*stretch1*stretch1)
        let loss=try actuationFinite(passive*(end-sample.position)-(after-before))
        guard loss >= 0 else { throw .residualMismatch }
        let ledger=try ActuatorEnergy(sourceWork:actuationFinite(-activeForce*sample.velocity*dt),mechanicalWork:actuationFinite(power*dt),storedBefore:before,storedAfter:after,physicalLoss:0,numericalLoss:loss,tolerance:tolerance)
        let next=try state.advancing(primary:active,secondary:0,dt:dt);try work.charge(0)
        return try ActuatorResponse(state:next,requestedEffort:effort,appliedEffort:effort,power:power,requestedInput:activation,appliedInput:input,clipped:activation != input,energy:ledger)
    }
}
