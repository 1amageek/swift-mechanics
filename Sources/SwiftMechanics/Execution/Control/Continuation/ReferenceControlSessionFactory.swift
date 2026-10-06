@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
public struct ReferenceControlSessionFactory: ControlSessionCreating, Sendable {
    public let drives:any DriveEvaluating
    public let equations:any RigidEquationComputing
    public let dynamics:any RigidDynamicsSolving
    public let integrator:any ExplicitIntegrating
    public init(drives:any DriveEvaluating = ReferenceDriveEvaluator(),equations:any RigidEquationComputing = RigidEquationKernel(),
                dynamics:any RigidDynamicsSolving = DenseRigidDynamics(),integrator:any ExplicitIntegrating = ReferenceExplicitIntegrator()) {
        self.drives=drives;self.equations=equations;self.dynamics=dynamics;self.integrator=integrator
    }
    @inline(never)
    public func make(plant:PrismaticControlPlant,controller:SampledController,clock:ControlClock,initialActuator:ActuatorState,
                     seed:UInt64,policy:ControlPolicy,work:inout NumericalWork) throws(ControlFailure) -> any ControlSessionOperating {
        try ControlArithmetic.charge(128,work:&work,policy:policy)
        let physical=plant.model.descriptor.initialState
        guard controller.servo.binding == plant.port.binding,initialActuator.binding == plant.port.binding,initialActuator.mode == controller.mode,
              initialActuator.time == physical.time,physical.time == clock.epochSeconds,physical.q.count == 1,physical.v.count == 1,
              policy.integration.scales.count == 2,policy.integration.scales[0].dimension == .length,
              policy.integration.scales[1].dimension == plant.port.rateDimension else { throw ControlFailure(.invalidInput,phase:"cold-start") }
        let end=try clock.end(after:0),dt=end-clock.epochSeconds
        guard policy.integration.initialStep >= dt,policy.integration.minimumStep <= dt else { throw ControlFailure(.invalidInput,phase:"cold-start") }
        let codec=try ControlContinuationCodec(plant:plant,controller:controller,clock:clock,policy:policy,work:&work)
        let descriptor:ODEDescriptor,integration:IntegrationContinuationProvider
        do { descriptor=try ODEDescriptor(identity:"mechanics.control.prismatic.v1",chart:"fixed-prismatic-q-v",model:plant.model.stamp,
                dimensions:[.length,plant.port.rateDimension],maximumIdentityBytes:policy.maximumMetadataBytes,maximumCoordinates:2)
            integration=try IntegrationContinuationProvider(descriptor:descriptor,policy:policy.integration)
        } catch { throw ControlFailure(.runtime(error),phase:"cold-start") }
        var aw=ActuationWork(budget:policy.actuation)
        let actuator:ActuatorRuntimeContributors
        do { actuator=try ActuatorRuntimeContributors(bindings:[plant.port.binding],codec:FixedActuatorContinuationCodec(),controlBudget:policy.actuation,work:&aw) }
        catch { throw ControlFailure(.actuation(error),phase:"cold-start") }
        let provider=ControlContributorProvider(actuator:actuator,integration:integration,codec:codec)
        let history=ControlHistory(tick:0,issued:false,pending:false,sourceTime:physical.time,sampleTickTime:physical.time,intervalEnd:physical.time,
            sampledPosition:physical.q[0],sampledRate:physical.v[0],requestedEffort:0,heldEffort:0,nominalSampledWork:0,actuatorIntervalWork:0,
            disturbanceIntervalWork:0,initialKineticEnergy:0,endpointKineticEnergy:0,forceResidual:0,endpointPosition:physical.q[0],endpointRate:physical.v[0],clipped:false)
        let handler=ControlCheckpointHandler(provider:provider,plant:plant,controller:controller,initialSequence:initialActuator.sequence,policy:policy)
        let equation=HeldPrismaticControlEquation(descriptor:descriptor,plant:plant,controller:controller,clock:clock,policy:policy,codec:codec,
            actuatorCodec:actuator.codec,input:nil,drives:drives,equations:equations,dynamics:dynamics)
        do {
            let configuration=try RuntimeConfiguration(continuation:policy.continuation,requiredContributors:provider.schemas,capacity:policy.runtimeCapacity,
                determinism:.sameBuildReplay,workload:"sampled-prismatic-control")
            let record=try actuator.codec.encode(initialActuator,work:&aw)
            let records=try [record,integration.initialRecord(physical:physical,equations:equation),codec.record(history)]
            let session=try RuntimeSession(model:plant.model,configuration:configuration,initialState:physical,contributors:records,seed:seed,checkpoints:handler)
            return BoundControlSession(session:session,plant:plant,controller:controller,clock:clock,policy:policy,provider:provider,
                descriptor:descriptor,drives:drives,equations:equations,dynamics:dynamics,integrator:integrator)
        } catch let failure as RuntimeFailure { throw ControlFailure(.runtime(failure),phase:"cold-start") }
        catch let failure as ActuationError { throw ControlFailure(.actuation(failure),phase:"cold-start") }
        catch { throw ControlFailure(.invalidSupplierOutput,phase:"cold-start") }
    }
}
