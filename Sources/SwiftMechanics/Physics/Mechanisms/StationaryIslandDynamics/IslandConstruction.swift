internal final class IslandConstruction: Sendable {
    let descriptor: MechanicalDescriptor
    let layout: TreeCoordinateLayout
    let indices: [Int]
    let constraintsLayout: ConstraintCoordinateLayout
    let constraints: QuadraticConstraintSystem?
    let drive: [Double]
    let policy: MechanismSolvePolicy
    init(source: CompiledMechanicalModel, constraints original: QuadraticConstraintSystem, drive originalDrive: [Double],
         indices selected: [Int], policy outer: StationaryIslandPolicy, work: inout NumericalWork) throws(StationaryIslandFailureReason) {
        let n=selected.count
        try IslandArithmetic.charge(try IslandArithmetic.product(source.tree.bodies.count,n),&work)
        let selectedJoints=source.descriptor.joints.filter { joint in source.tree.layout.joints.contains { selected.contains($0.velocities.start) && $0.joint == joint.record.id } }
        let selectedBodies=source.descriptor.bodies.filter { body in body.id == source.descriptor.root || selectedJoints.contains { $0.record.childBody == body.id } }
        let tree:KinematicTree
        do { tree=try KinematicTree(bodies:try selectedBodies.map { try $0.kinematicBody() },joints:selectedJoints.map {$0.record},
            root:source.descriptor.root,rootBase:.fixed,worldFrame:source.tree.worldFrame,revision:source.stamp.revision,capacity:source.policy.kinematicCapacity) }
        catch { throw .kinematics(error) }
        var mapping=[Int](repeating:-1,count:n)
        for local in tree.layout.joints {
            guard let original=source.tree.layout.joints.first(where:{$0.joint == local.joint}),local.velocities.count == 1,
                  local.positions.start == local.velocities.start,selected.contains(original.velocities.start) else { throw .sourceMismatch }
            mapping[local.velocities.start]=original.velocities.start
        }
        guard mapping.allSatisfy({$0 >= 0}) else { throw .sourceMismatch }
        indices=mapping;layout=tree.layout
        let suffix=".island."+String(selected[0])
        guard try IslandArithmetic.sum(source.stamp.identity.utf8.count,suffix.utf8.count) <= outer.maximumIdentifierBytes else { throw .capacityExceeded }
        let identity=source.stamp.identity+suffix
        guard identity.utf8.count <= outer.maximumIdentifierBytes else { throw .capacityExceeded }
        let state:KinematicState
        do throws(JointError) { state=try KinematicState(revision:source.stamp.revision,time:source.descriptor.initialState.time,
            q:mapping.map {source.descriptor.initialState.q[$0]},v:mapping.map {source.descriptor.initialState.v[$0]},acceleration:mapping.map {source.descriptor.initialState.acceleration[$0]}) }
        catch { throw .kinematics(error) }
        do throws(CompilationFailure) { descriptor=try MechanicalDescriptor(identity:identity,revision:source.stamp.revision,bodies:selectedBodies,joints:selectedJoints,
            root:source.descriptor.root,rootBase:.fixed,rootAuthority:.fixed,worldFrame:source.tree.worldFrame,initialState:state,
            representationRequirements:[],features:[],extensions:[]) }
        catch { throw .compilation(error) }
        do throws(ConstraintError) {
            constraintsLayout=try ConstraintCoordinateLayout(coordinateIDs:mapping.map {original.layout.coordinateIDs[$0]},dimensions:mapping.map {original.layout.dimensions[$0]},
                scales:mapping.map {original.layout.scales[$0]},timeScale:original.layout.timeScale,revision:original.layout.revision)
            var rows:[QuadraticConstraint]=[]
            for row in original.rows where mapping.contains(where:{row.linear[$0] != 0}) {
                rows.append(QuadraticConstraint(id:row.id,constant:row.constant,linear:mapping.map {row.linear[$0]},hessian:[Double](repeating:0,count:n*n),
                    timeLinear:0,timeQuadratic:0,mixedTime:[Double](repeating:0,count:n)))
            }
            if rows.isEmpty { constraints=nil }
            else { constraints=try QuadraticConstraintSystem(layout:constraintsLayout,rows:rows,minimumPosition:mapping.map {original.minimumPosition[$0]},
                maximumPosition:mapping.map {original.maximumPosition[$0]},minimumTime:original.minimumTime,maximumTime:original.maximumTime) }
        } catch { throw .constraint(error) }
        let originalPolicy=outer.mechanics.constraints
        let projected:ConstraintSolvePolicy
        do throws(ConstraintError) {
            projected=try ConstraintSolvePolicy(evaluation:originalPolicy.evaluation,diagonalMetric:mapping.map {originalPolicy.diagonalMetric[$0]},
                energyScale:originalPolicy.energyScale,rankPolicy:originalPolicy.rankPolicy,rankRelativeTolerance:originalPolicy.rankRelativeTolerance,
                originalResidualTolerance:originalPolicy.originalResidualTolerance,maximumCorrection:originalPolicy.maximumCorrection,
                nonlinear:originalPolicy.nonlinear,linearCapability:originalPolicy.linearCapability,linearTolerance:originalPolicy.linearTolerance)
        } catch { throw .constraint(error) }
        let dynamics:DynamicsSolvePolicy
        do throws(DynamicsError) { dynamics=try DynamicsSolvePolicy(capability:outer.mechanics.dynamics.capability,linearTolerance:outer.mechanics.dynamics.linearTolerance,
            coordinateScales:constraintsLayout.scales,energyScale:outer.mechanics.dynamics.energyScale,timeScale:outer.mechanics.dynamics.timeScale) }
        catch { throw .dynamics(error) }
        do throws(MechanismError) { policy=try MechanismSolvePolicy(dynamics:dynamics,constraints:projected,maximumCoordinates:outer.mechanics.maximumCoordinates,
            maximumRows:outer.mechanics.maximumRows,originalTolerance:outer.mechanics.originalTolerance,isCancelled:outer.mechanics.isCancelled) }
        catch { throw .mechanism(error) }
        drive=mapping.map {originalDrive[$0]}
    }
}
