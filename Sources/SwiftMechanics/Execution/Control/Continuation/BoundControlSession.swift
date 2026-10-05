import Synchronization

@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal final class BoundControlSession: ControlSessionOperating, Sendable {
    private let session:any RuntimeSessionOperating
    private let operation=Mutex(false)
    private let plant:PrismaticControlPlant
    private let controller:SampledController
    private let clock:ControlClock
    private let policy:ControlPolicy
    private let provider:ControlContributorProvider
    private let descriptor:ODEDescriptor
    private let drives:any DriveEvaluating
    private let equations:any RigidEquationComputing
    private let dynamics:any RigidDynamicsSolving
    private let integrator:any ExplicitIntegrating
    init(session:any RuntimeSessionOperating,plant:PrismaticControlPlant,controller:SampledController,clock:ControlClock,policy:ControlPolicy,
         provider:ControlContributorProvider,descriptor:ODEDescriptor,drives:any DriveEvaluating,equations:any RigidEquationComputing,
         dynamics:any RigidDynamicsSolving,integrator:any ExplicitIntegrating) {
        self.session=session;self.plant=plant;self.controller=controller;self.clock=clock;self.policy=policy;self.provider=provider
        self.descriptor=descriptor;self.drives=drives;self.equations=equations;self.dynamics=dynamics;self.integrator=integrator
    }
    private func begin() throws(ControlFailure) {
        try operation.withLock { busy throws(ControlFailure) in
            guard !busy else { throw ControlFailure(.busy,phase:"session") };busy=true
        }
    }
    private func end() { operation.withLock { $0=false } }
    private func decode(_ accepted:RuntimeAcceptedState) throws(ControlFailure) -> ControlObservation {
        guard let c=accepted.checkpoint.contributors.first(where:{$0.id == provider.codec.schema.id}),
              let a=accepted.checkpoint.contributors.first(where:{$0.id == controller.servo.binding.actuator.key}) else { throw ControlFailure(.invalidSupplierOutput,phase:"observe") }
        var work=ActuationWork(budget:policy.actuation)
        do { return ControlObservation(accepted:accepted,controller:try provider.codec.history(c),actuator:try provider.actuator.codec.decode(a,binding:controller.servo.binding,work:&work)) }
        catch let error as RuntimeFailure { throw ControlFailure(.runtime(error),phase:"observe") }
        catch let error as ActuationError { throw ControlFailure(.actuation(error),phase:"observe") }
        catch { throw ControlFailure(.invalidSupplierOutput,phase:"observe") }
    }
    private func capturedObservation() throws(ControlFailure) -> ControlObservation {
        let capture=ControlObservationCapture()
        do { try session.observe { accepted throws(RuntimeFailure) in
            do throws(ControlFailure) { capture.store(try self.decode(accepted)) }
            catch { throw ControlArithmetic.runtime(error) }
        } } catch { throw ControlFailure(.runtime(error),phase:"observe") }
        guard let observation=capture.read() else { throw ControlFailure(.invalidSupplierOutput,phase:"observe") };return observation
    }
    @inline(never)
    func step(input:ControlSampleInput) throws(ControlFailure) -> ControlStepResult {
        try begin();defer { end() }
        try ControlArithmetic.check(policy)
        let previous=try capturedObservation()
        guard previous.controller.tick == input.tick,previous.accepted.checkpoint.physical.time == input.sampleTickTime else { throw ControlFailure(.staleSample,phase:"session-sample") }
        let requested=try clock.end(after:input.tick)
        let equation=HeldPrismaticControlEquation(descriptor:descriptor,plant:plant,controller:controller,clock:clock,policy:policy,codec:provider.codec,
            actuatorCodec:provider.actuator.codec,input:input,drives:drives,equations:equations,dynamics:dynamics)
        let result:IntegrationAdvanceResult
        do { result=try integrator.advance(session,model:plant.model,equations:equation,continuation:provider.integration,to:requested) }
        catch {
            if let failure=equation.retainedFailure { throw failure }
            throw ControlFailure(.integration(error),phase:"integration",failedSupplierWorkUnavailable:error.work.failedSupplierWorkUnavailable)
        }
        guard result.reachedRequestedTime,result.acceptedSteps == 1,result.rejectedTrials == 0 else { throw ControlFailure(.originalEvidenceRejected,phase:"integration-endpoint") }
        let observed=try capturedObservation()
        guard observed.accepted == result.accepted,observed.controller.tick == input.tick+1,
              observed.controller.issued,!observed.controller.pending,observed.controller.sampleTickTime == input.sampleTickTime else { throw ControlFailure(.originalEvidenceRejected,phase:"publication") }
        return ControlStepResult(observation:observed,integration:result,actuationWork:equation.actuationWork)
    }
    func observe(_ body:@Sendable (ControlObservation) throws(ControlFailure) -> Void) throws(ControlFailure) {
        try begin();defer { end() }
        do { try session.observe { accepted throws(RuntimeFailure) in
            do throws(ControlFailure) { try body(self.decode(accepted)) } catch { throw ControlArithmetic.runtime(error) }
        } } catch { throw ControlFailure(.runtime(error),phase:"observe") }
    }
    func checkpoint(codec:any RuntimeCheckpointCoding) throws(ControlFailure) -> [UInt8] {
        try begin();defer { end() }
        do { return try session.checkpoint(codec:codec) } catch { throw ControlFailure(.runtime(error),phase:"checkpoint") }
    }
    func restart(_ bytes:[UInt8],codec:any RuntimeCheckpointCoding) throws(ControlFailure) {
        try begin();defer { end() }
        do { _=try session.restart(bytes,codec:codec) } catch { throw ControlFailure(.runtime(error),phase:"restart") }
        _=try capturedObservation()
    }
    func cancel() { session.cancel() }
    func shutdown() -> RuntimeShutdownStatus { session.shutdown() }
    func shutdownStatus() -> RuntimeShutdownStatus? { session.shutdownStatus() }
}
