import SwiftMechanics

internal struct TrajectoryGeometryFixtures {
    let model:CompiledMechanicalModel
    let program:PrescribedBaseTrajectoryProgram
    let system:GeometricConstraintSystem
    init(planar:Bool,descendants:Bool=false) throws {
        let old=try PrescribedRootGeometryFixture(planar:planar,descendants:descendants),law=old.program.law
        var work=try GeometricFixtures.work()
        let policy=try PrescribedTrajectoryPolicy(motion:old.program.policy,maximumSegments:2)
        let motion=try HarmonicPrescribedMotion(frame:law.frame,parentFrame:law.parentFrame,referenceTime:0,initialPose:law.initialPose,
            translationSine:law.translationRate,translationCosine:law.translationAcceleration.scaled(by:-1),rotationAxis:.unitZ,
            angularSine:0.2,angularCosine:-0.3,frequency:1,phase:0,minimumTime:0,maximumTime:2,maximumIdentifierBytes:100)
        program=try PrescribedBaseTrajectoryProgram(trajectory:.harmonic(motion),layout:old.program.layout,policy:policy,work:&work)
        let sample=try AnalyticPrescribedBaseTrajectorySampler().sampleBase(program,time:0,policy:policy,work:&work),d=old.model.descriptor
        let initial=try KinematicState(revision:1,time:0,q:sample.q+(descendants ? [0.3,0.3] : []),v:sample.v+(descendants ? [0,0] : []),acceleration:sample.a+(descendants ? [0,0] : []))
        let descriptor=try MechanicalDescriptor(identity:d.identity,revision:d.revision,bodies:d.bodies,joints:d.joints,root:d.root,rootBase:d.rootBase,
            rootAuthority:d.rootAuthority,worldFrame:d.worldFrame,initialState:initial,representationRequirements:d.representationRequirements,features:d.features,extensions:d.extensions)
        model=try ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()).compile(descriptor,policy:old.model.policy)
        system=try GeometricConstraintSystem(model:model,layout:old.system.layout,relations:old.system.relations,minimumPosition:old.system.minimumPosition,
            maximumPosition:old.system.maximumPosition,minimumTime:0,maximumTime:2,
            capacity:GeometricConstraintCapacity(maximumBodies:8,maximumPositions:16,maximumVelocities:8,maximumRows:12,maximumMetadataBytes:50000),work:&work,prescribedBaseTrajectory:program)
    }
}
