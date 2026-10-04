public struct ActuatorState: Equatable, Sendable {
    public let binding:ActuatorBinding
    public let time:Double,primary:Double,secondary:Double
    public let mode:DriveMode
    public let sequence:UInt64
    public init(binding:ActuatorBinding,time:Double,primary:Double,secondary:Double=0,mode:DriveMode = .effort,sequence:UInt64=0) throws(ActuationError) {
        guard time.isFinite,binding.stateDomain.contains(primary:primary,secondary:secondary) else { throw .outsideDomain }
        guard binding.stateKind == .servo || (mode == .effort && secondary == 0) else { throw .incompatibleMode }
        self.binding=binding;self.time=time;self.primary=primary;self.secondary=secondary;self.mode=mode;self.sequence=sequence
    }
    internal func preflight(sample:ActuatorSample,dt:Double,kind:ActuatorStateKind,work:inout ActuationWork) throws(ActuationError) {
        try work.metadata(binding.model.identity);try work.metadata(binding.actuator.key);try work.metadata(binding.joint.key);try work.metadata(binding.frame.key)
        try work.charge(8)
        guard binding == sample.binding,binding.stateKind == kind else { throw .staleBinding }
        guard binding.authority == .dynamicState else { throw .incompatibleAuthority }
        guard time == sample.time else { throw .staleTime }
        guard dt.isFinite,dt >= 0 else { throw .invalidInput }
        _=try actuationFinite(time+dt)
        if dt > 0 && sequence == UInt64.max { throw .sequenceOverflow }
    }
    internal func advancing(primary:Double,secondary:Double,dt:Double) throws(ActuationError) -> ActuatorState {
        if dt == 0 { return self }
        return try ActuatorState(binding:binding,time:actuationFinite(time+dt),primary:primary,secondary:secondary,mode:mode,sequence:sequence+1)
    }
}
