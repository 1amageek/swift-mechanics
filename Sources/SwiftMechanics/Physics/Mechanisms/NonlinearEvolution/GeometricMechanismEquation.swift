/// Actual body-frame holonomic evolution on the compiled tree's independent q/v manifolds.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public final class GeometricMechanismEquation: ProjectedMechanismEquations, Sendable {
    public let descriptor:ODEDescriptor
    public let model:CompiledMechanicalModel
    public let geometry:GeometricConstraintSystem
    public let projection:ManifoldProjectionPolicy
    public let policy:MechanismSolvePolicy
    public let drive:[Double]
    public let maximumStageChartCorrection:Double
    public let publicationBudget:NumericalBudget
    private let physical:NonlinearPhysicalEngine
    private let motionSampler:any PrescribedMotionSampling
    private let evaluator:any HolonomicGeometryProviding
    private let assembler:TangentManifoldAssembler
    private let quaternionStarts:[Int]
    public init(identity:String,geometry:GeometricConstraintSystem,drive:[Double],policy:MechanismSolvePolicy,
                projection:ManifoldProjectionPolicy,maximumStageChartCorrection:Double,publicationBudget:NumericalBudget,
                admission:DynamicsAdmission,maximumIdentityBytes:Int,
                kernel:any RigidEquationComputing = RigidEquationKernel(),evaluator:any HolonomicGeometryProviding = GeometricRelationEvaluator(),
                solver:any ConstrainedMechanismSolving = MassWeightedMechanismSolver(),ranker:any ConstraintRankAnalyzing = WeightedConstraintAssembler(),
                linear:any LinearSolving<Double> = ReferenceLinearSolver<Double>(),motionSampler:any PrescribedMotionSampling = AnalyticPrescribedMotionSampler()) throws(RuntimeFailure) {
        let model=geometry.model,p=model.tree.layout.positionCount,n=model.tree.layout.velocityCount,m=geometry.rowIDs.count
        guard maximumStageChartCorrection.isFinite,maximumStageChartCorrection > 0,identity.utf8.count <= maximumIdentityBytes,
              n <= policy.maximumCoordinates,m <= policy.maximumRows,n <= admission.capacity.maximumVelocities,
              model.tree.bodies.count <= admission.capacity.maximumBodies,drive.count == n,drive.allSatisfy({$0.isFinite}),
              policy.dynamics.coordinateScales == geometry.layout.scales,policy.dynamics.timeScale == geometry.layout.timeScale,
              projection.constraints.diagonalMetric.count == n,policy.constraints.diagonalMetric.count == n,
              p <= projection.constraints.evaluation.maximumCoordinates,m <= projection.constraints.evaluation.maximumRows,
              projection.constraints.evaluation.expectedLayoutRevision == model.stamp.revision else { throw RuntimeFailure(.invalidInput,message:"Geometric physical chart/policy differs.") }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Fully prescribed floating-root partitions and prescribed free joints need separate force-coordinate partition evidence. Fixed zero-DOF bridges are admitted through the geometry-bound anchor programme.
        guard model.descriptor.joints.allSatisfy({$0.record.manifold.velocityCount == 0 ? $0.authority == .fixed : $0.authority == .dynamicState}),
              model.descriptor.rootAuthority == (model.tree.rootBase == .fixed ? .fixed : .dynamicState) else { throw RuntimeFailure(.unsupportedDomain,message:"Geometric dynamic authority unavailable.") }
        var dimensions:[PhysicalDimension]=[],starts:[Int]=[]
        switch model.tree.rootBase {
        case .fixed: break
        case .planarFloating: dimensions += [.length,.length,.angle]
        case .spatialFloating: dimensions += [.length,.length,.length,.dimensionless,.dimensionless,.dimensionless,.dimensionless];starts.append(3)
        }
        for entry in model.tree.layout.joints {
            guard entry.positions.start == dimensions.count,let joint=model.tree.joints.first(where:{$0.id == entry.joint}) else { throw RuntimeFailure(.incompatibleModel,message:"Geometric joint chart source differs.") }
            switch joint.manifold.kind {
            case .spherical: starts.append(entry.positions.start);dimensions += [.dimensionless,.dimensionless,.dimensionless,.dimensionless]
            case .sixDOF: starts.append(entry.positions.start+3);dimensions += [.length,.length,.length,.dimensionless,.dimensionless,.dimensionless,.dimensionless]
            default: for axis in joint.manifold.orderedAxes { dimensions.append(axis.kind == .prismatic ? .length : .angle) }
            }
        }
        guard dimensions.count == p else { throw RuntimeFailure(.incompatibleModel,message:"Geometric position chart differs.") }
        for d in geometry.layout.dimensions {
            guard d.time > Int8.min else { throw RuntimeFailure(.invalidInput,message:"Geometric velocity dimension overflow.") }
            dimensions.append(PhysicalDimension(length:d.length,mass:d.mass,time:d.time-1,angle:d.angle,electricCurrent:d.electricCurrent,
                temperature:d.temperature,amount:d.amount,luminousIntensity:d.luminousIntensity))
        }
        let inertias:[RigidBodyInertia]
        do throws(MechanismError) { inertias=try NonlinearPhysicalEngine.bind(model) }
        catch { throw RuntimeFailure(.invalidState,message:"Geometric spatial inertia unavailable.") }
        let storage:Int
        do { storage=try NumericalWork.sum(geometry.scalarStorage,try NumericalWork.sum(try NumericalWork.product(32,try NumericalWork.product(m,max(m,n))),try NumericalWork.product(64,p+n))) }
        catch { throw RuntimeFailure(.capacityExceeded,message:"Geometric workspace envelope overflow.") }
        guard publicationBudget.scalarStorage >= storage else { throw RuntimeFailure(.capacityExceeded,message:"Geometric publication workspace capacity exhausted.") }
        let chart=try GeometricMechanismChart.signature(geometry,projection:projection,policy:policy,drive:drive,dimensions:dimensions,inertias:inertias,
            chartLimit:maximumStageChartCorrection,publication:publicationBudget,maximum:maximumIdentityBytes)
        do { descriptor=try ODEDescriptor(identity:identity,chart:chart,model:model.stamp,dimensions:dimensions,maximumIdentityBytes:maximumIdentityBytes,maximumCoordinates:p+n) }
        catch { throw RuntimeFailure(.invalidInput,message:"Geometric ODE descriptor invalid.") }
        self.model=model;self.geometry=geometry;self.drive=drive;self.policy=policy;self.projection=projection
        self.maximumStageChartCorrection=maximumStageChartCorrection;self.publicationBudget=publicationBudget;quaternionStarts=starts
        self.motionSampler=motionSampler;self.evaluator=evaluator;assembler=TangentManifoldAssembler(evaluator:evaluator,ranker:ranker,linear:linear)
        physical=NonlinearPhysicalEngine(model:model,velocityLayout:geometry.layout,drive:drive,policy:policy,admission:admission,
            inertias:inertias,kernel:kernel,solver:solver,storage:storage)
    }
    public func validate(model:CompiledMechanicalModel) throws(RuntimeFailure) {
        guard model.stamp == self.model.stamp,model.descriptor == self.model.descriptor,model.tree.layout == self.model.tree.layout else { throw RuntimeFailure(.incompatibleModel,message:"Geometric model source differs.") }
    }
    public func read(_ state:KinematicState,into point:inout [Double]) throws(RuntimeFailure) {
        let p=model.tree.layout.positionCount,n=model.tree.layout.velocityCount
        guard state.revision == model.stamp.revision,state.q.count == p,state.v.count == n,point.count == p+n else { throw RuntimeFailure(.invalidState,message:"Geometric physical chart differs.") }
        var validation=NumericalWork(budget:publicationBudget)
        try validatePrescribed(state,work:&validation)
        for i in 0..<p { point[i]=state.q[i] };for i in 0..<n { point[p+i]=state.v[i] }
    }
    public func read(_ trial:RuntimeTrial,into point:inout [Double]) throws(RuntimeFailure) {
        let p=model.tree.layout.positionCount,n=model.tree.layout.velocityCount
        guard point.count == p+n else { throw RuntimeFailure(.invalidState,message:"Geometric trial chart differs.") }
        var validation=NumericalWork(budget:publicationBudget)
        if let program=geometry.prescribedMotion {
            do throws(NumericalError) { try validation.requireStorage(physical.storage);try validation.chargeOperations(try NumericalWork.product(64,program.motions.count)) }
            catch { throw RuntimeFailure(.capacityExceeded,message:"Geometric trial association budget exhausted.") }
            var anchors:[PrescribedAnchorState]=[];anchors.reserveCapacity(program.motions.count)
            for motion in program.motions { anchors.append(try trial.prescribedAnchor(motion.frame)) }
            do throws(PrescribedMotionError) {
                let supplied=try PrescribedMotionSample(metadata:program.metadata,time:trial.timeSeconds,anchors:anchors,policy:program.policy)
                _=try OriginalPrescribedMotionAcceptance.validated(supplied,program:program,time:trial.timeSeconds,policy:program.policy,work:&validation)
            } catch { throw Self.failure(.motion(error)) }
        }
        for i in 0..<p { point[i]=try trial.position(at:i) };for i in 0..<n { point[p+i]=try trial.velocity(at:i) }
    }
    public func prepare(trial:inout RuntimeTrial,work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) {
        try reserve(&work,control:control)
        var point=[Double](repeating:0,count:descriptor.dimensions.count);try read(trial,into:&point)
        try validateInitial(time:trial.timeSeconds,point:point,work:&work,control:control)
    }
    public func validateInitial(time:Double,point:[Double],work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) {
        try reserve(&work,control:control)
        let state=try state(time:time,point:point,work:&work,control:control)
        let original=try evaluate(state,work:&work,control:control)
        _=try residual(original,velocity:true,work:&work)
    }
    public func derivative(time:Double,point:[Double],into output:inout [Double],work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) {
        guard output.count == descriptor.dimensions.count else { throw RuntimeFailure(.invalidState,message:"Geometric derivative chart differs.") }
        let result=try consistent(time:time,point:point,work:&work,control:control),p=model.tree.layout.positionCount
        for i in 0..<p { output[i]=result.acceleration.sourceSnapshot.coordinateRate[i] }
        for i in result.acceleration.values.indices { output[p+i]=result.acceleration.values[i] }
    }
    @inline(never)
    public func consistent(time:Double,point:[Double],work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) -> NonlinearMechanismState {
        try reserve(&work,control:control)
        let position=try positionContext(time:time,point:point,work:&work,control:control)
        let acceleration=try reconciledContext(position,work:&work,control:control)
        return try finish(acceleration,work:&work,control:control)
    }
    @inline(never)
    private func positionContext(time:Double,point:[Double],work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) -> GeometricPositionContext {
        let stage=try correctedStage(time:time,point:point,work:&work,control:control)
        let assembled=try assemble(stage.state,work:&work,control:control)
        return GeometricPositionContext(initial:stage.state,assembly:assembled,chartCorrection:stage.correction)
    }
    @inline(never)
    private func velocityContext(_ position:GeometricPositionContext,work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) -> GeometricVelocityContext {
        let beforeEnergy=try originalEnergy(position.initial,work:&work,control:control),assembled=position.assembly
        let original=try original(assembled.geometry,state:assembled.state,work:&work)
        let r=try residual(original,velocity:false,work:&work)
        let system=try physical.system(snapshot:original.snapshot,v:assembled.state.v,work:&work,control:control)
        let projectedEnergy=try physical.energy(system,acceleration:assembled.state.acceleration,work:&work,control:control).kineticEnergy
        return GeometricVelocityContext(position:position,physical:NonlinearPhysicalSolveContext(system:system,sample:original.velocity,
            impulse:true,positionResidual:r.position,velocityResidual:r.velocity),positionEnergyChange:projectedEnergy-beforeEnergy)
    }
    @inline(never)
    private func reconciledContext(_ position:GeometricPositionContext,work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) -> GeometricAccelerationContext {
        let context=try velocityContext(position,work:&work,control:control)
        let velocity=try physical.solve(context.physical,work:&work,control:control)
        return try accelerationContext(context,velocity:velocity,work:&work,control:control)
    }
    @inline(never)
    private func accelerationContext(_ context:GeometricVelocityContext,velocity:ConstrainedMotion,
                                     work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) -> GeometricAccelerationContext {
        let position=context.position.assembly.state,state:KinematicState
        do throws(JointError) { state=try KinematicState(revision:position.revision,time:position.time,q:position.q,v:velocity.values,acceleration:position.acceleration,prescribedAnchors:position.prescribedAnchors) }
        catch { throw RuntimeFailure(.invalidState,message:"Geometric reconciled state invalid.") }
        let original=try evaluate(state,work:&work,control:control),r=try residual(original,velocity:true,work:&work)
        let system=try physical.system(snapshot:original.snapshot,v:state.v,work:&work,control:control)
        let kinetic=try physical.energy(system,acceleration:state.acceleration,work:&work,control:control).kineticEnergy
        let before=try originalEnergy(position,work:&work,control:control)
        return GeometricAccelerationContext(position:context.position,velocity:velocity,physical:NonlinearPhysicalSolveContext(system:system,
            sample:original.velocity,impulse:false,positionResidual:r.position,velocityResidual:r.velocity),
            positionEnergyChange:context.positionEnergyChange,velocityEnergyChange:kinetic-before)
    }
    @inline(never)
    private func finish(_ context:GeometricAccelerationContext,work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) -> NonlinearMechanismState {
        let acceleration=try physical.solve(context.physical,work:&work,control:control)
        try reserve(&work,control:control)
        try GeometricAxisAcceptance.validate(geometry,snapshot:acceleration.sourceSnapshot,acceleration:acceleration.values,tolerance:policy.originalTolerance,work:&work)
        let energy=try physical.energy(context.physical.system,acceleration:acceleration.values,work:&work,control:control)
        var virtual=0.0
        for i in drive.indices { try physical.charge(4,&work);let force:Double
            do throws(DynamicsError) { force=try context.physical.system.forces.total(at:i) } catch { throw RuntimeFailure(.invalidState,message:"Original energy applied force unavailable.") }
            virtual+=(drive[i]+force+acceleration.generalizedReaction[i])*context.physical.system.input.velocity[i]
        }
        guard abs(energy.requiredVirtualPower-virtual) <= policy.originalTolerance*(1+abs(virtual)),
              abs(energy.kineticEnergyRate-energy.requiredVirtualPower-energy.requiredPrescribedPower) <= policy.originalTolerance*(1+abs(energy.kineticEnergyRate)) else { throw RuntimeFailure(.invalidState,message:"Original physical power identity rejected.") }
        return publication(context,acceleration:acceleration,energy:energy)
    }
    @inline(never)
    private func publication(_ context:GeometricAccelerationContext,acceleration:ConstrainedMotion,energy:MechanicalEnergy) -> NonlinearMechanismState {
        NonlinearMechanismState(point:context.position.assembly.state.q+context.velocity.values,acceleration:acceleration,velocity:context.velocity,
            positionResidual:context.physical.positionResidual,velocityResidual:context.physical.velocityResidual,
            correction:context.position.assembly.pathCorrection,kineticEnergy:energy.kineticEnergy,chartCorrection:context.position.chartCorrection,
            positionEnergyChange:context.positionEnergyChange,mechanicalEnergy:energy,velocityEnergyChange:context.velocityEnergyChange)
    }
    private func correctedStage(time:Double,point:[Double],work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) -> (state:KinematicState,correction:Double) {
        let raw=try state(time:time,point:point,work:&work,control:control);var q=raw.q,delta=0.0
        for start in quaternionStarts {
            var square=0.0
            for i in start..<(start+4) { try physical.charge(2,&work);square+=q[i]*q[i] }
            guard square.isFinite,square > 0 else { throw RuntimeFailure(.invalidState,message:"Geometric RK quaternion chart singular.") }
            let length=square.squareRoot()
            for i in start..<(start+4) { try physical.charge(5,&work);let normalized=q[i]/length,d=normalized-q[i];delta+=d*d;q[i]=normalized }
        }
        delta=delta.squareRoot()
        guard delta.isFinite,delta <= maximumStageChartCorrection else { throw RuntimeFailure(.invalidState,message:"Geometric RK chart correction exceeds caller limit.") }
        do throws(JointError) { return (try KinematicState(revision:raw.revision,time:time,q:q,v:raw.v,acceleration:raw.acceleration,prescribedAnchors:raw.prescribedAnchors),delta) }
        catch { throw RuntimeFailure(.invalidState,message:"Geometric stage state invalid.") }
    }
    private func state(time:Double,point:[Double],work:inout NumericalWork,control:RuntimeStepControl?) throws(RuntimeFailure) -> KinematicState {
        let p=model.tree.layout.positionCount,n=model.tree.layout.velocityCount
        guard point.count == p+n,point.allSatisfy({$0.isFinite}) else { throw RuntimeFailure(.invalidState,message:"Geometric point invalid.") }
        let anchors=try samples(time:time,work:&work,control:control)
        do throws(JointError) { return try KinematicState(revision:model.stamp.revision,time:time,q:Array(point[..<p]),v:Array(point[p...]),acceleration:[Double](repeating:0,count:n),prescribedAnchors:anchors) }
        catch { throw RuntimeFailure(.invalidState,message:"Geometric source state invalid.") }
    }
    @inline(never)
    private func assemble(_ state:KinematicState,work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) -> ManifoldAssemblyResult {
        var local=try physical.supplier(&work,control:control);let before=local
        var result:ManifoldAssemblyResult?,failure:ManifoldProjectionFailure?
        do throws(ManifoldProjectionFailure) { result=try assembler.assemble(geometry,initial:state,policy:projection,work:&local) } catch { failure=error }
        try physical.finish(local,before:before,into:&work)
        if let failure { throw Self.failure(failure.cause) }
        try reserve(&work,control:control)
        guard let result,result.correctionMetadata == projection.metadata,result.state.time == state.time,result.state.v == state.v,
              result.state.acceleration == state.acceleration,result.state.prescribedAnchors == state.prescribedAnchors,result.pathCorrection.isFinite,result.pathCorrection <= projection.maximumPathCorrection else { throw RuntimeFailure(.invalidState,message:"Geometric assembly source differs.") }
        return result
    }
    @inline(never)
    private func evaluate(_ state:KinematicState,work:inout NumericalWork,control:RuntimeStepControl?) throws(RuntimeFailure) -> HolonomicGeometrySample {
        var local=try physical.supplier(&work,control:control);let before=local
        var result:HolonomicGeometrySample?,failure:GeometricConstraintError?
        do throws(GeometricConstraintError) { result=try evaluator.evaluate(geometry,state:state,policy:projection.constraints.evaluation,work:&local) } catch { failure=error }
        try physical.finish(local,before:before,into:&work)
        if let failure { throw Self.failure(failure) }
        try reserve(&work,control:control)
        guard let result else { throw RuntimeFailure(.invalidState,message:"Geometric supplier result absent.") }
        return try original(result,state:state,work:&work)
    }
    private func original(_ sample:HolonomicGeometrySample,state:KinematicState,work:inout NumericalWork) throws(RuntimeFailure) -> HolonomicGeometrySample {
        do throws(GeometricConstraintError) { return try GeometricOriginalAcceptance.validatedSample(sample,system:geometry,state:state,
            tolerance:policy.originalTolerance,policy:projection.constraints.evaluation,work:&work) }
        catch { throw Self.failure(error) }
    }
    private func residual(_ sample:HolonomicGeometrySample,velocity:Bool,work:inout NumericalWork) throws(RuntimeFailure) -> (position:Double,velocity:Double) {
        var rp=0.0,rv=0.0;let n=sample.source.v.count,a=sample.velocity,t=geometry.layout.timeScale
        for value in sample.values { try physical.charge(1,&work);rp=max(rp,abs(value)) }
        for axis in sample.alignmentResiduals { try physical.charge(3,&work);rp=max(rp,max(abs(axis.x),max(abs(axis.y),abs(axis.z)))) }
        for row in a.rowIDs.indices {
            var value=a.drift[row]
            for i in 0..<n { try physical.charge(4,&work);value+=a.rows[row*n+i]*sample.source.v[i]*t/geometry.layout.scales[i] }
            rv=max(rv,abs(value))
        }
        guard rp.isFinite,rv.isFinite,rp <= projection.constraints.originalResidualTolerance,(!velocity || rv <= policy.originalTolerance) else { throw RuntimeFailure(.invalidState,message:"Original geometric position/velocity inconsistent.") }
        if velocity { try GeometricAxisAcceptance.validate(geometry,snapshot:sample.snapshot,acceleration:nil,tolerance:policy.originalTolerance,work:&work) }
        return (rp,rv)
    }
    private func originalEnergy(_ state:KinematicState,work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) -> Double {
        let snapshot:KinematicSnapshot
        do throws(GeometricConstraintError) { snapshot=try CompiledGeometricConfigurationValidator().snapshot(geometry,state:state,policy:projection.constraints.evaluation,work:&work) }
        catch { throw Self.failure(error) }
        let system=try physical.system(snapshot:snapshot,v:state.v,work:&work,control:control)
        return try physical.energy(system,acceleration:state.acceleration,work:&work,control:control).kineticEnergy
    }
    internal var contextualScalarStorage:Int { physical.storage }
    /// The initial prefix supplies acceleration; accepted evolution prefixes also bind it to original force.
    @inline(never)
    internal func validateStoredPhysical(_ state:KinematicState,acceptedSteps:UInt64,work:inout NumericalWork) throws(RuntimeFailure) {
        let context=try storedPhysicalContext(state,work:&work)
        if acceptedSteps > 0 {
            let solution=try physical.solve(context,work:&work,control:nil)
            for i in state.acceleration.indices { try physical.charge(3,&work)
                guard abs(state.acceleration[i]-solution.values[i])*geometry.layout.timeScale*geometry.layout.timeScale/geometry.layout.scales[i] <= policy.originalTolerance else {
                    throw RuntimeFailure(.invalidState,message:"Stored original physical acceleration differs.")
                }
            }
        }
    }
    @inline(never)
    private func storedPhysicalContext(_ state:KinematicState,work:inout NumericalWork) throws(RuntimeFailure) -> NonlinearPhysicalSolveContext {
        try reserve(&work,control:nil)
        let original=try evaluate(state,work:&work,control:nil)
        let r=try residual(original,velocity:true,work:&work)
        for row in original.velocity.rowIDs.indices {
            var value=original.velocity.accelerationBias[row]
            for i in state.acceleration.indices { try physical.charge(5,&work);value+=original.velocity.rows[row*state.v.count+i]*state.acceleration[i]*geometry.layout.timeScale*geometry.layout.timeScale/geometry.layout.scales[i] }
            guard value.isFinite,abs(value) <= policy.originalTolerance else { throw RuntimeFailure(.invalidState,message:"Stored original geometric acceleration inconsistent.") }
        }
        try GeometricAxisAcceptance.validate(geometry,snapshot:original.snapshot,acceleration:state.acceleration,tolerance:policy.originalTolerance,work:&work)
        let system=try physical.system(snapshot:original.snapshot,v:state.v,work:&work,control:nil)
        return NonlinearPhysicalSolveContext(system:system,sample:original.velocity,impulse:false,positionResidual:r.position,velocityResidual:r.velocity)
    }
    internal func validatePrescribed(_ state:KinematicState,work:inout NumericalWork) throws(RuntimeFailure) {
        do throws(GeometricConstraintError) { try geometry.validatePrescribed(state,work:&work) }
        catch { throw Self.failure(error) }
    }
    private func samples(time:Double,work:inout NumericalWork,control:RuntimeStepControl?) throws(RuntimeFailure) -> [PrescribedAnchorState] {
        guard let program=geometry.prescribedMotion else { return [] }
        try reserve(&work,control:control)
        var local=try physical.supplier(&work,control:control),result:PrescribedMotionSample?,failure:PrescribedMotionError?
        let before=local
        do throws(PrescribedMotionError) { result=try motionSampler.sample(program,time:time,policy:program.policy,work:&local) } catch { failure=error }
        try physical.finish(local,before:before,into:&work)
        if let failure { throw Self.failure(.motion(failure)) }
        guard let result else { throw RuntimeFailure(.invalidState,message:"Prescribed sample absent.") }
        let original:PrescribedMotionSample
        do throws(PrescribedMotionError) { original=try OriginalPrescribedMotionAcceptance.validated(result,program:program,time:time,policy:program.policy,work:&work) }
        catch { throw Self.failure(.motion(error)) }
        try reserve(&work,control:control);return original.anchors
    }
    private func reserve(_ work:inout NumericalWork,control:RuntimeStepControl?) throws(RuntimeFailure) {
        if let control { try control.beginWorkBlock(units:1) }
        guard !policy.isCancelled(),!projection.constraints.evaluation.isCancelled(),!physical.admission.isCancelled() else { throw RuntimeFailure(.cancelled,message:"Geometric evolution cancelled.") }
        do throws(NumericalError) { try work.requireStorage(physical.storage) }
        catch { throw RuntimeFailure(.capacityExceeded,message:"Geometric workspace budget exhausted.") }
    }
    private static func failure(_ error:GeometricConstraintError) -> RuntimeFailure {
        switch error {
        case .cancelled,.motion(.cancelled): return RuntimeFailure(.cancelled,message:"Geometric supplier cancelled.")
        case .supplierLedgerReplaced,.motion(.supplierLedgerReplaced): return RuntimeFailure(.invalidOwnerAccess,message:"Geometric supplier replaced/reset admitted ledger.",failedSupplierWorkUnavailable:true)
        case .capacityExceeded,.numerical(.resourceLimit),.motion(.capacityExceeded),.motion(.numerical(.resourceLimit)): return RuntimeFailure(.capacityExceeded,message:"Geometric supplier capacity exhausted.")
        default: return RuntimeFailure(.invalidState,message:"Original geometric evaluation/assembly failed.",failedSupplierWorkUnavailable:error.failedSupplierWorkUnavailable)
        }
    }
    public func write(point:[Double],derivative:[Double],time:Double,trial:inout RuntimeTrial) throws(RuntimeFailure) {
        var work=NumericalWork(budget:publicationBudget)
        try acceptEndpoint(point:point,derivative:derivative,time:time,work:&work,control:nil)
        try publish(point:point,derivative:derivative,time:time,trial:&trial,work:&work,control:nil)
    }
    public func writeAccepted(point:[Double],derivative:[Double],time:Double,trial:inout RuntimeTrial,work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) {
        try acceptEndpoint(point:point,derivative:derivative,time:time,work:&work,control:control)
        try publish(point:point,derivative:derivative,time:time,trial:&trial,work:&work,control:control)
    }
    @inline(never)
    private func acceptEndpoint(point:[Double],derivative:[Double],time:Double,work:inout NumericalWork,control:RuntimeStepControl?) throws(RuntimeFailure) {
        try reserve(&work,control:control)
        let state=try state(time:time,point:point,work:&work,control:control),p=state.q.count,n=state.v.count,sample:HolonomicGeometrySample
        guard derivative.count == p+n,derivative.allSatisfy({$0.isFinite}) else { throw RuntimeFailure(.invalidState,message:"Geometric endpoint derivative invalid.") }
        // Sealed builtin evaluation gives authority independently of injected suppliers and previous stages.
        do throws(GeometricConstraintError) { sample=try GeometricRelationEvaluator().evaluate(geometry,state:state,policy:projection.constraints.evaluation,work:&work) }
        catch { throw Self.failure(error) }
        _=try residual(sample,velocity:true,work:&work)
        for i in 0..<p { try physical.charge(2,&work);guard abs(derivative[i]-sample.snapshot.coordinateRate[i]) <= policy.originalTolerance else { throw RuntimeFailure(.invalidState,message:"Geometric endpoint qdot source differs.") } }
        for row in sample.velocity.rowIDs.indices {
            var value=sample.velocity.accelerationBias[row]
            for i in 0..<n { try physical.charge(5,&work);value+=sample.velocity.rows[row*n+i]*derivative[p+i]*geometry.layout.timeScale*geometry.layout.timeScale/geometry.layout.scales[i] }
            guard value.isFinite,abs(value) <= policy.originalTolerance else { throw RuntimeFailure(.invalidState,message:"Original geometric endpoint acceleration inconsistent.") }
        }
        try GeometricAxisAcceptance.validate(geometry,snapshot:sample.snapshot,acceleration:Array(derivative[p...]),tolerance:policy.originalTolerance,work:&work)
        try reserve(&work,control:control)
    }
    private func publish(point:[Double],derivative:[Double],time:Double,trial:inout RuntimeTrial,work:inout NumericalWork,control:RuntimeStepControl?) throws(RuntimeFailure) {
        let p=model.tree.layout.positionCount,n=model.tree.layout.velocityCount
        let anchors=try samples(time:time,work:&work,control:control)
        for sample in anchors { _=try trial.prescribedAnchor(sample.frame) }
        for i in 0..<p { _=try trial.position(at:i) };for i in 0..<n { _=try trial.velocity(at:i) }
        for i in 0..<p { try trial.setPosition(point[i],at:i) }
        for i in 0..<n { try trial.setVelocity(point[p+i],at:i);try trial.setAcceleration(derivative[p+i],at:i) }
        for sample in anchors { try trial.setPrescribedAnchor(sample) }
        try trial.setTime(time)
    }
}
