import SwiftMechanics

internal enum HexahedraQualificationFixtures {
    typealias E=HexahedraQualificationError
    static let bits=[[0,0,0],[1,0,0],[1,1,0],[0,1,0],[0,0,1],[1,0,1],[1,1,1],[0,1,1]]
    static func require(_ value: Bool,_ label: String) throws(E) { guard value else { throw .assertion(label) } }
    static func near(_ actual: Double,_ expected: Double,_ label: String,tolerance: Double = 1e-8) throws(E) {
        try require(actual.isFinite && expected.isFinite && abs(actual-expected)<=tolerance*max(1,max(abs(actual),abs(expected))),label)
    }
    static func core<T>(_ body: () throws(CoreError) -> T) throws(E) -> T { do { return try body() } catch { throw .core(error) } }
    static func model<T>(_ body: () throws(ModelError) -> T) throws(E) -> T { do { return try body() } catch { throw .model(error) } }
    static func material<T>(_ body: () throws(MaterialError) -> T) throws(E) -> T { do { return try body() } catch { throw .material(error) } }
    static func flexible<T>(_ body: () throws(FlexibleError) -> T) throws(E) -> T { do { return try body() } catch { throw .flexible(error) } }
    static func numerical<T>(_ body: () throws(NumericalError) -> T) throws(E) -> T { do { return try body() } catch { throw .numerical(error) } }
    static func hex<T>(_ body: () throws(HexahedralError) -> T) throws(E) -> T { do { return try body() } catch { throw .producer(error) } }
    static func vector(_ x: Double,_ y: Double,_ z: Double) throws(E) -> Vector3 {
        try core { () throws(CoreError) in try Vector3(x,y,z) }
    }
    static func component(_ v: Vector3,_ axis: Int) -> Double { axis==0 ? v.x : (axis==1 ? v.y : v.z) }
    static func provenance(_ name: String,_ revision: UInt64) throws(E) -> SourceProvenance {
        try model { () throws(ModelError) in try SourceProvenance(source:name,revision:revision) }
    }
    static func identity(_ kind: EntityKind,_ name: String) throws(E) -> EntityID {
        try model { () throws(ModelError) in try EntityID(kind:kind,key:name) }
    }
    static func work(storage: Int = 100_000,operations: Int = 1_000_000) throws(E) -> NumericalWork {
        let budget=try numerical { () throws(NumericalError) in try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:0) }
        return NumericalWork(budget:budget)
    }
    static func calls(_ count: Int = 400) throws(E) -> HexahedralConstitutiveWork {
        try hex { () throws(HexahedralError) in try HexahedralConstitutiveWork(maximumCalls:count) }
    }
    static func policy(nodes: Int = 16,cells: Int = 2,materials: Int = 2,floor: Double = 1e-12,margin: Double = 1e-12,
                       cancelled: @escaping @Sendable () -> Bool = {false}) throws(E) -> HexahedralAdmission {
        try hex { () throws(HexahedralError) in
            try HexahedralAdmission(maximumNodes:nodes,maximumCells:cells,maximumMaterials:materials,
                minimumReferenceDeterminant:floor,minimumCurrentDeterminant:1e-12,
                certificateRelativeMargin:margin,inverseRelativeTolerance:1e-12,isCancelled:cancelled)
        }
    }
    static func mesh(two: Bool = false,warp: Double? = nil,warpY: Double = 0,warpZ: Double = 0) throws(E) -> HexahedralMesh {
        var nodes: [FlexibleNode]=[],materials: [FlexibleMaterial]=[],cells: [HexahedronCell]=[]
        for block in 0..<(two ? 2 : 1) {
            let scale=Double(block+1),id=try identity(.material,"hex-material-\(block)")
            let origin=try provenance("hex-material-\(block)",3)
            let elasticity=try material { () throws(MaterialError) in try IsotropicElasticity(bulkModulus:12*scale,shearModulus:3*scale) }
            let domain=try material { () throws(MaterialError) in try StrainDomain(maximumStrainNorm:2,minimumVolumeRatio:0.2) }
            let law=try material { () throws(MaterialError) in try PolynomialHyperelasticity(elasticity:elasticity,nonlinearModulus:8*scale,domain:domain) }
            materials.append(try flexible { () throws(FlexibleError) in try FlexibleMaterial(identifier:id,source:origin,law:law,referenceDensity:6*scale,massDampingRate:0.25*scale) })
            for i in 0..<8 {
                let b=bits[i],x=Double(b[0])+Double(3*block)+(i==6 ? (warp ?? 0) : 0)
                let y=Double(b[1])+(i==6 ? warpY : 0),z=Double(b[2])+(i==6 ? warpZ : 0)
                nodes.append(FlexibleNode(identifier:UInt64(10+8*block+i),referencePosition:try vector(x,y,z),boundaryGroup:UInt64(100+8*block+i)))
            }
            let source=try provenance("hex-cell-\(block)",5),indices=(0..<8).map { 8*block+$0 }
            cells.append(try hex { () throws(HexahedralError) in try HexahedronCell(identifier:UInt64(50+block),nodes:indices,material:id,source:source) })
        }
        let frame=try identity(.frame,"hex-world"),source=try provenance("hex-reference",7)
        return try hex { () throws(HexahedralError) in try HexahedralMesh(identifier:71,revision:7,frame:frame,source:source,nodes:nodes,cells:cells,materials:materials) }
    }
    static func changed(_ mesh: HexahedralMesh,nodes: [FlexibleNode]? = nil,cells: [HexahedronCell]? = nil,materials: [FlexibleMaterial]? = nil) throws(E) -> HexahedralMesh {
        try hex { () throws(HexahedralError) in try HexahedralMesh(identifier:mesh.identifier,revision:mesh.revision,frame:mesh.frame,source:mesh.source,
            nodes:nodes ?? mesh.nodes,cells:cells ?? mesh.cells,materials:materials ?? mesh.materials) }
    }
    static func validate(_ mesh: HexahedralMesh,policy supplied: HexahedralAdmission? = nil) throws(E) -> ValidatedHexahedralMesh {
        let policy: HexahedralAdmission
        if let supplied { policy=supplied } else { policy=try Self.policy() }
        var work=try Self.work()
        let validator: any HexahedralMeshValidating=HexahedralMeshValidator()
        return try hex { () throws(HexahedralError) in try validator.validate(mesh,admission:policy,work:&work) }
    }
    static func state(_ mesh: HexahedralMesh,stretch: Double = 1.1,rotated: Bool = false) throws(E) -> HexahedralNodalState {
        var positions: [Vector3]=[],velocities: [Vector3]=[],ids: [UInt64]=[]
        for node in mesh.nodes {
            let x=node.referencePosition
            let a=stretch*x.x,b=x.y,c=x.z
            positions.append(try vector((rotated ? -b : a)+3,(rotated ? a : b)-2,c+4))
            let block=velocities.count/8
            velocities.append(try vector(x.x-Double(3*block),x.y,x.z));ids.append(node.identifier)
        }
        return HexahedralNodalState(revision:9,source:try provenance("hex-current",9),meshIdentifier:mesh.identifier,meshRevision:mesh.revision,
            frame:mesh.frame,meshSource:mesh.source,nodeIdentifiers:ids,positions:positions,velocities:velocities)
    }
    static func changed(_ state: HexahedralNodalState,identifier: UInt64? = nil,revision: UInt64? = nil,frame: EntityID? = nil,
                        source: SourceProvenance? = nil,ids: [UInt64]? = nil,positions: [Vector3]? = nil,velocities: [Vector3]? = nil) -> HexahedralNodalState {
        HexahedralNodalState(revision:state.revision,source:state.source,meshIdentifier:identifier ?? state.meshIdentifier,
            meshRevision:revision ?? state.meshRevision,frame:frame ?? state.frame,meshSource:source ?? state.meshSource,
            nodeIdentifiers:ids ?? state.nodeIdentifiers,positions:positions ?? state.positions,velocities:velocities ?? state.velocities)
    }
    static func assemble(_ mesh: ValidatedHexahedralMesh,_ state: HexahedralNodalState,mass: FlexibleMassForm = .consistent) throws(E) -> HexahedralAssembly {
        var work=try Self.work(),calls=try Self.calls()
        let assembler: any HexahedralAssembling=TotalLagrangianHexahedra()
        return try hex { () throws(HexahedralError) in try assembler.assemble(mesh,state:state,massForm:mass,constitutiveWork:&calls,work:&work) }
    }
    static func expect(_ wanted: HexahedralError,_ body: () throws(HexahedralError) -> Void) throws(E) {
        do { try body() } catch {
            guard error==wanted else { throw .producer(error) };return
        }
        throw .assertion("Expected exact Hex8 refusal")
    }
    static func domain(_ measure: String,limit: Double,_ body: () throws(HexahedralError) -> Void) throws(E) {
        do { try body() } catch {
            guard case .material(.outsideDomain(measure:let name,value:let value,limit:let actual))=error,
                  name==measure,actual==limit,value.isFinite,
                  (measure=="volumeRatio" ? value<limit : value>limit) else { throw .producer(error) }
            return
        }
        throw .assertion("Expected original material domain refusal")
    }
    // Separable integrals on the original physical unit cube, independent of Gauss/cache values.
    static func zeroMoment(_ i: Int,_ j: Int,_ axis: Int) -> Double { bits[i][axis]==bits[j][axis] ? 1.0/3 : 1.0/6 }
    static func firstMoment(_ i: Int,_ j: Int,_ axis: Int) -> Double { bits[i][axis]==1 && bits[j][axis]==1 ? 1.0/4 : 1.0/12 }
    static func sign(_ i: Int,_ axis: Int) -> Double { Double(2*bits[i][axis]-1) }
    static func gradientGram(_ i: Int,_ j: Int,_ a: Int,_ b: Int) -> Double {
        var value=sign(i,a)*sign(j,b)
        if a==b {
            for axis in 0..<3 where axis != a { value*=zeroMoment(i,j,axis) }
        } else {
            value*=0.25
            for axis in 0..<3 where axis != a && axis != b { value*=zeroMoment(i,j,axis) }
        }
        return value
    }
    static func elasticity(_ a: Int,_ i: Int,_ b: Int,_ j: Int) -> Double {
        let f=[1.1,1.0,1.0],s=[1.689261,1.05,1.05],fe=[0.1155,0.0,0.0]
        let geometric=(a==b && i==j) ? s[i] : 0
        let volumetric=(a==i && b==j) ? 10*f[a]*f[b] : 0
        let shear=(a==j && b==i ? f[a]*f[b] : 0)+(i==j && a==b ? f[a]*f[a] : 0)
        let nonlinear=(a==i && b==j) ? 16*fe[a]*fe[b] : 0
        return geometric+volumetric+3.0441*shear+nonlinear
    }
    static func tangent(_ node: Int,_ axis: Int,_ other: Int,_ otherAxis: Int) -> Double {
        var value=0.0
        for i in 0..<3 { for j in 0..<3 { value+=elasticity(axis,i,otherAxis,j)*gradientGram(node,other,i,j) } }
        return value
    }
    static func action(_ matrix: [Double],_ direction: [Double]) -> [Double] {
        let n=direction.count
        var output=[Double](repeating:0,count:n)
        for i in 0..<n { for j in 0..<n { output[i]+=matrix[i*n+j]*direction[j] } }
        return output
    }
    static func perturb(_ state: HexahedralNodalState,_ direction: [Double],_ amount: Double) throws(E) -> HexahedralNodalState {
        try require(direction.count==3*state.positions.count,"Original perturbation layout")
        var positions: [Vector3]=[]
        for i in state.positions.indices {
            let p=state.positions[i]
            positions.append(try vector(p.x+amount*direction[3*i],p.y+amount*direction[3*i+1],p.z+amount*direction[3*i+2]))
        }
        return changed(state,positions:positions)
    }
    static func physical(_ assembly: HexahedralAssembly,power: Double) throws(E) {
        var resultant=[Double](repeating:0,count:3),moment=resultant,nodalPower=0.0
        for i in assembly.state.positions.indices {
            let x=assembly.state.positions[i],f=Array(assembly.internalForce[(3*i)..<(3*i+3)])
            for axis in 0..<3 { resultant[axis]+=f[axis];nodalPower+=f[axis]*component(assembly.state.velocities[i],axis) }
            moment[0]+=x.y*f[2]-x.z*f[1];moment[1]+=x.z*f[0]-x.x*f[2];moment[2]+=x.x*f[1]-x.y*f[0]
        }
        for axis in 0..<3 { try near(resultant[axis],0,"Original force resultant");try near(moment[axis],0,"Original current world moment") }
        try near(nodalPower,power,"Original nodal virtual power")
    }
}
