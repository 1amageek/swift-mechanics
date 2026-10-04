import SwiftMechanics

@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal struct TrajectoryEvolutionFixtures {
    let model:CompiledMechanicalModel
    let program:PrescribedBaseTrajectoryProgram
    let geometry:GeometricConstraintSystem
    let planar:Bool
    let piecewise:Bool
    let descendants:Bool
    let first:Int
    let second:Int
    init(planar:Bool,piecewise:Bool,descendants:Bool=false,futureChange:Double=0) throws {
        self.planar=planar;self.piecewise=piecewise;self.descendants=descendants
        let old=try PrescribedRootEvolutionFixture(planar:planar,descendants:descendants)
        first=old.first;second=old.second
        var work=try GeometricEvolutionFixtures.work()
        let policy=try PrescribedTrajectoryPolicy(motion:old.program.policy,maximumSegments:4),law=old.program.law
        let trajectory:PrescribedTrajectory
        if piecewise {
            let start=try TrajectoryMotionOracle(time:0,planar:planar,piecewise:true).jet()
            let middle=try TrajectoryMotionOracle(time:1,planar:planar,piecewise:true).jet()
            let end=try TrajectoryMotionOracle(time:2,planar:planar,piecewise:true,futureChange:futureChange).jet()
            trajectory = .piecewise(try PiecewisePrescribedMotion(frame:law.frame,parentFrame:law.parentFrame,initialPose:law.initialPose,
                rotationAxis:law.rotationAxis,segments:[PrescribedMotionSegment(startTime:0,endTime:1,start:start,end:middle),
                PrescribedMotionSegment(startTime:1,endTime:2,start:middle,end:end)],policy:policy,work:&work))
        } else {
            trajectory = .harmonic(try HarmonicPrescribedMotion(frame:law.frame,parentFrame:law.parentFrame,referenceTime:0,initialPose:law.initialPose,
                translationSine:law.translationRate,translationCosine:law.translationAcceleration.scaled(by:-1),rotationAxis:law.rotationAxis,
                angularSine:0.2,angularCosine:-0.3,frequency:1,phase:0,minimumTime:0,maximumTime:2,maximumIdentifierBytes:100))
        }
        program=try PrescribedBaseTrajectoryProgram(trajectory:trajectory,layout:old.program.layout,policy:policy,work:&work)
        let base=try AnalyticPrescribedBaseTrajectorySampler().sampleBase(program,time:0,policy:policy,work:&work),d=old.model.descriptor
        let initial=try KinematicState(revision:1,time:0,q:base.q+(descendants ? [0.3,0.3] : []),v:base.v+(descendants ? [0.1,0.1] : []),
            acceleration:base.a+(descendants ? [-0.1,-0.1] : []))
        let descriptor=try MechanicalDescriptor(identity:d.identity,revision:d.revision,bodies:d.bodies,joints:d.joints,root:d.root,rootBase:d.rootBase,
            rootAuthority:d.rootAuthority,worldFrame:d.worldFrame,initialState:initial,representationRequirements:d.representationRequirements,features:d.features,extensions:d.extensions)
        model=try ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()).compile(descriptor,policy:old.model.policy)
        geometry=try GeometricConstraintSystem(model:model,layout:old.geometry.layout,relations:old.geometry.relations,
            minimumPosition:old.geometry.minimumPosition,maximumPosition:old.geometry.maximumPosition,minimumTime:0,maximumTime:2,
            capacity:GeometricConstraintCapacity(maximumBodies:8,maximumPositions:16,maximumVelocities:8,maximumRows:12,maximumMetadataBytes:50000),
            work:&work,prescribedBaseTrajectory:program)
    }
    func equation(sampler:any PrescribedBaseTrajectorySampling = AnalyticPrescribedBaseTrajectorySampler(),
                  query:any PrescribedTrajectoryBoundaryQuerying = PrescribedTrajectoryBoundaryQuery()) throws -> GeometricMechanismEquation {
        let old=try PrescribedRootEvolutionFixture(planar:planar,descendants:descendants).equation()
        var drive=[Double](repeating:0,count:geometry.layout.scales.count);if descendants { drive[first]=1 }
        return try GeometricMechanismEquation(identity:old.descriptor.identity,geometry:geometry,drive:drive,policy:old.policy,projection:old.projection,
            maximumStageChartCorrection:0.25,publicationBudget:old.publicationBudget,admission:NonlinearMechanismFixtures.admission(),maximumIdentityBytes:100000,
            physicalKernel:RigidEquationKernel(),prescribedRootSolver:MassWeightedMechanismSolver(physicalDynamics:DenseRigidDynamics(physicalEquations:RigidEquationKernel()),physicalEquations:RigidEquationKernel()),
            activeRanker:WeightedConstraintAssembler(),baseTrajectorySampler:sampler,boundaryQuery:query)
    }
    func sample(_ time:Double) throws -> PrescribedBaseMotionSample {
        var work=try GeometricEvolutionFixtures.work()
        return try AnalyticPrescribedBaseTrajectorySampler().sampleBase(program,time:time,policy:program.policy,work:&work)
    }
    func session(_ equation:GeometricMechanismEquation,step:Double=0.1) throws -> (PlanarEvolutionFixtures.Session,IntegrationContinuationProvider) {
        try PlanarEvolutionFixtures.session(equation,step:step)
    }
}
