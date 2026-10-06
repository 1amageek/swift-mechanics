@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal struct PrismaticCoSimulationParticipant: CoSimulationPhysicalParticipant, Sendable {
    let configuration: CoSimulationParticipantConfiguration
    private let session: any ControlSessionOperating
    init(configuration: CoSimulationParticipantConfiguration, work: inout NumericalWork) throws(CoSimulationFailure) {
        self.configuration=configuration
        do { session=try ReferenceControlSessionFactory().make(plant:configuration.plant,controller:configuration.controller,
            clock:configuration.clock,initialActuator:configuration.initialActuator,seed:configuration.seed,
            policy:configuration.control,work:&work) }
        catch { throw .control(error) }
    }
    func observe() throws(CoSimulationFailure) -> ControlObservation {
        let capture=CoSimulationObservationCapture()
        do { try session.observe { observation throws(ControlFailure) in capture.store(observation) } }
        catch { throw .control(error) }
        guard let actual=capture.read() else { throw .refusal(.originalEvidenceRejected) }
        try validate(actual)
        return actual
    }
    private func validate(_ actual: ControlObservation) throws(CoSimulationFailure) {
        let state=actual.accepted.checkpoint.physical, h=actual.controller
        guard state.q.count == 1, state.v.count == 1, state.q[0].isFinite, state.v[0].isFinite,
              actual.accepted.physical.state == state, actual.accepted.physical.stamp == configuration.plant.model.stamp,
              actual.actuator.binding == configuration.plant.port.binding, actual.actuator.mode == .effort,
              actual.actuator.time == state.time, h.intervalEnd == state.time, !h.pending,
              h.endpointPosition == state.q[0], h.endpointRate == state.v[0] else { throw .refusal(.originalEvidenceRejected) }
        let clockTime: Double
        do { clockTime=try configuration.clock.time(at:h.tick) }
        catch { throw .control(error) }
        guard clockTime == state.time else { throw .refusal(.staleBoundary) }
    }
    func checkpoint() throws(CoSimulationFailure) -> [UInt8] {
        do { return try session.checkpoint(codec:NativeRuntimeCheckpointCodec()) }
        catch { throw .control(error) }
    }
    func verifyCheckpoint(_ bytes: [UInt8], expected: ControlObservation) throws(CoSimulationFailure) {
        do { guard try NativeRuntimeCheckpointCodec().decode(bytes,capacity:configuration.control.runtimeCapacity) == expected.accepted.checkpoint
            else { throw CoSimulationFailure.refusal(.originalEvidenceRejected) } }
        catch let failure as RuntimeFailure { throw .control(ControlFailure(.runtime(failure),phase:"co-simulation-checkpoint")) }
        catch let failure as CoSimulationFailure { throw failure }
        catch { throw .refusal(.originalEvidenceRejected) }
    }
    func advance(from: ControlObservation, effort: Double, work: inout NumericalWork) throws(CoSimulationFailure) -> ControlStepResult {
        let state=from.accepted.checkpoint.physical, servo=configuration.controller.servo
        guard effort.isFinite, abs(effort) <= servo.effortLimit, state.v.count == 1,
              abs(state.v[0]) < servo.speedLimit,
              servo.binding.stateDomain.contains(primary:from.actuator.primary,secondary:effort) else { throw .refusal(.unsupportedDomain) }
        let encoder: JointEncoderObservation
        do {
            let source=try ReferenceObservationSourcePreparer().prepare(model:configuration.plant.model,
                state:from.accepted.physical,solved:nil,policy:configuration.observation,work:&work)
            encoder=try ReferenceKinematicObserver().encoder(source:source,joint:configuration.plant.port.binding.joint,
                policy:configuration.observation,work:&work)
        } catch { throw CoSimulationFailure(.observation(error),unavailable:error.failedSupplierWorkUnavailable) }
        let command: DriveCommand
        do { command=try DriveCommand(mode:.effort,value:effort) }
        catch { throw .control(ControlFailure(.actuation(error),phase:"co-simulation-command")) }
        let input=ControlSampleInput(encoder:encoder,sampleTickTime:state.time,tick:from.controller.tick,
            demand:.servo(command),commandDimension:configuration.plant.port.effortDimension)
        let result: ControlStepResult
        do { result=try session.step(input:input) } catch { throw .control(error) }
        do throws(CoSimulationFailure) {
            try validate(result.observation)
            let h=result.observation.controller
            guard from.controller.tick < UInt64.max, h.tick == from.controller.tick+1, h.issued, !h.clipped,
                  h.sourceTime == state.time, h.sampleTickTime == state.time,
                  h.sampledPosition == state.q[0], h.sampledRate == state.v[0],
                  h.heldEffort == effort, h.requestedEffort == effort,
                  result.integration.accepted == result.observation.accepted, result.integration.reachedRequestedTime,
                  result.integration.acceptedSteps == 1, result.integration.rejectedTrials == 0 else { throw .refusal(.originalEvidenceRejected) }
            return result
        } catch {
            throw CoSimulationFailure(error.cause,unavailable:error.failedSupplierWorkUnavailable,
                supplierAcceptedPrefix:result.integration.accepted)
        }
    }
    func restart(_ bytes: [UInt8]) throws(CoSimulationFailure) {
        do { try session.restart(bytes,codec:NativeRuntimeCheckpointCodec()) } catch { throw .control(error) }
    }
    func shutdown() -> RuntimeShutdownStatus { session.shutdown() }
}
