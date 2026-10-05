public struct ControlHistory: Sendable {
    public let tick:UInt64
    public let issued:Bool
    public let pending:Bool
    public let sourceTime:Double,sampleTickTime:Double,intervalEnd:Double
    public let sampledPosition:Double,sampledRate:Double,requestedEffort:Double,heldEffort:Double
    public let nominalSampledWork:Double,actuatorIntervalWork:Double,disturbanceIntervalWork:Double
    public let initialKineticEnergy:Double,endpointKineticEnergy:Double,forceResidual:Double
    public let endpointPosition:Double,endpointRate:Double
    public let clipped:Bool
    internal init(tick:UInt64,issued:Bool,pending:Bool,sourceTime:Double,sampleTickTime:Double,intervalEnd:Double,
                  sampledPosition:Double,sampledRate:Double,requestedEffort:Double,heldEffort:Double,nominalSampledWork:Double,
                  actuatorIntervalWork:Double,disturbanceIntervalWork:Double,initialKineticEnergy:Double,endpointKineticEnergy:Double,
                  forceResidual:Double,endpointPosition:Double,endpointRate:Double,clipped:Bool) {
        self.tick=tick;self.issued=issued;self.pending=pending;self.sourceTime=sourceTime;self.sampleTickTime=sampleTickTime;self.intervalEnd=intervalEnd
        self.sampledPosition=sampledPosition;self.sampledRate=sampledRate;self.requestedEffort=requestedEffort;self.heldEffort=heldEffort
        self.nominalSampledWork=nominalSampledWork;self.actuatorIntervalWork=actuatorIntervalWork;self.disturbanceIntervalWork=disturbanceIntervalWork
        self.initialKineticEnergy=initialKineticEnergy;self.endpointKineticEnergy=endpointKineticEnergy;self.forceResidual=forceResidual
        self.endpointPosition=endpointPosition;self.endpointRate=endpointRate;self.clipped=clipped
    }
}
