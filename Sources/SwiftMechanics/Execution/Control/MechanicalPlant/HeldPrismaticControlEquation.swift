import Synchronization

@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal final class HeldPrismaticControlEquation: SmoothODEEquations, Sendable {
    let descriptor:ODEDescriptor
    let plant:PrismaticControlPlant
    let controller:SampledController
    let clock:ControlClock
    let policy:ControlPolicy
    let codec:ControlContinuationCodec
    let actuatorCodec:any ActuatorContinuationCoding
    let input:ControlSampleInput?
    let drives:any DriveEvaluating
    let equations:any RigidEquationComputing
    let dynamics:any RigidDynamicsSolving
    private let state:Mutex<ControlEquationState>
    init(descriptor:ODEDescriptor,plant:PrismaticControlPlant,controller:SampledController,clock:ControlClock,policy:ControlPolicy,
         codec:ControlContinuationCodec,actuatorCodec:any ActuatorContinuationCoding,input:ControlSampleInput?,drives:any DriveEvaluating,
         equations:any RigidEquationComputing,dynamics:any RigidDynamicsSolving) {
        self.descriptor=descriptor;self.plant=plant;self.controller=controller;self.clock=clock;self.policy=policy;self.codec=codec
        self.actuatorCodec=actuatorCodec;self.input=input;self.drives=drives;self.equations=equations;self.dynamics=dynamics
        state=Mutex(ControlEquationState(budget:policy.actuation))
    }
    var retainedFailure:ControlFailure? { state.withLock { $0.failure } }
    var actuationWork:ActuationWork { state.withLock { $0.work } }
    func validate(model:CompiledMechanicalModel) throws(RuntimeFailure) {
        guard model.stamp == plant.model.stamp,model.descriptor == plant.model.descriptor else { throw RuntimeFailure(.incompatibleModel,message:"Control model differs.") }
    }
    func read(_ physical:KinematicState,into point:inout [Double]) throws(RuntimeFailure) {
        guard physical.revision == descriptor.model.revision,physical.q.count == 1,physical.v.count == 1,point.count == 2 else { throw RuntimeFailure(.invalidState,message:"Control chart shape differs.") }
        point[0]=physical.q[0];point[1]=physical.v[0]
    }
    func read(_ trial:RuntimeTrial,into point:inout [Double]) throws(RuntimeFailure) {
        guard point.count == 2 else { throw RuntimeFailure(.invalidState,message:"Control chart shape differs.") }
        point[0]=try trial.position(at:0);point[1]=try trial.velocity(at:0)
    }
    private func checkout() throws(RuntimeFailure) -> ControlEquationState {
        try state.withLock { value throws(RuntimeFailure) in
            guard !value.busy else { throw RuntimeFailure(.busy,message:"Control equation reentry.") }
            value.busy=true;return value
        }
    }
    private func finish(_ value:ControlEquationState) { state.withLock { $0=value;$0.busy=false } }
    @inline(never)
    func prepare(trial:inout RuntimeTrial,work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) {
        var local=try checkout();defer { finish(local) }
        do throws(ControlFailure) { try prepareCandidate(trial:&trial,work:&work,control:control,state:&local) }
        catch { let failure=error.retaining(numerical:work,actuation:local.work);local.failure=failure;throw ControlArithmetic.runtime(failure) }
    }
    @inline(never)
    private func prepareCandidate(trial:inout RuntimeTrial,work:inout NumericalWork,control:RuntimeStepControl,state:inout ControlEquationState) throws(ControlFailure) {
        try ControlArithmetic.charge(128+codec.schema.maximumBytes,work:&work,policy:policy)
        do { try control.beginWorkBlock(units:1);try state.work.reserve(scalars:32,bytes:policy.maximumPayloadBytes) } catch let e as ActuationError { throw ControlFailure(.actuation(e),phase:"prepare") } catch let e as RuntimeFailure { throw ControlFailure(.runtime(e),phase:"prepare") } catch { throw ControlFailure(.invalidSupplierOutput,phase:"prepare") }
        let sample=try preparationSample(trial:&trial,state:&state,work:&work)
        let system=try preparationSystem(sample,work:&work)
        let driven=try evaluateDrive(sample,system:system,state:&state,work:&work)
        let prepared=try prepareEvidence(driven,work:&work)
        try stagePrepared(prepared,trial:&trial,state:&state)
    }
    @inline(never)
    private func preparationSample(trial:inout RuntimeTrial,state:inout ControlEquationState,work:inout NumericalWork) throws(ControlFailure) -> ControlPreparationSample {
        guard let input,state.history == nil else { throw ControlFailure(.invalidInput,phase:"prepare") }
        let saved:ControlHistory,old:ActuatorState,q:Double,v:Double
        do {
            saved=try codec.history(trial.contributor(codec.schema.id))
            old=try actuatorCodec.decode(trial.contributor(controller.servo.binding.actuator.key),binding:controller.servo.binding,work:&state.work)
            q=try trial.position(at:0);v=try trial.velocity(at:0)
        } catch let e as ActuationError { throw ControlFailure(.actuation(e),phase:"decode") } catch let e as RuntimeFailure { throw ControlFailure(.runtime(e),phase:"decode") } catch { throw ControlFailure(.invalidSupplierOutput,phase:"decode") }
        let start=try clock.time(at:saved.tick),end=try clock.end(after:saved.tick),dt=end-start
        guard !saved.pending,input.tick == saved.tick,input.sampleTickTime == start,trial.timeSeconds == start,old.time == start,
              old.mode == controller.mode,policy.integration.initialStep >= dt,policy.integration.minimumStep <= dt else { throw ControlFailure(.staleSample,phase:"sample") }
        let feedback=try ReferenceControlPortAdapter().prepare(encoder:input.encoder,port:plant.port,policy:policy,work:&work)
        guard feedback.sourceTime == start,feedback.position == q,feedback.rate == v else { throw ControlFailure(.staleSample,phase:"sample") }
        return ControlPreparationSample(input:input,old:old,feedback:feedback,tick:saved.tick,q:q,v:v,start:start,end:end,dt:dt)
    }
    @inline(never)
    private func preparationSystem(_ sample:ControlPreparationSample,work:inout NumericalWork) throws(ControlFailure) -> ControlRigidSystemSample {
        ControlRigidSystemSample(try ControlRigidSampling.system(plant:plant,time:sample.start,point:[sample.q,sample.v],policy:policy,equations:equations,work:&work))
    }
    @inline(never)
    private func evaluateDrive(_ sample:ControlPreparationSample,system sampleSystem:ControlRigidSystemSample,state:inout ControlEquationState,work:inout NumericalWork) throws(ControlFailure) -> ControlDrivenSample {
        let system=sampleSystem.system
        let command=try desiredCommand(sample.input,feedback:sample.feedback,system:system,work:&work)
        let response=try drive(command,old:sample.old,q:sample.q,v:sample.v,dt:sample.dt,state:&state,work:&work)
        guard response.state.binding == sample.old.binding,response.state.time == sample.end,response.state.mode == sample.old.mode,sample.old.sequence < UInt64.max,
              response.state.sequence == sample.old.sequence+1,abs(response.appliedEffort) <= controller.servo.effortLimit,
              ControlArithmetic.agrees(response.power,response.appliedEffort*sample.v,policy.agreement),
              ControlArithmetic.agrees(response.energy.mechanicalWork,response.appliedEffort*sample.v*sample.dt,policy.agreement) else { throw ControlFailure(.invalidSupplierOutput,phase:"drive") }
        return ControlDrivenSample(sample:sample,system:system,response:response)
    }
    @inline(never)
    private func prepareEvidence(_ driven:ControlDrivenSample,work:inout NumericalWork) throws(ControlFailure) -> ControlPreparedSample {
        let total=driven.response.appliedEffort+plant.disturbanceNewtons
        let solution=try ControlRigidSampling.solve(driven.system,drive:total,inverseAcceleration:nil,plant:plant,dynamics:dynamics,policy:policy,work:&work)
        let initial=try ControlRigidSampling.evidence(driven.system,acceleration:solution.acceleration[0],force:total,plant:plant,equations:equations,policy:policy,work:&work)
        let history=ControlHistory(tick:driven.sample.tick+1,issued:true,pending:true,sourceTime:driven.sample.start,sampleTickTime:driven.sample.start,intervalEnd:driven.sample.end,
            sampledPosition:driven.sample.q,sampledRate:driven.sample.v,requestedEffort:driven.response.requestedEffort,heldEffort:driven.response.appliedEffort,nominalSampledWork:driven.response.energy.mechanicalWork,
            actuatorIntervalWork:0,disturbanceIntervalWork:0,initialKineticEnergy:initial.kineticEnergy,endpointKineticEnergy:0,forceResidual:initial.forceResidual,
            endpointPosition:driven.sample.q,endpointRate:driven.sample.v,clipped:driven.response.clipped)
        return ControlPreparedSample(response:driven.response,history:history)
    }
    @inline(never)
    private func stagePrepared(_ prepared:ControlPreparedSample,trial:inout RuntimeTrial,state:inout ControlEquationState) throws(ControlFailure) {
        do { try trial.replaceContributor(actuatorCodec.encode(prepared.response.state,work:&state.work));try trial.replaceContributor(codec.record(prepared.history)) }
        catch let e as ActuationError { throw ControlFailure(.actuation(e),phase:"stage") } catch let e as RuntimeFailure { throw ControlFailure(.runtime(e),phase:"stage") } catch { throw ControlFailure(.invalidSupplierOutput,phase:"stage") }
        state.response=prepared.response;state.history=prepared.history
    }
    @inline(never)
    private func desiredCommand(_ input:ControlSampleInput,feedback:ScalarControlFeedback,system:RigidDynamicsSystem,work:inout NumericalWork) throws(ControlFailure) -> DriveCommand {
        switch (controller.law,input.demand) {
        case (.servo,.servo(let command)):
            let dimension:PhysicalDimension
            switch command.mode { case .effort:dimension=plant.port.effortDimension;case .velocity:dimension=plant.port.rateDimension;case .position:dimension = .length }
            guard command.mode == controller.mode,input.commandDimension == dimension else { throw ControlFailure(.incompatiblePort,phase:"command") };return command
        case (.computedTorque,.computedTorque(let reference)):
            guard input.commandDimension == PhysicalDimension(length:1,time:-2) else { throw ControlFailure(.incompatiblePort,phase:"command") }
            try ControlArithmetic.charge(8,work:&work,policy:policy)
            let a=reference.accelerationMetersPerSecondSquared+controller.positionAccelerationGain*(reference.positionMeters-feedback.position)+controller.rateAccelerationGain*(reference.rateMetersPerSecond-feedback.rate)
            guard a.isFinite else { throw ControlFailure(.invalidInput,phase:"computed-torque") }
            let inverse=try ControlRigidSampling.solve(system,drive:0,inverseAcceleration:a,plant:plant,dynamics:dynamics,policy:policy,work:&work)
            do { return try DriveCommand(mode:.effort,value:inverse.driveForce[0]-plant.disturbanceNewtons) } catch { throw ControlFailure(.actuation(error),phase:"computed-torque") }
        default:throw ControlFailure(.incompatiblePort,phase:"command")
        }
    }
    @inline(never)
    private func drive(_ command:DriveCommand,old:ActuatorState,q:Double,v:Double,dt:Double,state:inout ControlEquationState,work:inout NumericalWork) throws(ControlFailure) -> ActuatorResponse {
        let sample:ActuatorSample
        do { sample=try ActuatorSample(binding:old.binding,time:old.time,position:q,velocity:v);try state.work.charge(1) } catch { throw ControlFailure(.actuation(error),phase:"drive") }
        var numerical=try ControlRigidSampling.nested(work,reserved:512),actuation=state.work
        let nbefore=numerical,abefore=actuation
        var value:ActuatorResponse?,failure:ActuationError?
        do { value=try drives.step(law:controller.servo,state:old,sample:sample,command:command,dt:dt,energyTolerance:policy.agreement,work:&actuation,numerical:&numerical) } catch { failure=error }
        let valid=actuation.budget.maximumWork == abefore.budget.maximumWork && actuation.budget.maximumScalars == abefore.budget.maximumScalars &&
            actuation.budget.maximumBytes == abefore.budget.maximumBytes && actuation.budget.maximumBindings == abefore.budget.maximumBindings && actuation.budget.maximumMetadataBytes == abefore.budget.maximumMetadataBytes &&
            actuation.used >= abefore.used && actuation.peakScalars >= abefore.peakScalars && actuation.peakBytes >= abefore.peakBytes
        state.work=abefore
        var restoreFailure:ActuationError?
        if valid { do { try state.work.charge(actuation.used-abefore.used);try state.work.reserve(scalars:actuation.peakScalars,bytes:actuation.peakBytes) } catch { restoreFailure=error } }
        try ControlRigidSampling.reconcile(numerical,before:nbefore,work:&work,reserved:512,auxiliaryValid:valid)
        if let restoreFailure { throw ControlFailure(.actuation(restoreFailure),phase:"drive",failedSupplierWorkUnavailable:state.work.used < actuation.used || state.work.peakScalars < actuation.peakScalars || state.work.peakBytes < actuation.peakBytes) }
        if let failure { throw ControlFailure(.actuation(failure),phase:"drive") }
        guard let value else { throw ControlFailure(.invalidSupplierOutput,phase:"drive") };return value
    }
    @inline(never)
    func derivative(time:Double,point:[Double],into output:inout [Double],work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) {
        var local=try checkout();defer { finish(local) }
        do throws(ControlFailure) {
            do { try control.beginWorkBlock(units:1) } catch { throw ControlFailure(.runtime(error),phase:"stage") }
            guard let history=local.history,history.pending,time >= history.sampleTickTime,time <= history.intervalEnd,output.count == 2 else { throw ControlFailure(.invalidInput,phase:"stage") }
            let sample=try stage(time:time,point:point,history:history,work:&work)
            output[0]=point[1];output[1]=sample.acceleration
            if time == history.intervalEnd {
                let displacement=point[0]-history.sampledPosition,aw=history.heldEffort*displacement,dw=plant.disturbanceNewtons*displacement
                guard abs(point[1]) <= controller.servo.speedLimit,
                      ControlArithmetic.agrees(sample.kineticEnergy-history.initialKineticEnergy,aw+dw,policy.agreement) else { throw ControlFailure(.originalEvidenceRejected,phase:"endpoint-energy") }
                local.endpoint=point;local.endpointDerivative=output
                local.history=ControlHistory(tick:history.tick,issued:true,pending:true,sourceTime:history.sourceTime,sampleTickTime:history.sampleTickTime,intervalEnd:history.intervalEnd,
                    sampledPosition:history.sampledPosition,sampledRate:history.sampledRate,requestedEffort:history.requestedEffort,heldEffort:history.heldEffort,
                    nominalSampledWork:history.nominalSampledWork,actuatorIntervalWork:aw,disturbanceIntervalWork:dw,initialKineticEnergy:history.initialKineticEnergy,
                    endpointKineticEnergy:sample.kineticEnergy,forceResidual:sample.forceResidual,endpointPosition:point[0],endpointRate:point[1],clipped:history.clipped)
            }
            try ControlArithmetic.check(policy)
        } catch { let failure=error.retaining(numerical:work,actuation:local.work);local.failure=failure;throw ControlArithmetic.runtime(failure) }
    }
    @inline(never)
    private func stage(time:Double,point:[Double],history:ControlHistory,work:inout NumericalWork) throws(ControlFailure) -> ControlMechanicalSample {
        let system=try ControlRigidSampling.system(plant:plant,time:time,point:point,policy:policy,equations:equations,work:&work)
        let total=history.heldEffort+plant.disturbanceNewtons
        let solution=try ControlRigidSampling.solve(system,drive:total,inverseAcceleration:nil,plant:plant,dynamics:dynamics,policy:policy,work:&work)
        return try ControlRigidSampling.evidence(system,acceleration:solution.acceleration[0],force:total,plant:plant,equations:equations,policy:policy,work:&work)
    }
    @inline(never)
    func write(point:[Double],derivative:[Double],time:Double,trial:inout RuntimeTrial) throws(RuntimeFailure) {
        var local=try checkout();defer { finish(local) }
        do throws(ControlFailure) {
            try ControlArithmetic.check(policy)
            guard let h=local.history,let response=local.response,local.endpoint == point,local.endpointDerivative == derivative,time == h.intervalEnd else { throw ControlFailure(.originalEvidenceRejected,phase:"write") }
            do { try local.work.charge(codec.schema.maximumBytes) } catch { throw ControlFailure(.actuation(error),phase:"write") }
            let ready=ControlHistory(tick:h.tick,issued:true,pending:false,sourceTime:h.sourceTime,sampleTickTime:h.sampleTickTime,intervalEnd:h.intervalEnd,
                sampledPosition:h.sampledPosition,sampledRate:h.sampledRate,requestedEffort:h.requestedEffort,heldEffort:h.heldEffort,nominalSampledWork:h.nominalSampledWork,
                actuatorIntervalWork:h.actuatorIntervalWork,disturbanceIntervalWork:h.disturbanceIntervalWork,initialKineticEnergy:h.initialKineticEnergy,
                endpointKineticEnergy:h.endpointKineticEnergy,forceResidual:h.forceResidual,endpointPosition:h.endpointPosition,endpointRate:h.endpointRate,clipped:h.clipped)
            do {
                try trial.setPosition(point[0],at:0);try trial.setVelocity(point[1],at:0);try trial.setAcceleration(derivative[1],at:0);try trial.setTime(time)
                try trial.replaceContributor(codec.record(ready));try trial.replaceContributor(actuatorCodec.encode(response.state,work:&local.work))
            } catch let e as ActuationError { throw ControlFailure(.actuation(e),phase:"write") } catch let e as RuntimeFailure { throw ControlFailure(.runtime(e),phase:"write") } catch { throw ControlFailure(.invalidSupplierOutput,phase:"write") }
            local.history=ready
        } catch { local.failure=error;throw ControlArithmetic.runtime(error) }
    }
}
