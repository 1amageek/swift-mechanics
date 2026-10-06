import SwiftMechanics

internal enum FieldOutputsQualificationFixtures {
    typealias E=FieldOutputsQualificationError
    enum Failure {
        case invalid, location, duplicate, mixed, capacity, callLimit, cancelled
        case source, geometry, layout, frame, inverted, stress, projection
        case strainDomain, volumeDomain, supplierCalls(Int), storage(Int), operations(Int)
    }
    static func require(_ value: Bool,_ label: String) throws(E) { guard value else { throw .assertion(label) } }
    static func near(_ actual: Double,_ expected: Double,_ label: String,tolerance: Double = 1e-9) throws(E) {
        try require(actual.isFinite && expected.isFinite && abs(actual-expected) <= tolerance*max(1,max(abs(actual),abs(expected))),label)
    }
    static func near(_ actual: Vector3,_ expected: Vector3,_ label: String) throws(E) {
        try near(actual.x,expected.x,label+" x");try near(actual.y,expected.y,label+" y");try near(actual.z,expected.z,label+" z")
    }
    static func entries(_ m: Matrix3) -> [Double] { [m.m00,m.m01,m.m02,m.m10,m.m11,m.m12,m.m20,m.m21,m.m22] }
    static func near(_ actual: Matrix3,_ expected: Matrix3,_ label: String) throws(E) {
        let a=entries(actual),b=entries(expected)
        for i in 0..<9 { try near(a[i],b[i],label) }
    }
    static func core<T>(_ body: () throws(CoreError) -> T) throws(E) -> T { do { return try body() } catch { throw .core(error) } }
    static func model<T>(_ body: () throws(ModelError) -> T) throws(E) -> T { do { return try body() } catch { throw .model(error) } }
    static func material<T>(_ body: () throws(MaterialError) -> T) throws(E) -> T { do { return try body() } catch { throw .material(error) } }
    static func flexible<T>(_ body: () throws(FlexibleError) -> T) throws(E) -> T { do { return try body() } catch { throw .flexible(error) } }
    static func numerical<T>(_ body: () throws(NumericalError) -> T) throws(E) -> T { do { return try body() } catch { throw .numerical(error) } }
    static func field<T>(_ body: () throws(FieldOutputError) -> T) throws(E) -> T { do { return try body() } catch { throw .producer(error) } }
    static func vector(_ x: Double,_ y: Double,_ z: Double) throws(E) -> Vector3 { try core { () throws(CoreError) in try Vector3(x,y,z) } }
    static func matrix(_ v: [Double]) throws(E) -> Matrix3 {
        try require(v.count==9,"Fixture matrix layout")
        return try core { () throws(CoreError) in try Matrix3(v[0],v[1],v[2],v[3],v[4],v[5],v[6],v[7],v[8]) }
    }
    static func shear(_ gamma: Double = 0.2) throws(E) -> Matrix3 { try matrix([1,gamma,0,0,1,0,0,0,1]) }
    static func volumetric(_ a: Double = 1.1) throws(E) -> Matrix3 { try matrix([a,0,0,0,a,0,0,0,a]) }
    static func rate() throws(E) -> Matrix3 { try matrix([0.1,0.3,0,0,-0.05,0,0,0,0.2]) }
    static func rotation() throws(E) -> Matrix3 { try matrix([0,-1,0,1,0,0,0,0,1]) }
    static func rotate(_ x: Vector3) throws(E) -> Vector3 { try vector(-x.y,x.x,x.z) }
    static func rotateSpatial(_ m: Matrix3) throws(E) -> Matrix3 { try matrix([-m.m10,-m.m11,-m.m12,m.m00,m.m01,m.m02,m.m20,m.m21,m.m22]) }
    static func rotateBoth(_ m: Matrix3) throws(E) -> Matrix3 { try matrix([m.m11,-m.m10,-m.m12,-m.m01,m.m00,m.m02,-m.m21,m.m20,m.m22]) }
    static func apply(_ m: Matrix3,_ x: Vector3) throws(E) -> Vector3 {
        try vector(m.m00*x.x+m.m01*x.y+m.m02*x.z,m.m10*x.x+m.m11*x.y+m.m12*x.z,m.m20*x.x+m.m21*x.y+m.m22*x.z)
    }
    static func dot(_ a: Vector3,_ b: Vector3) -> Double { a.x*b.x+a.y*b.y+a.z*b.z }
    static func cross(_ a: Vector3,_ b: Vector3) throws(E) -> Vector3 { try vector(a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x) }
    static func sum(_ values: [Vector3]) throws(E) -> Vector3 {
        var x=0.0,y=0.0,z=0.0
        for v in values { x+=v.x;y+=v.y;z+=v.z }
        return try vector(x,y,z)
    }
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
    static func calls(_ count: Int = 1) throws(E) -> FieldConstitutiveWork { try field { () throws(FieldOutputError) in try FieldConstitutiveWork(maximumCalls:count) } }
    static func policy(nodes: Int = 20,cells: Int = 20,materials: Int = 4,locations: Int = 20,bytes: Int = 256,scalars: Int = 100_000,
                       minimumVolume: Double = 1e-12,minimumJ: Double = 0.1,
                       cancelled: @escaping @Sendable () -> Bool = {false}) throws(E) -> FieldOutputPolicy {
        try field { () throws(FieldOutputError) in
            try FieldOutputPolicy(maximumNodes:nodes,maximumCells:cells,maximumMaterials:materials,maximumLocations:locations,
                maximumIdentifierBytes:bytes,maximumScalars:scalars,minimumCurrentVolume:minimumVolume,minimumVolumeRatio:minimumJ,
                barycentricTolerance:1e-10,deformationTolerance:1e-10,strainTolerance:1e-10,stressTolerance:1e-9,
                volumeTolerance:1e-10,forceTolerance:1e-9,momentTolerance:1e-9,powerTolerance:1e-9,energyTolerance:1e-9,isCancelled:cancelled)
        }
    }
    static func source(mixed: Bool = false,frameName: String = "world") throws(E) -> Tet4FieldSource {
        let frame=try identity(.frame,frameName),source=try provenance("qualified-field-mesh",7)
        var materials: [FlexibleMaterial]=[]
        for index in 0..<(mixed ? 2 : 1) {
            let scale=Double(index+1),name=index==0 ? "material-a" : "material-b"
            let id=try identity(.material,name),origin=try provenance(name,3)
            let elasticity=try material { () throws(MaterialError) in try IsotropicElasticity(bulkModulus:12*scale,shearModulus:3*scale) }
            let domain=try material { () throws(MaterialError) in try StrainDomain(maximumStrainNorm:0.5,minimumVolumeRatio:0.2) }
            let law=try material { () throws(MaterialError) in try PolynomialHyperelasticity(elasticity:elasticity,nonlinearModulus:0,domain:domain) }
            materials.append(try flexible { () throws(FlexibleError) in try FlexibleMaterial(identifier:id,source:origin,law:law,referenceDensity:6,massDampingRate:0.25) })
        }
        var points: [Vector3]=[.zero,.unitX,.unitY,.unitZ]
        if mixed { points += try [vector(3,0,0),vector(5,0,0),vector(3,1,0),vector(3,0,1)] }
        var nodes: [FlexibleNode]=[],cells: [TetrahedronCell]=[]
        for i in points.indices { nodes.append(FlexibleNode(identifier:UInt64(10+i),referencePosition:points[i],boundaryGroup:UInt64(100+i))) }
        for index in materials.indices {
            let id=UInt64(50+10*index),origin=try provenance(index==0 ? "cell-a" : "cell-b",2)
            cells.append(try flexible { () throws(FlexibleError) in try TetrahedronCell(identifier:id,nodes:[4*index,4*index+1,4*index+2,4*index+3],material:materials[index].identifier,source:origin) })
        }
        let raw=try flexible { () throws(FlexibleError) in try TetrahedralMesh(frame:frame,revision:7,source:source,nodes:nodes,cells:cells,materials:materials) }
        let admission=try flexible { () throws(FlexibleError) in try MeshAdmission(maximumNodes:20,maximumCells:20,maximumMaterials:4,minimumReferenceVolume:1e-12,inverseRelativeTolerance:1e-12) }
        var work=try Self.work()
        let validator: any TetrahedralMeshValidating=TetrahedralMeshValidator()
        return Tet4FieldSource(mesh:try flexible { () throws(FlexibleError) in try validator.validate(raw,admission:admission,work:&work) })
    }
    static func state(_ source: Tet4FieldSource,f: Matrix3,rate: Matrix3? = nil,translation: Vector3? = nil,velocity: Vector3? = nil) throws(E) -> NodalState {
        let h: Matrix3,t: Vector3,v: Vector3
        if let rate { h=rate } else { h=try Self.rate() }
        if let translation { t=translation } else { t=try vector(2,-1,0.5) }
        if let velocity { v=velocity } else { v=try vector(1,-2,0.5) }
        var positions: [Vector3]=[],velocities: [Vector3]=[],ids: [UInt64]=[]
        for (i,node) in source.mesh.mesh.nodes.enumerated() {
            let second=i>=4,base=second ? try vector(3,0,0) : .zero
            let x=try vector(node.referencePosition.x-base.x,node.referencePosition.y-base.y,node.referencePosition.z-base.z)
            let selected=second ? try volumetric() : f,point=try apply(selected,x),drift=try apply(h,x)
            positions.append(try vector(base.x+point.x+t.x,base.y+point.y+t.y,base.z+point.z+t.z))
            velocities.append(try vector(drift.x+v.x,drift.y+v.y,drift.z+v.z));ids.append(node.identifier)
        }
        return NodalState(frame:source.mesh.mesh.frame,meshRevision:7,nodeIdentifiers:ids,positions:positions,velocities:velocities)
    }
    static func changed(_ state: NodalState,frame: EntityID? = nil,revision: UInt64? = nil,ids: [UInt64]? = nil,positions: [Vector3]? = nil,velocities: [Vector3]? = nil) -> NodalState {
        NodalState(frame:frame ?? state.frame,meshRevision:revision ?? state.meshRevision,nodeIdentifiers:ids ?? state.nodeIdentifiers,positions:positions ?? state.positions,velocities:velocities ?? state.velocities)
    }
    static func evaluate(_ source: Tet4FieldSource,_ state: NodalState,previous: Tet4FieldSnapshot? = nil,time: Double = 0.5,revision: UInt64 = 4,
                         policy supplied: FieldOutputPolicy? = nil) throws(E) -> Tet4FieldSnapshot {
        let policy: FieldOutputPolicy
        if let supplied { policy=supplied } else { policy=try Self.policy() }
        var work=try Self.work(),calls=try Self.calls(source.mesh.mesh.cells.count)
        let evaluator: any Tet4FieldComputing=TetrahedralFieldEvaluator()
        return try field { () throws(FieldOutputError) in try evaluator.evaluate(source:source,state:state,timeSeconds:time,geometryRevision:revision,previous:previous,policy:policy,work:&work,constitutiveWork:&calls) }
    }
    static func location(_ barycentric: [Double],cell: UInt64 = 50,revision: UInt64 = 7) throws(E) -> Tet4FieldLocation {
        try field { () throws(FieldOutputError) in try Tet4FieldLocation(meshRevision:revision,cell:cell,barycentric:barycentric) }
    }
    static func sample(_ snapshot: Tet4FieldSnapshot,_ location: Tet4FieldLocation,measure: FieldStressMeasure = .firstPiola) throws(E) -> Tet4FieldSample {
        let evaluator: any Tet4FieldComputing=TetrahedralFieldEvaluator(),policy=try Self.policy()
        var work=try Self.work()
        return try field { () throws(FieldOutputError) in try evaluator.sample(snapshot,location:location,measure:measure,projection:.elementConstant,policy:policy,work:&work) }
    }
    static func average(_ snapshot: Tet4FieldSnapshot,weighting: FieldAveragingPolicy.Weighting) throws(E) -> Tet4FieldAverage {
        let evaluator: any Tet4FieldComputing=TetrahedralFieldEvaluator(),policy=try Self.policy()
        var work=try Self.work()
        return try field { () throws(FieldOutputError) in try evaluator.average(snapshot,selectedCells:[50,60],measure:.firstPiola,projection:.elementConstant,
            averaging:FieldAveragingPolicy(weighting:weighting,materialMixing:.explicitBlend),policy:policy,work:&work) }
    }
    static func expect(_ wanted: Failure,_ body: () throws(FieldOutputError) -> Void) throws(E) {
        do { try body() } catch {
            let matches: Bool
            switch (wanted,error) {
            case (.invalid,.invalidInput),(.location,.invalidLocation),(.duplicate,.duplicateSelection),(.mixed,.mixedMaterials),(.capacity,.capacityExceeded),
                 (.callLimit,.constitutiveCallLimit),(.cancelled,.cancelled),(.source,.staleSource),(.geometry,.staleGeometry),(.layout,.staleLayout),
                 (.frame,.frameMismatch),(.inverted,.invertedCell(50)),(.stress,.unsupportedStressMeasure),(.projection,.unsupportedProjection):matches=true
            case (.strainDomain,.material(.outsideDomain(measure:"strainNorm",value:let value,limit:0.5))):matches=value>0.5 && value.isFinite
            case (.volumeDomain,.material(.outsideDomain(measure:"volumeRatio",value:let value,limit:0.2))):matches=value<0.2 && value.isFinite
            case (.supplierCalls(let expected),.flexible(.constitutiveCallLimit(limit:let actual))):matches=expected==actual
            case (.storage(let expected),.numerical(.resourceLimit(resource:.scalarStorage,limit:let actual))),
                 (.operations(let expected),.numerical(.resourceLimit(resource:.arithmeticOperations,limit:let actual))):matches=expected==actual
            default:matches=false
            }
            guard matches else { throw .producer(error) };return
        }
        throw .assertion("Expected exact typed field refusal")
    }
    static func shearP() throws(E) -> Matrix3 { try matrix([8.0/25,83.0/125,0,3.0/5,8.0/25,0,0,0,1.0/5]) }
    static func shearS() throws(E) -> Matrix3 { try matrix([0.2,0.6,0,0.6,0.32,0,0,0,0.2]) }
    static func shearE() throws(E) -> Matrix3 { try matrix([0,0.1,0,0.1,0.02,0,0,0,0]) }
    static func shearCauchy() throws(E) -> Matrix3 { try matrix([283.0/625,83.0/125,0,83.0/125,8.0/25,0,0,0,1.0/5]) }
    static func positiveForces(_ p: Matrix3) throws(E) -> [Vector3] {
        try [vector(-(p.m00+p.m01+p.m02)/6,-(p.m10+p.m11+p.m12)/6,-(p.m20+p.m21+p.m22)/6),
             vector(p.m00/6,p.m10/6,p.m20/6),vector(p.m01/6,p.m11/6,p.m21/6),vector(p.m02/6,p.m12/6,p.m22/6)]
    }
    static func physical(_ snapshot: Tet4FieldSnapshot,p: Matrix3,energy: Double,power: Double) throws(E) {
        let expected=try positiveForces(p)
        try require(snapshot.internalForces.count==4,"Original node layout")
        var moments: [Vector3]=[],nodalPower=0.0
        for i in 0..<4 {
            try near(snapshot.internalForces[i],expected[i],"Original analytic positive energy-gradient nodal force")
            let x=snapshot.state.positions[i],o=snapshot.momentReferencePosition,lever=try vector(x.x-o.x,x.y-o.y,x.z-o.z)
            moments.append(try cross(lever,snapshot.internalForces[i]));nodalPower+=dot(snapshot.internalForces[i],snapshot.state.velocities[i])
        }
        try near(sum(snapshot.internalForces),.zero,"Original resultant force");try near(sum(moments),.zero,"Original current moment")
        try near(snapshot.storedEnergy,energy,"Original reference energy J");try near(snapshot.internalPower,power,"Original P:Fdot power W");try near(nodalPower,power,"Original nodal virtual power")
        try require(snapshot.forceResidual<=1e-9 && snapshot.momentResidual<=1e-9 && snapshot.powerResidual<=1e-9,"Original physical residuals")
        try require(snapshot.constitutiveWork.calls==1 && snapshot.numericalWork.operations>0,"One actual assigned constitutive evaluate")
        try require(snapshot.momentReferencePosition==snapshot.state.positions[0],"Explicit current moment origin")
    }
}
