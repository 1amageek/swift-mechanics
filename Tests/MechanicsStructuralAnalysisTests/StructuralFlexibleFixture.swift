import SwiftMechanics
internal enum StructuralFlexibleFixture {
    static func work(storage: Int = 100000, operations: Int = 1000000) throws -> NumericalWork {
        NumericalWork(budget:try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:0))
    }
    static func admission(cancelled: Bool = false, maximumNodes: Int = 20) throws -> MeshAdmission {
        try MeshAdmission(maximumNodes:maximumNodes,maximumCells:20,maximumMaterials:4,minimumReferenceVolume:1e-12,inverseRelativeTolerance:1e-12,isCancelled:{cancelled})
    }
    static func material() throws -> FlexibleMaterial {
        try FlexibleMaterial(identifier:EntityID(kind:.material,key:"solid"),source:SourceProvenance(source:"measured material",revision:1),
            law:PolynomialHyperelasticity(elasticity:IsotropicElasticity(bulkModulus:1000,shearModulus:400),nonlinearModulus:800,
                domain:StrainDomain(maximumStrainNorm:2,minimumVolumeRatio:0.2)),referenceDensity:6,massDampingRate:3)
    }
    static func raw(positions: [Vector3]? = nil, indexes: [Int] = [0,1,2,3], extraNode: Bool = false) throws -> TetrahedralMesh {
        let m = try material(), p = positions ?? [.zero,.unitX,.unitY,.unitZ]
        var nodes: [FlexibleNode] = []
        for i in p.indices { nodes.append(FlexibleNode(identifier:UInt64(i+10),referencePosition:p[i],boundaryGroup:UInt64(100+i))) }
        if extraNode { nodes.append(FlexibleNode(identifier:99,referencePosition:try Vector3(2,2,2))) }
        return try TetrahedralMesh(frame:EntityID(kind:.frame,key:"reference-world"),revision:1,source:try SourceProvenance(source:"physical tetra domain",revision:1),nodes:nodes,
            cells:[try TetrahedronCell(identifier:50,nodes:indexes,material:m.identifier,source:SourceProvenance(source:"cell",revision:1))],materials:[m])
    }
    static func mesh() throws -> ValidatedTetrahedralMesh {
        var w = try work(); let service: any TetrahedralMeshValidating = TetrahedralMeshValidator()
        return try service.validate(raw(),admission:admission(),work:&w)
    }
    static func state(_ mesh: ValidatedTetrahedralMesh, f: Matrix3 = .identity, translation: Vector3 = .zero, velocity: Vector3 = .zero) throws -> NodalState {
        var positions: [Vector3] = [], ids: [UInt64] = [], velocities: [Vector3] = []
        for node in mesh.mesh.nodes { positions.append(try f.applying(to:node.referencePosition).adding(translation)); ids.append(node.identifier); velocities.append(velocity) }
        return NodalState(frame:mesh.mesh.frame,meshRevision:mesh.mesh.revision,nodeIdentifiers:ids,positions:positions,velocities:velocities)
    }
    static func response(_ mesh: ValidatedTetrahedralMesh, state: NodalState, form: FlexibleMassForm = .consistent) throws -> FlexibleAssembly {
        var w = try work(), calls = try ConstitutiveCallWork(maximumCalls:1000)
        let service: any TetrahedralAssembling = TotalLagrangianTetrahedra()
        return try service.assemble(mesh,state:state,massForm:form,constitutiveWork:&calls,work:&w)
    }
    static func close(_ a: Double, _ b: Double, tolerance: Double = 1e-8) -> Bool { abs(a-b) <= tolerance*max(1,max(abs(a),abs(b))) }
    static func action(_ matrix: [Double], _ vector: [Double]) -> [Double] {
        let n = vector.count; var result = [Double](repeating:0,count:n)
        for i in 0..<n { for j in 0..<n { result[i] += matrix[i*n+j]*vector[j] } }; return result
    }
}
