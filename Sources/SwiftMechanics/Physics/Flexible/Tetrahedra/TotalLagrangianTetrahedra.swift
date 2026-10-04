public struct TotalLagrangianTetrahedra: TetrahedralAssembling {
    public let isCancelled: @Sendable () -> Bool
    public init(isCancelled: @escaping @Sendable () -> Bool = { false }) { self.isCancelled = isCancelled }
    public func assemble(_ validated: ValidatedTetrahedralMesh, state: NodalState, massForm: FlexibleMassForm,
                         constitutiveWork: inout ConstitutiveCallWork, work: inout NumericalWork) throws(FlexibleError) -> FlexibleAssembly {
        guard !isCancelled() else { throw .cancelled }
        let mesh = validated.mesh, nodes = mesh.nodes.count
        guard try FlexibleArithmetic.sameIdentity(state.frame,mesh.frame,isCancelled:isCancelled,work:&work) else { throw .layoutMismatch }
        guard state.meshRevision == mesh.revision, state.nodeIdentifiers.count == nodes, state.positions.count == nodes, state.velocities.count == nodes else { throw .layoutMismatch }
        for i in 0..<nodes { try FlexibleArithmetic.charge(1,&work); guard state.nodeIdentifiers[i] == mesh.nodes[i].identifier else { throw .layoutMismatch } }
        let n = try FlexibleArithmetic.multiply(nodes,3), square = try FlexibleArithmetic.multiply(n,n)
        let storage = try FlexibleArithmetic.sum(validated.scalarStorage,FlexibleArithmetic.sum(FlexibleArithmetic.multiply(square,3),FlexibleArithmetic.multiply(n,2)))
        // Fixed-size Core matrices/vectors are stack values; no arrays inside a constitutive direction.
        try FlexibleArithmetic.storage(storage,&work)
        var force = [Double](repeating:0,count:n), tangent = [Double](repeating:0,count:square)
        var mass = [Double](repeating:0,count:square), damping = [Double](repeating:0,count:square), dampingForce = [Double](repeating:0,count:n)
        var energy = 0.0, totalMass = 0.0
        for reference in validated.referenceCells {
            guard !isCancelled() else { throw .cancelled }
            let cell = reference.cell, material = mesh.materials[reference.materialIndex]
            let edges = try FlexibleArithmetic.edges(state.positions,cell.nodes,&work)
            try FlexibleArithmetic.charge(45,&work)
            let f = try FlexibleArithmetic.core { () throws(CoreError) in try edges.multiplied(by:reference.inverseEdges) }
            let law: any HyperelasticResponding = material.law
            try constitutiveWork.charge()
            let response: FiniteStressResponse
            do { response = try law.evaluate(deformationGradient:f) } catch { throw .material(error) }
            try FlexibleArithmetic.charge(4,&work)
            energy = try FlexibleArithmetic.finite(energy+reference.volume*response.energyDensity)
            let cellMass = try FlexibleArithmetic.finite(reference.volume*material.referenceDensity)
            totalMass = try FlexibleArithmetic.finite(totalMass+cellMass)
            for i in 0..<4 {
                try FlexibleArithmetic.charge(15,&work)
                let p = try FlexibleArithmetic.core { () throws(CoreError) in try response.firstPiolaStress.applying(to:reference.gradient(i)) }
                for axis in 0..<3 {
                    let row = 3*cell.nodes[i]+axis; try FlexibleArithmetic.charge(2,&work)
                    force[row] = try FlexibleArithmetic.finite(force[row]+reference.volume*FlexibleArithmetic.component(p,axis))
                }
            }
            for j in 0..<4 { for axis in 0..<3 {
                guard !isCancelled() else { throw .cancelled }
                let g = reference.gradient(j)
                let h = try FlexibleArithmetic.core { () throws(CoreError) in try Matrix3(axis == 0 ? g.x : 0,axis == 0 ? g.y : 0,axis == 0 ? g.z : 0,
                    axis == 1 ? g.x : 0,axis == 1 ? g.y : 0,axis == 1 ? g.z : 0,axis == 2 ? g.x : 0,axis == 2 ? g.y : 0,axis == 2 ? g.z : 0) }
                try constitutiveWork.charge()
                let derivative: FiniteStressDirectionalResponse
                do { derivative = try law.tangent(deformationGradient:f,direction:h) } catch { throw .material(error) }
                for i in 0..<4 {
                    try FlexibleArithmetic.charge(15,&work)
                    // First-Piola direction includes both material and geometric prestress contributions.
                    let dp = try FlexibleArithmetic.core { () throws(CoreError) in try derivative.firstPiolaDirection.applying(to:reference.gradient(i)) }
                    for rowAxis in 0..<3 {
                        let entry = (3*cell.nodes[i]+rowAxis)*n+3*cell.nodes[j]+axis
                        try FlexibleArithmetic.charge(2,&work)
                        tangent[entry] = try FlexibleArithmetic.finite(tangent[entry]+reference.volume*FlexibleArithmetic.component(dp,rowAxis))
                    }
                }
            } }
            for i in 0..<4 { for j in 0..<4 {
                try FlexibleArithmetic.charge(2,&work)
                let m = try FlexibleArithmetic.finite(massForm == .consistent ? cellMass*(i == j ? 2 : 1)/20 : (i == j ? cellMass/4 : 0))
                try FlexibleArithmetic.charge(1,&work)
                let c = try FlexibleArithmetic.finite(material.massDampingRate*m)
                for axis in 0..<3 {
                    let entry = (3*cell.nodes[i]+axis)*n+3*cell.nodes[j]+axis
                    try FlexibleArithmetic.charge(2,&work)
                    mass[entry] = try FlexibleArithmetic.finite(mass[entry]+m)
                    damping[entry] = try FlexibleArithmetic.finite(damping[entry]+c)
                }
            } }
        }
        var power = 0.0
        for i in 0..<n {
            for j in 0..<n {
                try FlexibleArithmetic.charge(2,&work)
                dampingForce[i] = try FlexibleArithmetic.finite(dampingForce[i]+damping[i*n+j]*FlexibleArithmetic.component(state.velocities[j/3],j%3))
            }
            try FlexibleArithmetic.charge(2,&work)
            power = try FlexibleArithmetic.finite(power+dampingForce[i]*FlexibleArithmetic.component(state.velocities[i/3],i%3))
        }
        guard !Task.isCancelled, !isCancelled() else { throw .cancelled }
        return FlexibleAssembly(frame:mesh.frame,meshRevision:mesh.revision,nodeIdentifiers:state.nodeIdentifiers,coordinateCount:n,internalForce:force,tangent:tangent,mass:mass,damping:damping,dampingForce:dampingForce,storedEnergy:energy,dissipatedPower:power,totalReferenceMass:totalMass,massForm:massForm,numericalWork:work,constitutiveWork:constitutiveWork)
    }
}
