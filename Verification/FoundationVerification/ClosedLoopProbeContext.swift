import SwiftMechanics

/// Retains immutable sources on the heap while each expensive public operation owns a distinct stack phase.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class ClosedLoopProbeContext: Sendable {
    let fixture: ClosedLoopProbeModel
    let geometry: GeometricConstraintSystem
    let physicalRows: GeometricPhysicalRowWitness
    let dynamics: RigidDynamicsSystem
    let motion: ConstrainedMotion

    @inline(never)
    init(fixture:ClosedLoopProbeModel,scale:Double=4,duplicate:Bool=false) throws {
        self.fixture=fixture
        let geometry=try Self.geometry(fixture,scale:scale,duplicate:duplicate)
        self.geometry=geometry
        let physicalRows=try Self.rows(geometry,state:fixture.model.descriptor.initialState)
        self.physicalRows=physicalRows
        let dynamics=try Self.assemble(fixture)
        self.dynamics=dynamics
        motion=try Self.solve(dynamics,rows:physicalRows)
    }
    @inline(never)
    private static func geometry(_ fixture:ClosedLoopProbeModel,scale:Double,duplicate:Bool) throws -> GeometricConstraintSystem {
        let model=fixture.model
        let first=try GeometricFrameEndpoint(body:fixture.first,frame:EntityID(kind:.frame,key:fixture.first.key+"-frame"),point:fixture.offset ? .unitX : .zero)
        let second=try GeometricFrameEndpoint(body:fixture.second,frame:EntityID(kind:.frame,key:fixture.second.key+"-frame"),point:fixture.offset ? .unitY : .zero)
        let target=try GeometricAnalyticTarget(value:Vector3(2,0,0))
        var relations=[try GeometricRelation(kind:.distance,rowIDs:[91],first:first,second:second,target:target,scale:scale)]
        if duplicate { relations.append(try GeometricRelation(kind:.distance,rowIDs:[92],first:first,second:second,target:target,scale:scale)) }
        let layout=try ConstraintCoordinateLayout(coordinateIDs:[10,20],dimensions:[.length,.length],scales:[2,3],timeScale:5,revision:1)
        var work=try MechanismProbeContext.work()
        return try GeometricConstraintSystem(model:model,layout:layout,relations:relations,minimumPosition:[-20,-20],maximumPosition:[20,20],minimumTime:0,maximumTime:5,
            capacity:GeometricConstraintCapacity(maximumBodies:3,maximumPositions:2,maximumVelocities:2,maximumRows:4,maximumMetadataBytes:32768),work:&work)
    }
    @inline(never)
    private static func rows(_ geometry:GeometricConstraintSystem,state:KinematicState) throws -> GeometricPhysicalRowWitness {
        var work=try MechanismProbeContext.work()
        let service:any HolonomicGeometryProviding=GeometricRelationEvaluator()
        let policy=try rowPolicy()
        let sample=try service.evaluate(geometry,state:state,policy:policy.evaluation,work:&work)
        return try service.physicalRows(geometry,state:state,supplied:sample,policy:policy,work:&work)
    }
    @inline(never)
    static func assemble(_ fixture:ClosedLoopProbeModel,force:Double=10) throws -> RigidDynamicsSystem {
        let model=fixture.model
        var inertias:[RigidBodyInertia]=[]
        for body in model.tree.bodies {
            guard let raw=model.descriptor.bodies.first(where:{$0.id == body.id}),case .spatial(let spatial)=raw,
                  let inertia=spatial.inertia else { throw FoundationVerificationError.analyticCheckFailed }
            inertias.append(try RigidBodyInertia(body:body.id,frame:body.frame,properties:inertia.properties))
        }
        let applied=try BodyWrenchContribution(body:fixture.first,frame:model.tree.worldFrame,referencePoint:fixture.offset ? .unitY : .zero,
            wrench:SpatialWrench(torque:.zero,force:Vector3(force,0,fixture.offset ? 5 : 0)),channel:.applied)
        let input=try RigidDynamicsInput(snapshot:model.initialSnapshot,velocity:model.descriptor.initialState.v,inertias:inertias,gravity:nil,bodyWrenches:[applied])
        var work=try MechanismProbeContext.work(),load=try loadWork()
        let service:any RigidEquationComputing=RigidEquationKernel()
        return try service.assemble(input,admission:MechanismProbeContext.admission(),loadWork:&load,work:&work)
    }
    @inline(never)
    static func solve(_ dynamics:RigidDynamicsSystem,rows:GeometricPhysicalRowWitness,impulse:Bool=false) throws -> ConstrainedMotion {
        var work=try MechanismProbeContext.work(),dynamic=try MechanismProbeContext.work(),rank=try MechanismProbeContext.work(),linear=try MechanismProbeContext.work()
        let service:any ConstrainedMechanismSolving=MassWeightedMechanismSolver(),policy=try MechanismProbeContext.policy()
        if impulse { return try service.reconcileVelocity(dynamics,sample:rows.original.velocity,policy:policy,
            work:&work,dynamicsWork:&dynamic,rankWork:&rank,linearWork:&linear) }
        return try service.acceleration(dynamics,sample:rows.original.velocity,drive:[0,0],policy:policy,
            work:&work,dynamicsWork:&dynamic,rankWork:&rank,linearWork:&linear)
    }
    @inline(never)
    func input(dynamics:RigidDynamicsSystem?=nil,state:KinematicState?=nil,motion:ConstrainedMotion?=nil,
               drive:[Double]=[0,0],topology:ClosedLoopReactionTopology = .completeTreeAndDeclaredRows) -> ClosedLoopReactionInput {
        ClosedLoopReactionInput(dynamics:dynamics ?? self.dynamics,geometry:geometry,state:state ?? fixture.model.descriptor.initialState,
            physicalRows:physicalRows,motion:motion ?? self.motion,originalDrive:drive,topology:topology)
    }
    @inline(never)
    func recover(frame:EntityID?=nil) throws -> ClosedLoopReactionReport {
        let input=self.input(),policy=try Self.policy()
        var work=try MechanismProbeContext.work(),load=try Self.loadWork()
        let service:any ClosedLoopReactionRecovering=ClosedLoopReactionRecovery()
        return try service.recover(input,outputFrame:frame ?? fixture.model.tree.worldFrame,policy:policy,loadWork:&load,work:&work)
    }
    static func loadWork() throws -> LoadWork { LoadWork(budget:try LoadBudget(maximumWork:100,maximumScalars:0)) }
    static func rowPolicy() throws -> GeometricPhysicalRowPolicy {
        try GeometricPhysicalRowPolicy(evaluation:MechanismProbeContext.policy().constraints.evaluation,maximumBodies:3,
            originalComparisonTolerance:1e-10,projectionTolerance:NumericalTolerance(absolute:1e-10,relative:1e-10))
    }
    @inline(never)
    static func policy() throws -> ClosedLoopReactionPolicy {
        let tolerance=try NumericalTolerance(absolute:1e-9,relative:1e-10)
        let tree=try TreeReactionPolicy(maximumBodies:3,maximumJoints:2,maximumBodyLoads:8,generalizedForceScales:[1,1],
            generalizedTolerance:tolerance,forceTolerance:tolerance,torqueTolerance:tolerance)
        return try ClosedLoopReactionPolicy(maximumRows:4,geometry:rowPolicy(),rank:MechanismProbeContext.policy().constraints,
            tree:tree,admission:MechanismProbeContext.admission(),positionTolerance:1e-9,velocityTolerance:1e-9,accelerationTolerance:1e-9)
    }
}
