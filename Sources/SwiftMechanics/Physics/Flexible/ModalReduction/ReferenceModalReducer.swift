public struct ReferenceModalReducer: ModalReducing, Sendable {
    public let solver: any LinearSolving<Double>
    public init(solver: any LinearSolving<Double> = ReferenceLinearSolver<Double>()) { self.solver=solver }

    public func beam(_ assembly: BeamAssembly, fixedCoordinates: [Int], compressiveLoad: Double,
                     expectedRevision: UInt64, retainedModes: [Int], maps: ModalReductionMaps,
                     envelope: ModalReductionEnvelope, policy: ModalReductionPolicy,
                     work: inout NumericalWork) throws(ModalReductionError) -> ModalReducedModel {
        try ModalReductionArithmetic.check(policy)
        let live=try preparationStorage(fullCount:assembly.coordinateCount,maps:maps,sourceStorage:64,policy:policy)
        let pencil=try ModalReductionArithmetic.structural(reservedStorage:live,work:&work) { (supplier:inout NumericalWork) throws(StructuralError) in
            try ReferenceStructuralModelBuilder().beam(assembly,fixedCoordinates:fixedCoordinates,
                compressiveLoad:compressiveLoad,expectedRevision:expectedRevision,policy:policy.structural,work:&supplier)
        }
        return try reduce(pencil,tetrahedra:nil,fullCount:assembly.coordinateCount,retained:retainedModes,
                          maps:maps,envelope:envelope,policy:policy,work:&work)
    }

    public func tetrahedra(_ mesh: ValidatedTetrahedralMesh, operatingState: NodalState, fixedCoordinates: [Int],
                           coordinateScale: Double, retainedModes: [Int], maps: ModalReductionMaps,
                           envelope: ModalReductionEnvelope, policy: ModalReductionPolicy,
                           constitutiveWork: inout ConstitutiveCallWork,
                           work: inout NumericalWork) throws(ModalReductionError) -> ModalReducedModel {
        try ModalReductionArithmetic.check(policy)
        let full=try ModalReductionArithmetic.size(3,mesh.mesh.nodes.count)
        let live=try preparationStorage(fullCount:full,maps:maps,sourceStorage:mesh.scalarStorage,policy:policy)
        let pencil=try ModalReductionArithmetic.structural(reservedStorage:live,work:&work) { (supplier:inout NumericalWork) throws(StructuralError) in
            try ReferenceStructuralModelBuilder().flexible(mesh,state:operatingState,fixedCoordinates:fixedCoordinates,
                coordinateScale:coordinateScale,assembler:TotalLagrangianTetrahedra(isCancelled:policy.structural.isCancelled),
                constitutiveWork:&constitutiveWork,policy:policy.structural,work:&supplier)
        }
        return try reduce(pencil,tetrahedra:mesh,fullCount:full,retained:retainedModes,
                          maps:maps,envelope:envelope,policy:policy,work:&work)
    }

    private func preparationStorage(fullCount: Int, maps: ModalReductionMaps, sourceStorage: Int,
                                    policy: ModalReductionPolicy) throws(ModalReductionError) -> Int {
        guard fullCount>0,fullCount<=policy.structural.maximumCoordinates,
              maps.inputDimensions.count<=policy.maximumPorts,maps.interfaceDimensions.count<=policy.maximumPorts,
              maps.identity.utf8.count<=policy.structural.maximumMetadataBytes else { throw .capacityExceeded }
        let bound=try ModalReductionArithmetic.size(fullCount,policy.maximumPorts)
        guard maps.inputMap.count<=bound,maps.interfaceMap.count<=bound,
              maps.inputCoefficientDimensions.count<=bound,maps.interfaceCoefficientDimensions.count<=bound else { throw .capacityExceeded }
        let values=try ModalReductionArithmetic.sum(maps.inputMap.count,maps.interfaceMap.count)
        let dimensions=try ModalReductionArithmetic.sum(maps.inputCoefficientDimensions.count,maps.interfaceCoefficientDimensions.count)
        let ports=try ModalReductionArithmetic.sum(maps.inputDimensions.count,maps.interfaceDimensions.count)
        let metadata=try ModalReductionArithmetic.sum(values,try ModalReductionArithmetic.size(8,try ModalReductionArithmetic.sum(dimensions,ports)))
        return try ModalReductionArithmetic.sum(sourceStorage,try ModalReductionArithmetic.sum(metadata,
            try ModalReductionArithmetic.sum(try ModalReductionArithmetic.size(4,try ModalReductionArithmetic.size(fullCount,fullCount)),
                                             try ModalReductionArithmetic.size(8,fullCount))))
    }

    private func reduce(_ pencil: StructuralPencil, tetrahedra: ValidatedTetrahedralMesh?, fullCount: Int,
                        retained: [Int], maps: ModalReductionMaps, envelope: ModalReductionEnvelope,
                        policy: ModalReductionPolicy, work: inout NumericalWork) throws(ModalReductionError) -> ModalReducedModel {
        let n=pencil.count,r=retained.count,p=maps.inputDimensions.count,h=maps.interfaceDimensions.count
        guard n>0,r>0,r<=n,fullCount<=policy.structural.maximumCoordinates,
              p<=policy.maximumPorts,h<=policy.maximumPorts,!maps.identity.isEmpty else { throw .capacityExceeded }
        let np=try ModalReductionArithmetic.size(n,p),hn=try ModalReductionArithmetic.size(h,n)
        guard maps.inputMap.count==np,maps.inputCoefficientDimensions.count==np,
              maps.interfaceMap.count==hn,maps.interfaceCoefficientDimensions.count==hn else { throw .invalidInput }
        var bytes=try ModalReductionArithmetic.sum(maps.identity.utf8.count,pencil.binding.identity.utf8.count)
        bytes=try ModalReductionArithmetic.sum(bytes,pencil.binding.frame.key.utf8.count)
        bytes=try ModalReductionArithmetic.sum(bytes,pencil.binding.provenance?.source.utf8.count ?? 0)
        if let mesh=tetrahedra {
            for material in mesh.mesh.materials {
                try ModalReductionArithmetic.check(policy);try ModalReductionArithmetic.charge(1,&work)
                bytes=try ModalReductionArithmetic.sum(bytes,try ModalReductionArithmetic.sum(material.identifier.key.utf8.count,material.source.source.utf8.count))
            }
            for cell in mesh.mesh.cells {
                try ModalReductionArithmetic.check(policy);try ModalReductionArithmetic.charge(1,&work)
                bytes=try ModalReductionArithmetic.sum(bytes,cell.source.source.utf8.count)
            }
        }
        guard bytes<=policy.structural.maximumMetadataBytes else { throw .capacityExceeded }
        let square=try ModalReductionArithmetic.size(n,n)
        let storage=try ModalReductionArithmetic.sum(tetrahedra?.scalarStorage ?? 64,
            try ModalReductionArithmetic.sum(try ModalReductionArithmetic.size(32,square),
                try ModalReductionArithmetic.sum(try ModalReductionArithmetic.size(32,fullCount),
                    try ModalReductionArithmetic.size(20,try ModalReductionArithmetic.sum(np,hn)))))
        try ModalReductionArithmetic.reserve(storage,&work)
        for i in retained.indices {
            try ModalReductionArithmetic.check(policy); try ModalReductionArithmetic.charge(i+1,&work)
            guard retained[i]>=0,retained[i]<n else { throw .invalidBasis }
            for j in 0..<i { guard retained[i] != retained[j] else { throw .invalidBasis } }
        }
        for row in 0..<n {
            try ModalReductionArithmetic.check(policy);try ModalReductionArithmetic.charge(p,&work)
            let effort=try ModalReductionArithmetic.effortDimension(pencil.binding.dimensions[row])
            for column in 0..<p {
                let index=row*p+column
                guard maps.inputMap[index].isFinite else { throw .invalidInput }
                let dimension=try ModalReductionArithmetic.core { () throws(CoreError) in
                    try maps.inputCoefficientDimensions[index].multiplied(by:maps.inputDimensions[column]) }
                guard dimension==effort else { throw .dimensionMismatch }
            }
        }
        for row in 0..<h {
            try ModalReductionArithmetic.check(policy);try ModalReductionArithmetic.charge(n,&work)
            for column in 0..<n {
                let index=row*n+column
                guard maps.interfaceMap[index].isFinite else { throw .invalidInput }
                let dimension=try ModalReductionArithmetic.core { () throws(CoreError) in
                    try maps.interfaceCoefficientDimensions[index].multiplied(by:pencil.binding.dimensions[column]) }
                guard dimension==maps.interfaceDimensions[row] else { throw .dimensionMismatch }
            }
        }
        let modes=try ModalReductionArithmetic.structural(reservedStorage:storage,work:&work) { (supplier:inout NumericalWork) throws(StructuralError) in
            try ReferenceModalAnalyzer().modes(pencil,expectedBinding:pencil.binding,policy:policy.structural,work:&supplier)
        }
        guard modes.binding==pencil.binding,modes.modes.count==square,modes.eigenvalues.count==n,
              modes.classifications.count==n else { throw .invalidBasis }
        var omitted:[Int]=[];omitted.reserveCapacity(n-r)
        for i in 0..<n {
            try ModalReductionArithmetic.check(policy);try ModalReductionArithmetic.charge(r+1,&work)
            guard modes.eigenvalues[i].isFinite else { throw .invalidBasis }
            guard modes.classifications[i] != .unstable else { throw .unstablePencil }
            if !retained.contains(i) {
                guard modes.classifications[i] == .oscillatory else { throw .invalidBasis }
                guard envelope.maximumAngularFrequency < modes.eigenvalues[i].squareRoot() else { throw .outsideEnvelope }
                omitted.append(i)
            }
        }
        let scale=try ModalReductionArithmetic.finite(policy.structural.energyScale.squareRoot()*policy.structural.timeScale)
        let scale2=try ModalReductionArithmetic.finite(scale*scale)
        guard scale>0,scale2>0 else { throw .nonFiniteResult }
        var basis=[Double](repeating:0,count:try ModalReductionArithmetic.size(n,r))
        for i in 0..<n {try ModalReductionArithmetic.check(policy);try ModalReductionArithmetic.charge(r,&work)
            for j in 0..<r { basis[i*r+j]=try ModalReductionArithmetic.finite(scale*modes.modes[i*n+retained[j]]) }
        }
        let transpose=try ModalReductionArithmetic.transpose(basis,rows:n,columns:r,policy:policy,work:&work)
        let mb=try ModalReductionArithmetic.product(pencil.mass,rows:n,inner:n,basis,columns:r,policy:policy,work:&work)
        let kb=try ModalReductionArithmetic.product(pencil.stiffness,rows:n,inner:n,basis,columns:r,policy:policy,work:&work)
        let cb=try ModalReductionArithmetic.product(pencil.damping,rows:n,inner:n,basis,columns:r,policy:policy,work:&work)
        let m=try ModalReductionArithmetic.product(transpose,rows:r,inner:n,mb,columns:r,policy:policy,work:&work)
        let k=try ModalReductionArithmetic.product(transpose,rows:r,inner:n,kb,columns:r,policy:policy,work:&work)
        let c=try ModalReductionArithmetic.product(transpose,rows:r,inner:n,cb,columns:r,policy:policy,work:&work)
        var gram=0.0,eigenResidual=0.0
        for i in 0..<r {
            try ModalReductionArithmetic.check(policy);try ModalReductionArithmetic.charge(r,&work)
            for j in 0..<r { gram=max(gram,try ModalReductionArithmetic.finite(abs(m[i*r+j]/scale2-(i==j ? 1 : 0)))) }
            for row in 0..<n {
                try ModalReductionArithmetic.charge(8,&work)
                let left=try ModalReductionArithmetic.finite(kb[row*r+i]*pencil.binding.coordinateScales[row]/policy.structural.energyScale)
                let right=try ModalReductionArithmetic.finite(modes.eigenvalues[retained[i]]*mb[row*r+i]*pencil.binding.coordinateScales[row]/policy.structural.energyScale)
                eigenResidual=max(eigenResidual,try ModalReductionArithmetic.finite(abs(left-right)/max(1,max(abs(left),abs(right)))))
            }
        }
        // A bounded entry error alone does not certify SPD for arbitrary rank; the infinity-norm bound does.
        guard try ModalReductionArithmetic.finite(Double(r)*gram)<1,gram<=policy.massGramTolerance,
              eigenResidual<=policy.structural.originalResidualTolerance else { throw .invalidBasis }
        let b=try ModalReductionArithmetic.product(transpose,rows:r,inner:n,maps.inputMap,columns:p,policy:policy,work:&work)
        let interface=try ModalReductionArithmetic.product(maps.interfaceMap,rows:h,inner:n,basis,columns:r,policy:policy,work:&work)
        try ModalReductionArithmetic.check(policy)
        return ModalReducedModel(pencil:pencil,tetrahedra:tetrahedra,maps:maps,envelope:envelope,policy:policy,
            fullCoordinateCount:fullCount,retainedModes:retained,truncatedModes:omitted,eigenvalues:modes.eigenvalues,
            basis:basis,mass:m,stiffness:k,damping:c,reducedInputMap:b,reducedInterfaceMap:interface,
            maximumMassGramError:gram,maximumRetainedEigenResidual:eigenResidual)
    }

    public func initialState(_ model: ModalReducedModel, coordinates: [Double], velocities: [Double], time: Double,
                             work: inout NumericalWork) throws(ModalReductionError) -> ModalReducedState {
        try ModalReductionArithmetic.reserve(try ModalReductionArithmetic.storage(model),&work)
        let state=ModalReducedState(model:model,time:time,coordinates:coordinates,velocities:velocities)
        _=try reconstruct(state,work:&work)
        try ModalReductionArithmetic.check(model.policy)
        return state
    }

    private func reconstruct(_ state: ModalReducedState, work: inout NumericalWork) throws(ModalReductionError) -> ([Double],[Double]) {
        let model=state.model,policy=model.policy,r=model.count,n=model.pencil.count
        try ModalReductionArithmetic.check(policy)
        guard state.time.isFinite,state.time>=model.envelope.minimumTime,state.time<=model.envelope.maximumTime,
              state.coordinates.count==r,state.velocities.count==r else { throw .outsideEnvelope }
        for i in 0..<r { try ModalReductionArithmetic.charge(2,&work)
            guard state.coordinates[i].isFinite,state.velocities[i].isFinite else { throw .invalidInput }
        }
        let q=try ModalReductionArithmetic.product(model.basis,rows:n,inner:r,state.coordinates,columns:1,policy:policy,work:&work)
        let v=try ModalReductionArithmetic.product(model.basis,rows:n,inner:r,state.velocities,columns:1,policy:policy,work:&work)
        var fullQ=[Double](repeating:0,count:model.fullCoordinateCount),fullV=fullQ
        for i in 0..<n {
            try ModalReductionArithmetic.check(policy);try ModalReductionArithmetic.charge(4,&work)
            let scale=model.pencil.binding.coordinateScales[i],coordinate=model.pencil.binding.retainedCoordinates[i]
            guard coordinate>=0,coordinate<model.fullCoordinateCount else { throw .staleBinding }
            guard try ModalReductionArithmetic.finite(abs(q[i])/scale)<=model.envelope.maximumNormalizedDisplacement,
                  try ModalReductionArithmetic.finite(abs(v[i])*policy.structural.timeScale/scale)<=model.envelope.maximumNormalizedVelocity else { throw .outsideEnvelope }
            fullQ[coordinate]=q[i];fullV[coordinate]=v[i]
        }
        try beamBounds(model,displacement:fullQ,work:&work)
        try tetrahedralBounds(model,displacement:fullQ,work:&work)
        return (fullQ,fullV)
    }

    private func tetrahedralBounds(_ model: ModalReducedModel, displacement: [Double],
                                   work: inout NumericalWork) throws(ModalReductionError) {
        guard let mesh=model.tetrahedra else { return }
        let operating=model.pencil.binding.operatingCoordinates
        guard operating.count==model.fullCoordinateCount else { throw .staleBinding }
        for reference in mesh.referenceCells {
            try ModalReductionArithmetic.check(model.policy)
            // Fixed-size coordinate, F, determinant and Green-strain/domain operations; no material evaluation occurs.
            try ModalReductionArithmetic.charge(500,&work)
            let nodes=reference.cell.nodes,origin=nodes[0]
            func edge(_ node: Int, _ axis: Int) throws(ModalReductionError) -> Double {
                let i=3*node+axis,j=3*origin+axis
                return try ModalReductionArithmetic.finite((operating[i]+displacement[i])-(operating[j]+displacement[j]))
            }
            let e00=try edge(nodes[1],0),e01=try edge(nodes[2],0),e02=try edge(nodes[3],0)
            let e10=try edge(nodes[1],1),e11=try edge(nodes[2],1),e12=try edge(nodes[3],1)
            let e20=try edge(nodes[1],2),e21=try edge(nodes[2],2),e22=try edge(nodes[3],2)
            let deformation=try ModalReductionArithmetic.core { () throws(CoreError) in
                try Matrix3(e00,e01,e02,e10,e11,e12,e20,e21,e22).multiplied(by:reference.inverseEdges)
            }
            do { _=try FiniteStrainKinematics(deformationGradient:deformation,domain:mesh.mesh.materials[reference.materialIndex].law.domain) }
            catch { throw .material(error) }
        }
    }

    private func beamBounds(_ model: ModalReducedModel, displacement: [Double], work: inout NumericalWork) throws(ModalReductionError) {
        guard let beam=model.pencil.binding.beam else { return }
        let h=try ModalReductionArithmetic.finite(beam.length/Double(beam.elements))
        let e=try ModalReductionArithmetic.finite(9/(3/beam.elasticity.shearModulus+1/beam.elasticity.bulkModulus))
        let axial=try ModalReductionArithmetic.finite(model.pencil.binding.operatingCoordinates[0]/(e*beam.area))
        for cell in 0..<beam.elements {
            try ModalReductionArithmetic.check(model.policy);try ModalReductionArithmetic.charge(20,&work)
            let d=try ModalReductionArithmetic.finite(abs(displacement[2*cell])+abs(displacement[2*cell+2]))
            let slope=try ModalReductionArithmetic.finite(abs(displacement[2*cell+1])+abs(displacement[2*cell+3]))
            let slopeBound=try ModalReductionArithmetic.finite(1.5*d/h+slope)
            let strainBound=try ModalReductionArithmetic.finite(axial+beam.maximumFiberDistance*(6*d/h+4*slope)/h)
            guard slopeBound<=beam.maximumSlope,strainBound<=beam.maximumLinearStrain else { throw .outsideEnvelope }
        }
    }

    public func step(_ state: ModalReducedState, expectedBinding: StructuralBinding, duration: Double,
                     angularFrequency: Double, inputEfforts: [Double], interfaceEfforts: [Double],
                     fullReference: ModalFullReference?, linearTolerance: LinearTolerance<Double>,
                     work: inout NumericalWork) throws(ModalReductionError) -> ModalReducedStep {
        let model=state.model,policy=model.policy,n=model.pencil.count,r=model.count
        let p=model.maps.inputDimensions.count,h=model.maps.interfaceDimensions.count
        try ModalReductionArithmetic.check(policy)
        try ModalReductionArithmetic.binding(expectedBinding,matches:model,work:&work)
        guard duration.isFinite,duration>0,angularFrequency.isFinite,angularFrequency>=0,
              angularFrequency<=model.envelope.maximumAngularFrequency,
              inputEfforts.count==p,interfaceEfforts.count==h else { throw .outsideEnvelope }
        let reserve=try ModalReductionArithmetic.storage(model)
        try ModalReductionArithmetic.reserve(reserve,&work)
        _=try reconstruct(state,work:&work)
        for value in inputEfforts {try ModalReductionArithmetic.charge(1,&work);guard value.isFinite else { throw .invalidInput }}
        for value in interfaceEfforts {try ModalReductionArithmetic.charge(1,&work);guard value.isFinite else { throw .invalidInput }}
        let time=try ModalReductionArithmetic.finite(state.time+duration)
        guard time>state.time,time<=model.envelope.maximumTime else { throw .outsideEnvelope }
        let inverse=try ModalReductionArithmetic.finite(1/duration),inverse2=try ModalReductionArithmetic.finite(inverse*inverse)
        guard inverse>0,inverse2>0 else { throw .nonFiniteResult }
        let energy=policy.structural.energyScale
        var effort=try ModalReductionArithmetic.product(model.reducedInputMap,rows:r,inner:p,inputEfforts,columns:1,policy:policy,work:&work)
        var fullEffort=try ModalReductionArithmetic.product(model.maps.inputMap,rows:n,inner:p,inputEfforts,columns:1,policy:policy,work:&work)
        for i in 0..<r { try ModalReductionArithmetic.check(policy);try ModalReductionArithmetic.charge(try ModalReductionArithmetic.size(2,h),&work)
            for j in 0..<h { effort[i]=try ModalReductionArithmetic.finite(effort[i]+model.reducedInterfaceMap[j*r+i]*interfaceEfforts[j]) }
        }
        for i in 0..<n {try ModalReductionArithmetic.check(policy);try ModalReductionArithmetic.charge(try ModalReductionArithmetic.size(2,h),&work)
            for j in 0..<h { fullEffort[i]=try ModalReductionArithmetic.finite(fullEffort[i]+model.maps.interfaceMap[j*n+i]*interfaceEfforts[j]) }
        }
        var matrix=[Double](repeating:0,count:try ModalReductionArithmetic.size(r,r)),rhs=[Double](repeating:0,count:r)
        for i in 0..<r {
            try ModalReductionArithmetic.check(policy);try ModalReductionArithmetic.charge(try ModalReductionArithmetic.size(18,r),&work)
            var value=effort[i]
            for j in 0..<r {
                let ij=i*r+j
                matrix[ij]=try ModalReductionArithmetic.finite((model.mass[ij]*inverse2+model.damping[ij]*inverse+model.stiffness[ij])/energy)
                value=try ModalReductionArithmetic.finite(value+model.mass[ij]*(state.coordinates[j]*inverse2+state.velocities[j]*inverse)+model.damping[ij]*state.coordinates[j]*inverse)
            }
            rhs[i]=try ModalReductionArithmetic.finite(value/energy)
        }
        let dense=try ModalReductionArithmetic.numerical { () throws(NumericalError) in try DenseMatrix(rows:r,columns:r,values:matrix) }
        let budget=try ModalReductionArithmetic.numerical { () throws(NumericalError) in try work.remainingBudget(reservedStorage:reserve) }
        let solved: LinearSolution<Double>
        do { solved=try solver.solve(dense,rightHandSide:rhs,
            capability:LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.partialPivotLU),tolerance:linearTolerance,budget:budget) }
        catch { throw .numerical(error,failedSupplierWorkUnavailable:true) }
        try ModalReductionArithmetic.numerical { () throws(NumericalError) in try work.absorb(solved.diagnostics.work,reservedStorage:reserve) }
        guard solved.values.count==r else { throw .invalidInput }
        var velocity=[Double](repeating:0,count:r),acceleration=velocity
        for i in 0..<r {try ModalReductionArithmetic.charge(4,&work)
            velocity[i]=try ModalReductionArithmetic.finite((solved.values[i]-state.coordinates[i])*inverse)
            acceleration[i]=try ModalReductionArithmetic.finite((velocity[i]-state.velocities[i])*inverse)
        }
        let next=ModalReducedState(model:model,time:time,coordinates:solved.values,velocities:velocity)
        let reconstructed=try reconstruct(next,work:&work)
        let q=try ModalReductionArithmetic.product(model.basis,rows:n,inner:r,solved.values,columns:1,policy:policy,work:&work)
        let v=try ModalReductionArithmetic.product(model.basis,rows:n,inner:r,velocity,columns:1,policy:policy,work:&work)
        let a=try ModalReductionArithmetic.product(model.basis,rows:n,inner:r,acceleration,columns:1,policy:policy,work:&work)
        var residual=[Double](repeating:0,count:n),fullError=0.0
        for i in 0..<n {
            try ModalReductionArithmetic.check(policy);try ModalReductionArithmetic.charge(try ModalReductionArithmetic.size(8,n),&work)
            var force=0.0
            for j in 0..<n {let ij=i*n+j
                force=try ModalReductionArithmetic.finite(force+model.pencil.mass[ij]*a[j]+model.pencil.damping[ij]*v[j]+model.pencil.stiffness[ij]*q[j])
            }
            residual[i]=try ModalReductionArithmetic.finite(force-fullEffort[i])
            let scale=model.pencil.binding.coordinateScales[i]/energy
            let denominator=max(1,max(try ModalReductionArithmetic.finite(abs(force*scale)),try ModalReductionArithmetic.finite(abs(fullEffort[i]*scale))))
            fullError=max(fullError,try ModalReductionArithmetic.finite(abs(residual[i]*scale)/denominator))
        }
        var projectedError=0.0
        for i in 0..<r {
            try ModalReductionArithmetic.check(policy);try ModalReductionArithmetic.charge(try ModalReductionArithmetic.size(4,n),&work)
            var value=0.0,reference=0.0
            for j in 0..<n {
                value=try ModalReductionArithmetic.finite(value+model.basis[j*r+i]*residual[j])
                reference=try ModalReductionArithmetic.finite(reference+model.basis[j*r+i]*fullEffort[j])
            }
            let denominator=max(1,max(try ModalReductionArithmetic.finite(abs(reference/energy)),try ModalReductionArithmetic.finite(abs((value+reference)/energy))))
            projectedError=max(projectedError,try ModalReductionArithmetic.finite(abs(value/energy)/denominator))
        }
        guard fullError<=model.envelope.maximumFullResidual,projectedError<=policy.projectedResidualTolerance else {
            throw .residualRejected(full:fullError,projected:projectedError)
        }
        let iq=try ModalReductionArithmetic.product(model.maps.interfaceMap,rows:h,inner:n,q,columns:1,policy:policy,work:&work)
        let iv=try ModalReductionArithmetic.product(model.maps.interfaceMap,rows:h,inner:n,v,columns:1,policy:policy,work:&work)
        var physicalPower=0.0,reducedPower=0.0
        for i in 0..<h {try ModalReductionArithmetic.charge(2,&work)
            physicalPower=try ModalReductionArithmetic.finite(physicalPower+interfaceEfforts[i]*iv[i])
        }
        for i in 0..<r {
            try ModalReductionArithmetic.check(policy);try ModalReductionArithmetic.charge(try ModalReductionArithmetic.sum(2,try ModalReductionArithmetic.size(2,h)),&work)
            var interfaceForce=0.0
            for j in 0..<h { interfaceForce=try ModalReductionArithmetic.finite(interfaceForce+model.reducedInterfaceMap[j*r+i]*interfaceEfforts[j]) }
            reducedPower=try ModalReductionArithmetic.finite(reducedPower+interfaceForce*velocity[i])
        }
        let powerScale=energy/policy.structural.timeScale
        guard powerScale.isFinite,powerScale>0 else { throw .nonFiniteResult }
        let powerError=try ModalReductionArithmetic.finite(abs(physicalPower-reducedPower)/max(powerScale,max(abs(physicalPower),abs(reducedPower))))
        guard powerError<=policy.interfacePowerTolerance else { throw .interfacePowerRejected(powerError) }
        var referenceError:Double?=nil
        if let supplied=fullReference {
            try ModalReductionArithmetic.binding(supplied.binding,matches:model,work:&work)
            guard supplied.time==time else { throw .staleBinding }
            let reference=supplied.displacement
            guard reference.count==model.fullCoordinateCount else { throw .invalidInput }
            var error=0.0
            for i in 0..<model.fullCoordinateCount {try ModalReductionArithmetic.charge(1,&work);guard reference[i].isFinite else { throw .invalidInput }}
            for i in 0..<n {try ModalReductionArithmetic.charge(3,&work)
                let index=model.pencil.binding.retainedCoordinates[i]
                error=max(error,try ModalReductionArithmetic.finite(abs(reconstructed.0[index]-reference[index])/model.pencil.binding.coordinateScales[i]))
            }
            // Reference fixed-coordinate motion must satisfy this model's zero-increment boundary contract.
            for i in 0..<model.fullCoordinateCount {
                try ModalReductionArithmetic.check(policy);try ModalReductionArithmetic.charge(n,&work)
                if !model.pencil.binding.retainedCoordinates.contains(i) {guard reference[i]==0 else { throw .staleBinding }}
            }
            guard error<=model.envelope.maximumReferenceDisplacementError else { throw .referenceRejected(error) }
            referenceError=error
        }
        try ModalReductionArithmetic.check(policy)
        return ModalReducedStep(state:next,displacement:reconstructed.0,velocity:reconstructed.1,
            interfaceDisplacement:iq,interfaceVelocity:iv,fullResidual:residual,
            maximumNormalizedFullResidual:fullError,maximumNormalizedProjectedResidual:projectedError,
            maximumReferenceDisplacementError:referenceError,interfacePower:physicalPower,reducedInterfacePower:reducedPower,
            normalizedInterfacePowerError:powerError,work:work)
    }

    public func beamStress(_ state: ModalReducedState, element: Int, elementCoordinate: Double, fiberDistance: Double,
                           work: inout NumericalWork) throws(ModalReductionError) -> Double {
        let model=state.model
        guard let beam=model.pencil.binding.beam else { throw .unsupportedSource }
        guard element>=0,element<beam.elements,elementCoordinate.isFinite,elementCoordinate>=0,elementCoordinate<=1,
              fiberDistance.isFinite,abs(fiberDistance)<=beam.maximumFiberDistance else { throw .invalidInput }
        try ModalReductionArithmetic.reserve(try ModalReductionArithmetic.storage(model),&work)
        let full=try reconstruct(state,work:&work).0
        try ModalReductionArithmetic.charge(30,&work)
        let h=try ModalReductionArithmetic.finite(beam.length/Double(beam.elements)),s=elementCoordinate
        let curvature=try ModalReductionArithmetic.finite(((12*s-6)*full[2*element]+(6*s-4)*h*full[2*element+1]
            + (-12*s+6)*full[2*element+2]+(6*s-2)*h*full[2*element+3])/(h*h))
        let e=try ModalReductionArithmetic.finite(9/(3/beam.elasticity.shearModulus+1/beam.elasticity.bulkModulus))
        let stress=try ModalReductionArithmetic.finite(-model.pencil.binding.operatingCoordinates[0]/beam.area-e*fiberDistance*curvature)
        try ModalReductionArithmetic.check(model.policy)
        return stress
    }

    // FIXME(INCOMPLETE_IMPLEMENTATION): The legacy ConstitutiveCallWork has no public charge operation.
    // This ModalReducing signature rejects calls until its actual material-call accounting is supplied
    // and qualified; the explicit FieldConstitutiveWork overload does not silently replace its contract.
    public func tetrahedralStress(_ state: ModalReducedState, cellIdentifier: UInt64,
                                  constitutiveWork: inout ConstitutiveCallWork,
                                  work: inout NumericalWork) throws(ModalReductionError) -> FiniteStressResponse {
        try ModalReductionArithmetic.check(state.model.policy)
        throw .unsupportedSource
    }

    public func tetrahedralStress(_ state: ModalReducedState, expectedBinding: StructuralBinding,
                                  location: Tet4FieldLocation, geometryRevision: UInt64, fieldPolicy: FieldOutputPolicy,
                                  constitutiveWork: inout FieldConstitutiveWork,
                                  work: inout NumericalWork) throws(ModalReductionError) -> ModalTet4StressOutput {
        let model = state.model
        try ModalReductionArithmetic.check(model.policy)
        guard let validated = model.tetrahedra else { throw .unsupportedSource }
        try ModalReductionArithmetic.binding(expectedBinding, matches: model, work: &work)
        let mesh = validated.mesh, nodes = mesh.nodes.count
        let full = try ModalReductionArithmetic.size(3, nodes)
        guard full == model.fullCoordinateCount,
              model.pencil.binding.operatingCoordinates.count == full,
              model.pencil.binding.sourceCoordinateIDs.count == nodes,
              model.pencil.binding.frame == mesh.frame,
              model.pencil.binding.revision == mesh.revision,
              model.pencil.binding.provenance == mesh.source else { throw .staleBinding }
        let live = try ModalReductionArithmetic.sum(try ModalReductionArithmetic.storage(model),
                                                  try ModalReductionArithmetic.size(8, nodes))
        try ModalReductionArithmetic.reserve(live, &work)
        let reconstructed = try reconstruct(state, work: &work)
        var positions: [Vector3] = [], velocities: [Vector3] = [], identifiers: [UInt64] = []
        positions.reserveCapacity(nodes); velocities.reserveCapacity(nodes); identifiers.reserveCapacity(nodes)
        for node in 0..<nodes {
            try ModalReductionArithmetic.check(model.policy)
            try ModalReductionArithmetic.charge(8, &work)
            guard model.pencil.binding.sourceCoordinateIDs[node] == mesh.nodes[node].identifier else { throw .staleBinding }
            let index = 3*node, operating = model.pencil.binding.operatingCoordinates
            let x = try ModalReductionArithmetic.finite(operating[index]+reconstructed.0[index])
            let y = try ModalReductionArithmetic.finite(operating[index+1]+reconstructed.0[index+1])
            let z = try ModalReductionArithmetic.finite(operating[index+2]+reconstructed.0[index+2])
            positions.append(try ModalReductionArithmetic.core { () throws(CoreError) in try Vector3(x,y,z) })
            velocities.append(try ModalReductionArithmetic.core { () throws(CoreError) in
                try Vector3(reconstructed.1[index],reconstructed.1[index+1],reconstructed.1[index+2]) })
            identifiers.append(mesh.nodes[node].identifier)
        }
        let nodal = NodalState(frame: mesh.frame, meshRevision: mesh.revision, nodeIdentifiers: identifiers,
                              positions: positions, velocities: velocities)
        let source = Tet4FieldSource(mesh: validated)
        let evaluator: any Tet4FieldComputing = TetrahedralFieldEvaluator()
        let budget = try ModalReductionArithmetic.numerical { () throws(NumericalError) in
            try work.remainingBudget(reservedStorage: live) }
        var supplier = NumericalWork(budget: budget)
        let sample: Tet4FieldSample
        do throws(FieldOutputError) {
            let snapshot = try evaluator.evaluate(source: source, state: nodal, timeSeconds: state.time,
                geometryRevision: geometryRevision, previous: nil, policy: fieldPolicy,
                work: &supplier, constitutiveWork: &constitutiveWork)
            sample = try evaluator.sample(snapshot, location: location, measure: .firstPiola,
                projection: .elementConstant, policy: fieldPolicy, work: &supplier)
        } catch {
            try ModalReductionArithmetic.numerical { () throws(NumericalError) in
                try work.absorb(supplier, reservedStorage: live) }
            throw .field(error)
        }
        try ModalReductionArithmetic.numerical { () throws(NumericalError) in
            try work.absorb(supplier, reservedStorage: live) }
        try ModalReductionArithmetic.check(model.policy)
        guard !Task.isCancelled, !fieldPolicy.isCancelled() else { throw .field(.cancelled) }
        return ModalTet4StressOutput(state: state, sample: sample, work: work)
    }
}
