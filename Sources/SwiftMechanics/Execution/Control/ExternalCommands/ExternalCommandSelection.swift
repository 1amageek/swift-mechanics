public struct ExternalCommandSelection: Sendable {
    public let command: DriveCommand
    public let actuator: ActuatorBinding
    public let tick: UInt64
    public let applicationTimeSeconds: Double
    public let targetSourceTimeSeconds: Double
    public let firstPacket: ExternalCommandPacket
    public let secondPacket: ExternalCommandPacket?
    public let firstWeight: Double
    public let secondWeight: Double
    public let firstValueInSI: Double
    public let secondValueInSI: Double?
    public let nextCheckpoint: ExternalCommandCheckpoint
    internal init(command: DriveCommand, actuator: ActuatorBinding, tick: UInt64,
                  applicationTimeSeconds: Double, targetSourceTimeSeconds: Double,
                  firstPacket: ExternalCommandPacket, secondPacket: ExternalCommandPacket?,
                  firstWeight: Double, secondWeight: Double, firstValueInSI: Double,
                  secondValueInSI: Double?, nextCheckpoint: ExternalCommandCheckpoint) {
        self.command = command; self.actuator = actuator; self.tick = tick
        self.applicationTimeSeconds = applicationTimeSeconds; self.targetSourceTimeSeconds = targetSourceTimeSeconds
        self.firstPacket = firstPacket; self.secondPacket = secondPacket
        self.firstWeight = firstWeight; self.secondWeight = secondWeight
        self.firstValueInSI = firstValueInSI; self.secondValueInSI = secondValueInSI
        self.nextCheckpoint = nextCheckpoint
    }
}
