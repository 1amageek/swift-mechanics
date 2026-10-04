import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
struct ClosedLoopProbeModel: Sendable {
    let model: CompiledMechanicalModel
    let first: EntityID
    let second: EntityID
    let firstJoint: EntityID
    let secondJoint: EntityID
    let firstIndex: Int
    let secondIndex: Int
    let offset: Bool

    @inline(never)
    init(offset: Bool = false) throws {
        self.offset=offset
        let id=MechanismProbeContext.id
        let root=try id(.body,"closed-loop-root")
        first=try id(.body,"closed-loop-first");second=try id(.body,"closed-loop-second")
        firstJoint=try id(.joint,"closed-loop-first-slide");secondJoint=try id(.joint,"closed-loop-second-slide")
        let tolerance=try NumericalTolerance(absolute:1e-12,relative:1e-12)
        let inertiaPolicy=try InertiaValidationPolicy(symmetry:tolerance,physicalityRelative:0)
        let rotated=try UnitQuaternion(axis:.unitZ,angle:offset ? .pi/2 : 0)
        let poses=[RigidTransform.identity,RigidTransform(rotation:rotated,translation:.zero),
                   RigidTransform(rotation:.identity,translation:try Vector3(2,0,0))]
        let ids=[root,first,second],masses=[1.0,2,3]
        var bodies:[MechanicalBody]=[]
        for i in ids.indices {
            let properties=try MassProperties3D(mass:masses[i],centerOfMass:.zero,inertiaAtCenter:.identity,policy:inertiaPolicy)
            bodies.append(.spatial(try BodyRecord3D(id:ids[i],frame:id(.frame,ids[i].key+"-frame"),mode:i == 0 ? .static : .dynamic,
                bodyToWorld:poses[i],representations:BodyRepresentations(),inertia:InertialRepresentation3D(properties:properties,
                provenance:SourceProvenance(source:"closed-loop-public-oracle",revision:1),quality:.exact))))
        }
        let joints=try [Self.joint(firstJoint,parent:root,child:first,rotation:UnitQuaternion(axis:.unitZ,angle:offset ? -.pi/2 : 0)),
                        Self.joint(secondJoint,parent:root,child:second,rotation:.identity)]
        let capacity=try KinematicCapacity(maximumBodies:3,maximumVelocities:2,maximumJacobianScalars:64)
        let world=try id(.frame,"closed-loop-world")
        let proposed=try KinematicTree(bodies:bodies.map { try $0.kinematicBody() },joints:joints.map {$0.record},root:root,
            rootBase:.fixed,worldFrame:world,revision:1,capacity:capacity)
        firstIndex=try Self.index(firstJoint,layout:proposed.layout)
        secondIndex=try Self.index(secondJoint,layout:proposed.layout)
        var q=[Double](repeating:0,count:proposed.layout.positionCount)
        q[firstIndex]=0;q[secondIndex]=2
        let zero=[Double](repeating:0,count:proposed.layout.velocityCount)
        let descriptor=try MechanicalDescriptor(identity:"closed-loop-public",revision:1,bodies:bodies,joints:joints,root:root,
            rootBase:.fixed,rootAuthority:.fixed,worldFrame:world,initialState:KinematicState(revision:1,time:0,q:q,v:zero,acceleration:zero),
            representationRequirements:[],features:[],extensions:[])
        let policy=try CompilationPolicy(kinematicCapacity:capacity,
            jointPolicy:JointEvaluationPolicy(quaternionTolerance:tolerance,chartRankRelative:1e-10,characteristicLengthMeters:1),
            inertiaPolicy:inertiaPolicy,translationTolerance:tolerance,rotationTolerance:tolerance,
            maximumRecords:64,maximumIdentifierBytes:8192,maximumSparsityEntries:1024,maximumDependencyEntries:1024,
            maximumExtensionRecords:1,maximumDiagnostics:8,extensionBudget:NumericalBudget(scalarStorage:100,arithmeticOperations:1000,iterations:10),
            target:FoundationVerification.compilerVerificationTarget)
        model=try ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()).compile(descriptor,policy:policy)
        guard model.tree.layout == proposed.layout, firstIndex != secondIndex else { throw FoundationVerificationError.analyticCheckFailed }
    }
    @inline(never)
    private static func joint(_ id:EntityID,parent:EntityID,child:EntityID,rotation:UnitQuaternion) throws -> MechanicalJoint {
        let record=try JointRecord(id:id,parentBody:parent,childBody:child,
            parentAnchor:JointAnchor(frame:EntityID(kind:.frame,key:id.key+"-parent"),placement:.fixed(.identity)),
            childAnchor:JointAnchor(frame:EntityID(kind:.frame,key:id.key+"-child"),placement:.fixed(RigidTransform(rotation:rotation,translation:.zero))),
            manifold:JointManifold(.prismatic(axis:.unitX)))
        return MechanicalJoint(record:record,authority:.dynamicState)
    }
    private static func index(_ id:EntityID,layout:TreeCoordinateLayout) throws -> Int {
        guard let entry=layout.joints.first(where:{$0.joint == id}),entry.positions.count == 1,entry.velocities.count == 1,
              entry.positions.start == entry.velocities.start else { throw FoundationVerificationError.analyticCheckFailed }
        return entry.positions.start
    }
}
