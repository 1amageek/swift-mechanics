import SwiftMechanics

@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal struct TrajectoryAnchorEvolutionFixture {
    let model:CompiledMechanicalModel
    let program:PrescribedTrajectoryProgram
    let geometry:GeometricConstraintSystem
    let first:Int
    let second:Int
    init(piecewise:Bool) throws {
        let old=try MovingBaseFixture(),law=old.program.motions[0],d=old.model.descriptor
        first=old.first;second=old.second
        var work=try GeometricEvolutionFixtures.work()
        let policy=try PrescribedTrajectoryPolicy(motion:old.program.policy,maximumSegments:4),trajectory:PrescribedTrajectory
        if piecewise {
            let start=try TrajectoryAnchorOracle(0,piecewise:true).jet(),middle=try TrajectoryAnchorOracle(1,piecewise:true).jet(),end=try TrajectoryAnchorOracle(2,piecewise:true).jet()
            trajectory = .piecewise(try PiecewisePrescribedMotion(frame:law.frame,parentFrame:law.parentFrame,initialPose:law.initialPose,rotationAxis:.unitZ,
                segments:[PrescribedMotionSegment(startTime:0,endTime:1,start:start,end:middle),PrescribedMotionSegment(startTime:1,endTime:2,start:middle,end:end)],policy:policy,work:&work))
        } else {
            trajectory = .harmonic(try HarmonicPrescribedMotion(frame:law.frame,parentFrame:law.parentFrame,referenceTime:0,initialPose:law.initialPose,
                translationSine:law.translationRate,translationCosine:law.translationAcceleration.scaled(by:-1),rotationAxis:.unitZ,
                angularSine:0.4,angularCosine:-0.2,frequency:1,phase:0,minimumTime:0,maximumTime:2,maximumIdentifierBytes:100))
        }
        program=try PrescribedTrajectoryProgram(trajectories:[trajectory],policy:policy,work:&work)
        let anchors=try AnalyticPrescribedTrajectorySampler().sample(program,time:0,policy:policy,work:&work).anchors
        let initial=try KinematicState(revision:1,time:0,q:d.initialState.q,v:d.initialState.v,acceleration:d.initialState.acceleration,prescribedAnchors:anchors)
        let descriptor=try MechanicalDescriptor(identity:d.identity,revision:d.revision,bodies:d.bodies,joints:d.joints,root:d.root,rootBase:d.rootBase,
            rootAuthority:d.rootAuthority,worldFrame:d.worldFrame,initialState:initial,representationRequirements:d.representationRequirements,features:d.features,extensions:d.extensions)
        model=try ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()).compile(descriptor,policy:old.model.policy)
        geometry=try GeometricConstraintSystem(model:model,layout:old.geometry.layout,relations:old.geometry.relations,minimumPosition:old.geometry.minimumPosition,
            maximumPosition:old.geometry.maximumPosition,minimumTime:0,maximumTime:2,
            capacity:GeometricConstraintCapacity(maximumBodies:8,maximumPositions:8,maximumVelocities:8,maximumRows:8,maximumMetadataBytes:50000),work:&work,prescribedTrajectory:program)
    }
    func equation(sampler:any PrescribedTrajectorySampling = AnalyticPrescribedTrajectorySampler(),query:any PrescribedTrajectoryBoundaryQuerying = PrescribedTrajectoryBoundaryQuery()) throws -> GeometricMechanismEquation {
        let old=try MovingBaseFixture().equation()
        return try GeometricMechanismEquation(identity:old.descriptor.identity,geometry:geometry,drive:old.drive,policy:old.policy,projection:old.projection,
            maximumStageChartCorrection:0.25,publicationBudget:old.publicationBudget,admission:NonlinearMechanismFixtures.admission(),maximumIdentityBytes:100000,
            physicalKernel:RigidEquationKernel(),physicalSolver:MassWeightedMechanismSolver(physicalDynamics:DenseRigidDynamics(physicalEquations:RigidEquationKernel()),physicalEquations:RigidEquationKernel()),
            trajectorySampler:sampler,boundaryQuery:query)
    }
}
