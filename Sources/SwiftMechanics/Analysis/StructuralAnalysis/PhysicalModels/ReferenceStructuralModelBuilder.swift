public struct ReferenceStructuralModelBuilder: StructuralModelBuilding, Sendable {
    public init() {}
    public func beam(_ assembly: BeamAssembly,fixedCoordinates: [Int],compressiveLoad: Double,expectedRevision: UInt64,
                     policy: StructuralPolicy,work: inout NumericalWork) throws(StructuralError) -> StructuralPencil {
        let beam=assembly.beam,n=assembly.coordinateCount
        try StructuralArithmetic.check(policy);try StructuralArithmetic.metadata(beam.identity,beam.frame.key,policy:policy)
        guard try StructuralArithmetic.sum(try StructuralArithmetic.sum(beam.identity.utf8.count,beam.frame.key.utf8.count),beam.source.source.utf8.count)<=policy.maximumMetadataBytes else { throw .capacityExceeded }
        guard beam.revision==expectedRevision else { throw .staleBinding }
        guard compressiveLoad.isFinite,compressiveLoad>=0 else { throw .invalidInput }
        let axialRigidity=try StructuralArithmetic.finite(assembly.youngModulus*beam.area)
        guard axialRigidity>0,compressiveLoad/axialRigidity<=beam.maximumLinearStrain else { throw .outsideDomain }
        let retained=try coordinates(n,fixed:fixedCoordinates,policy:policy,work:&work),nn=try StructuralArithmetic.size(retained.count,retained.count)
        try StructuralArithmetic.reserve(try StructuralArithmetic.sum(try StructuralArithmetic.size(8,try StructuralArithmetic.size(n,n)),try StructuralArithmetic.size(4,n)),&work)
        var k=[Double](repeating:0,count:nn),m=k,c=k,scales=[Double](repeating:1,count:retained.count),dims=[PhysicalDimension](repeating:.dimensionless,count:retained.count)
        for i in retained.indices {
            try StructuralArithmetic.check(policy);try StructuralArithmetic.charge(try StructuralArithmetic.size(6,retained.count),&work)
            if retained[i]%2==0 { scales[i]=beam.length;dims[i] = .length }
            for j in retained.indices {
                let original=retained[i]*n+retained[j],index=i*retained.count+j
                k[index]=try StructuralArithmetic.finite(assembly.elasticStiffness[original]-compressiveLoad*assembly.geometricStiffness[original])
                m[index]=assembly.mass[original];c[index]=assembly.damping[original]
            }
        }
        let binding=StructuralBinding(identity:beam.identity,revision:beam.revision,frame:beam.frame,source:.uniformHermiteBeam,provenance:beam.source,sourceCoordinateIDs:[],reductionBasis:[],beam:beam,equilibriumModel:nil,operatingParameter:nil,branchIdentity:nil,
            retainedCoordinates:retained,dimensions:dims,coordinateScales:scales,operatingTime:0,operatingCoordinates:[compressiveLoad])
        try StructuralArithmetic.check(policy)
        return StructuralPencil(binding:binding,mass:m,stiffness:k,damping:c)
    }
    @inline(never)
    public func flexible(_ mesh: ValidatedTetrahedralMesh,state: NodalState,fixedCoordinates: [Int],coordinateScale: Double,
                         assembler: any TetrahedralAssembling,constitutiveWork: inout ConstitutiveCallWork,
                         policy: StructuralPolicy,work: inout NumericalWork) throws(StructuralError) -> StructuralPencil {
        try StructuralArithmetic.check(policy);try StructuralArithmetic.metadata(mesh.mesh.source.source,mesh.mesh.frame.key,policy:policy)
        guard try StructuralArithmetic.sum(try StructuralArithmetic.size(2,mesh.mesh.source.source.utf8.count),mesh.mesh.frame.key.utf8.count)<=policy.maximumMetadataBytes else { throw .capacityExceeded }
        let n=try StructuralArithmetic.size(3,mesh.mesh.nodes.count)
        let retained=try coordinates(n,fixed:fixedCoordinates,policy:policy,work:&work)
        guard coordinateScale.isFinite,coordinateScale>0,state.positions.count==mesh.mesh.nodes.count,state.velocities.count==mesh.mesh.nodes.count,
            state.nodeIdentifiers.count==mesh.mesh.nodes.count,state.frame==mesh.mesh.frame,state.meshRevision==mesh.mesh.revision else { throw .staleBinding }
        let assembly: FlexibleAssembly
        do { assembly=try assembler.assemble(mesh,state:state,massForm:.consistent,constitutiveWork:&constitutiveWork,work:&work) }
        catch { throw .flexible(error) }
        guard assembly.frame==state.frame,assembly.meshRevision==state.meshRevision,assembly.nodeIdentifiers==state.nodeIdentifiers,
            assembly.coordinateCount==n,assembly.mass.count == (try StructuralArithmetic.size(n,n)),
            assembly.tangent.count == (try StructuralArithmetic.size(n,n)),assembly.damping.count == (try StructuralArithmetic.size(n,n)) else { throw .staleBinding }
        let nn=try StructuralArithmetic.size(n,n),rr=try StructuralArithmetic.size(retained.count,retained.count)
        try StructuralArithmetic.reserve(try StructuralArithmetic.sum(mesh.scalarStorage,try StructuralArithmetic.sum(try StructuralArithmetic.size(7,nn),try StructuralArithmetic.size(8,n))),&work)
        var m=[Double](repeating:0,count:rr),k=m,c=m,operating=[Double](repeating:0,count:n)
        for i in state.positions.indices { operating[3*i]=state.positions[i].x;operating[3*i+1]=state.positions[i].y;operating[3*i+2]=state.positions[i].z }
        for i in retained.indices {
            try StructuralArithmetic.check(policy);try StructuralArithmetic.charge(try StructuralArithmetic.size(3,retained.count),&work)
            for j in retained.indices { let source=retained[i]*n+retained[j],index=i*retained.count+j;m[index]=assembly.mass[source];k[index]=assembly.tangent[source];c[index]=assembly.damping[source] }
        }
        let binding=StructuralBinding(identity:mesh.mesh.source.source,revision:mesh.mesh.revision,frame:mesh.mesh.frame,source:.totalLagrangianTet4,provenance:mesh.mesh.source,sourceCoordinateIDs:state.nodeIdentifiers,reductionBasis:[],beam:nil,equilibriumModel:nil,operatingParameter:nil,branchIdentity:nil,
            retainedCoordinates:retained,dimensions:[PhysicalDimension](repeating:.length,count:retained.count),coordinateScales:[Double](repeating:coordinateScale,count:retained.count),operatingTime:0,operatingCoordinates:operating)
        try StructuralArithmetic.check(policy);return StructuralPencil(binding:binding,mass:m,stiffness:k,damping:c)
    }
    public func equilibrium(_ linearization: EquilibriumLinearization,expectedModel: ModelStamp,policy: StructuralPolicy,work: inout NumericalWork) throws(StructuralError) -> StructuralPencil {
        let point=linearization.operatingPoint,chart=point.model.chart,k=linearization.reduction.freeCoordinates
        try StructuralArithmetic.check(policy);try StructuralArithmetic.metadata(chart.stamp.identity,chart.frame.key,policy:policy)
        guard chart.stamp==expectedModel else { throw .staleBinding }
        guard k>0,k<=policy.maximumCoordinates,chart.count<=policy.maximumCoordinates else { throw .capacityExceeded }
        try StructuralArithmetic.reserve(try StructuralArithmetic.sum(try StructuralArithmetic.size(6,try StructuralArithmetic.size(chart.count,chart.count)),try StructuralArithmetic.size(4,chart.count)),&work)
        let binding=StructuralBinding(identity:chart.stamp.identity,revision:chart.stamp.revision,frame:chart.frame,source:.equilibriumReduction,provenance:nil,sourceCoordinateIDs:chart.coordinateIDs,reductionBasis:linearization.reduction.basis,beam:nil,equilibriumModel:point.model,operatingParameter:point.parameter,branchIdentity:point.branch.identity,
            retainedCoordinates:Array(0..<k),dimensions:[PhysicalDimension](repeating:.dimensionless,count:k),coordinateScales:[Double](repeating:1,count:k),operatingTime:point.time,operatingCoordinates:point.position)
        try StructuralArithmetic.check(policy)
        let pencil=StructuralPencil(binding:binding,mass:linearization.reducedMass,stiffness:linearization.reducedStiffness,damping:linearization.reducedDamping)
        try StructuralArithmetic.validate(pencil,expected:binding,policy:policy,work:&work)
        return pencil
    }
    internal func coordinates(_ n: Int,fixed: [Int],policy: StructuralPolicy,work: inout NumericalWork) throws(StructuralError) -> [Int] {
        guard n>0,n<=policy.maximumCoordinates,fixed.count<n else { throw .capacityExceeded }
        try StructuralArithmetic.reserve(try StructuralArithmetic.size(2,n),&work)
        for i in fixed.indices { try StructuralArithmetic.check(policy);try StructuralArithmetic.charge(try StructuralArithmetic.sum(1,i),&work)
            guard fixed[i]>=0,fixed[i]<n else { throw .invalidInput }
            for j in 0..<i { guard fixed[i] != fixed[j] else { throw .invalidInput } }
        }
        var retained:[Int]=[];retained.reserveCapacity(n-fixed.count)
        for i in 0..<n { try StructuralArithmetic.check(policy);try StructuralArithmetic.charge(fixed.count,&work);if !fixed.contains(i) { retained.append(i) } }
        return retained
    }
}
