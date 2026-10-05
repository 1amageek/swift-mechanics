public protocol ExternalCommandScheduling: Sendable {
    func bind(binding: ActuatorBinding, model: CompiledMechanicalModel, producer: String,
              configurationRevision: UInt64, mode: DriveMode, clock: ControlClock,
              delaySeconds: Double, maximumAgeSeconds: Double, maximumGapSeconds: Double,
              interpolation: ExternalCommandInterpolation, actuationWork: inout ActuationWork,
              work: inout ExternalCommandWork) throws(ExternalCommandError) -> ExternalCommandCheckpoint
    func append(_ packets: [ExternalCommandPacket], to checkpoint: ExternalCommandCheckpoint,
                converter: any UnitConverting, work: inout ExternalCommandWork)
        throws(ExternalCommandError) -> ExternalCommandCheckpoint
    func select(tick: UInt64, from checkpoint: ExternalCommandCheckpoint, work: inout ExternalCommandWork)
        throws(ExternalCommandError) -> ExternalCommandSelection
    func drive(tick: UInt64, from checkpoint: ExternalCommandCheckpoint, law: ScalarServo,
               state: ActuatorState, sample: ActuatorSample, evaluator: any DriveEvaluating,
               energyTolerance: NumericalTolerance, actuationWork: inout ActuationWork,
               numericalWork: inout NumericalWork, work: inout ExternalCommandWork)
        throws(ExternalCommandError) -> ExternalDriveStep
    func prune(_ checkpoint: ExternalCommandCheckpoint, work: inout ExternalCommandWork)
        throws(ExternalCommandError) -> ExternalCommandCheckpoint
    func restore(stream: ExternalCommandStream, packets: [ExternalCommandPacket], lastTick: UInt64?,
                 converter: any UnitConverting, work: inout ExternalCommandWork)
        throws(ExternalCommandError) -> ExternalCommandCheckpoint
}
