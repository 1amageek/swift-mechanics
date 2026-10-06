public struct ReferenceStationaryIslandPreparer: StationaryIslandPreparing {
    private let compiler: any MechanicalModelCompiling
    private let equations: any RigidEquationComputing
    public init(compiler: any MechanicalModelCompiling = ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()),
                equations: any RigidEquationComputing = RigidEquationKernel()) {
        self.compiler=compiler;self.equations=equations
    }
    @inline(never)
    public func prepare(source: CompiledMechanicalModel, constraints: QuadraticConstraintSystem, drive: [Double],
                        policy: StationaryIslandPolicy, work: inout StationaryIslandWork) throws(StationaryIslandFailure) -> StationaryIslandProgram {
        do throws(StationaryIslandFailureReason) {
            try IslandArithmetic.check(policy)
            let groups=try admit(source,constraints:constraints,drive:drive,policy:policy,work:&work.numerical)
            guard work.compilationCalls <= policy.maximumCompilationCalls,groups.count <= policy.maximumIslands, groups.count <= policy.maximumCompilationCalls-work.compilationCalls else { throw .capacityExceeded }
            let binding=try IslandSourceSignature.encode(source:source,constraints:constraints,drive:drive,policy:policy,work:&work.numerical)
            var islands:[StationaryMechanicalIsland]=[];islands.reserveCapacity(groups.count)
            for indices in groups {
                try IslandArithmetic.check(policy)
                islands.append(try makeIsland(source,constraints:constraints,drive:drive,indices:indices,policy:policy,work:&work))
            }
            let program=StationaryIslandProgram(source:source,constraints:constraints,drive:drive,policy:policy,islands:islands,
                binding:binding,inertias:try IslandSource.inertias(source))
            try IslandSource.validatePartition(program,physical:source.descriptor.initialState,equations:equations,work:&work)
            try IslandArithmetic.check(policy)
            return program
        } catch { if IslandArithmetic.unavailable(error) { work.unavailable() };throw StationaryIslandFailure(error,work:work) }
    }
    @inline(never)
    private func admit(_ source: CompiledMechanicalModel, constraints: QuadraticConstraintSystem, drive: [Double],
                       policy: StationaryIslandPolicy, work: inout NumericalWork) throws(StationaryIslandFailureReason) -> [[Int]] {
        let n=source.tree.layout.velocityCount,m=constraints.rows.count
        guard n > 0,n <= policy.mechanics.maximumCoordinates,n <= policy.admission.capacity.maximumVelocities,n <= policy.mechanics.constraints.evaluation.maximumCoordinates,
              source.tree.bodies.count <= policy.admission.capacity.maximumBodies,m <= policy.mechanics.maximumRows,
              m <= policy.mechanics.constraints.evaluation.maximumRows,drive.count == n else { throw .capacityExceeded }
        let square=try IslandArithmetic.product(n,n)
        try IslandArithmetic.storage(try IslandArithmetic.sum(try IslandArithmetic.product(m,square),try IslandArithmetic.product(8,square)),&work)
        // FIXME(INCOMPLETE_IMPLEMENTATION): This public preparation admits direct scalar spatial branches only.
        // General trees, semantic extensions, prescribed/floating motion and external load ownership need original partition evidence before success.
        guard source.tree.rootBase == .fixed,source.descriptor.rootAuthority == .fixed,source.tree.layout.positionCount == n,
              source.tree.joints.count == n,source.tree.bodies.count == n+1,
              source.descriptor.features.isEmpty,source.descriptor.extensions.isEmpty,source.descriptor.representationRequirements.isEmpty,
              source.descriptor.initialState.prescribedAnchors.isEmpty,
              constraints.layout.revision == source.stamp.revision,constraints.layout.scales.count == n,
              constraints.layout.coordinateIDs.count == n,constraints.layout.dimensions.count == n,
              constraints.minimumPosition.count == n,constraints.maximumPosition.count == n,
              constraints.layout.scales == policy.mechanics.dynamics.coordinateScales,
              constraints.layout.timeScale == policy.mechanics.dynamics.timeScale,
              policy.mechanics.constraints.diagonalMetric.count == n,drive.allSatisfy({$0.isFinite}) else { throw .unsupportedDomain }
        guard source.stamp.identity.utf8.count <= policy.maximumIdentifierBytes else { throw .capacityExceeded }
        guard let root=source.descriptor.bodies.first(where:{$0.id == source.descriptor.root}),case .spatial(let rootBody)=root,
              rootBody.mode == .static else { throw .unsupportedDomain }
        for entry in source.tree.layout.joints {
            try IslandArithmetic.charge(source.descriptor.joints.count,&work)
            guard entry.positions.count == 1,entry.velocities.count == 1,entry.positions.start == entry.velocities.start,
                  let item=source.descriptor.joints.first(where:{$0.record.id == entry.joint}),item.authority == .dynamicState,
                  item.record.parentBody == source.descriptor.root,
                  item.record.manifold.kind == .prismatic || item.record.manifold.kind == .revolute,
                  item.record.manifold.orderedAxes.count == 1,
                  let child=source.descriptor.bodies.first(where:{$0.id == item.record.childBody}),case .spatial(let body)=child,
                  body.mode == .dynamic,body.inertia != nil else { throw .unsupportedDomain }
            for anchor in [item.record.parentAnchor,item.record.childAnchor] {
                guard case .fixed=anchor.placement else { throw .unsupportedDomain }
            }
            let i=entry.velocities.start
            guard constraints.layout.dimensions[i] == (item.record.manifold.kind == .prismatic ? .length : .angle),
                  constraints.layout.scales[i].isFinite,constraints.layout.scales[i] > 0,
                  constraints.minimumPosition[i].isFinite,constraints.maximumPosition[i].isFinite,
                  constraints.minimumPosition[i] <= constraints.maximumPosition[i],
                  !constraints.layout.coordinateIDs[..<i].contains(constraints.layout.coordinateIDs[i]) else { throw .invalidInput }
        }
        _=try IslandSource.inertias(source)
        var edges=[Bool](repeating:false,count:square)
        for r in constraints.rows.indices {
            let row=constraints.rows[r]
            guard row.linear.count == n,row.hessian.count == square,row.mixedTime.count == n,
                  row.constant.isFinite,row.linear.allSatisfy({$0.isFinite}),!constraints.rows[..<r].contains(where:{$0.id == row.id}) else { throw .invalidInput }
            try IslandArithmetic.charge(try IslandArithmetic.sum(square,try IslandArithmetic.product(2,n)),&work)
            // FIXME(INCOMPLETE_IMPLEMENTATION): Time-dependent/nonlinear retained laws cannot authorize stationary omission.
            // Their original dependency and boundary-power authority must precede admission.
            guard row.timeLinear == 0,row.timeQuadratic == 0,row.hessian.allSatisfy({$0 == 0}),row.mixedTime.allSatisfy({$0 == 0}) else { throw .unsupportedDomain }
            let support=row.linear.indices.filter { row.linear[$0] != 0 }
            guard !support.isEmpty else { throw .rankAmbiguity }
            for i in support { for j in support { try IslandArithmetic.charge(1,&work);edges[i*n+j]=true } }
        }
        var seen=[Bool](repeating:false,count:n),groups:[[Int]]=[]
        for seed in 0..<n where !seen[seed] {
            var queue=[seed],cursor=0;seen[seed]=true
            while cursor < queue.count {
                let i=queue[cursor];cursor += 1
                for j in 0..<n { try IslandArithmetic.charge(1,&work);if edges[i*n+j] && !seen[j] { seen[j]=true;queue.append(j) } }
            };groups.append(queue.sorted())
        }
        return groups
    }
    @inline(never)
    private func makeIsland(_ source: CompiledMechanicalModel, constraints: QuadraticConstraintSystem, drive: [Double],
                            indices: [Int], policy: StationaryIslandPolicy, work: inout StationaryIslandWork) throws(StationaryIslandFailureReason) -> StationaryMechanicalIsland {
        let construction=try IslandConstruction(source:source,constraints:constraints,drive:drive,indices:indices,policy:policy,work:&work.numerical)
        try IslandArithmetic.charge(1,&work.numerical);try work.beginCompilation(maximum:policy.maximumCompilationCalls)
        let compiled:CompiledMechanicalModel
        do throws(CompilationFailure) { compiled=try compiler.compile(construction.descriptor,policy:source.policy) }
        catch { work.unavailable();throw .compilation(error) }
        guard compiled.descriptor == construction.descriptor,compiled.policy == source.policy,compiled.tree.layout == construction.layout else { throw .sourceMismatch }
        return StationaryMechanicalIsland(id:UInt64(indices[0]),model:compiled,indices:construction.indices,layout:construction.constraintsLayout,
            constraints:construction.constraints,drive:construction.drive,policy:construction.policy,inertias:try IslandSource.inertias(compiled))
    }
}
