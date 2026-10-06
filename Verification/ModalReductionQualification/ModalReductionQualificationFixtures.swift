import SwiftMechanics
internal enum ModalReductionQualificationFixtures {
    typealias E = ModalReductionQualificationError
    static func require(_ condition: Bool, _ label: String) throws(E) {
        guard condition else { throw .assertion(label) }
    }
    static func near(_ actual: Double, _ expected: Double, _ label: String) throws(E) {
        try require(actual.isFinite && expected.isFinite && abs(actual-expected) <= 1e-12+1e-9*max(abs(actual),abs(expected)),label)
    }
    static func near(_ actual: Vector3, _ expected: Vector3, _ label: String) throws(E) {
        try near(actual.x,expected.x,label+" x"); try near(actual.y,expected.y,label+" y"); try near(actual.z,expected.z,label+" z")
    }
    static func entries(_ a: Matrix3) -> [Double] { [a.m00,a.m01,a.m02,a.m10,a.m11,a.m12,a.m20,a.m21,a.m22] }
    static func matrix(_ a: Matrix3,_ expected: [Double],_ label: String) throws(E) {
        let values=entries(a);try require(expected.count==9,"Oracle tensor count")
        for i in 0..<9 { try near(values[i],expected[i],label) }
    }
    static func core<T>(_ body: () throws(CoreError) -> T) throws(E) -> T { do { return try body() } catch { throw .core(error) } }
    static func model<T>(_ body: () throws(ModelError) -> T) throws(E) -> T { do { return try body() } catch { throw .model(error) } }
    static func material<T>(_ body: () throws(MaterialError) -> T) throws(E) -> T { do { return try body() } catch { throw .material(error) } }
    static func flexible<T>(_ body: () throws(FlexibleError) -> T) throws(E) -> T { do { return try body() } catch { throw .flexible(error) } }
    static func structural<T>(_ body: () throws(StructuralError) -> T) throws(E) -> T { do { return try body() } catch { throw .structural(error) } }
    static func modal<T>(_ body: () throws(ModalReductionError) -> T) throws(E) -> T { do { return try body() } catch { throw .modal(error) } }
    static func field<T>(_ body: () throws(FieldOutputError) -> T) throws(E) -> T { do { return try body() } catch { throw .field(error) } }
    static func numerical<T>(_ body: () throws(NumericalError) -> T) throws(E) -> T { do { return try body() } catch { throw .numerical(error) } }
    static func vector(_ x: Double,_ y: Double,_ z: Double) throws(E) -> Vector3 {
        try core { () throws(CoreError) in try Vector3(x,y,z) }
    }
    static func work(storage: Int = 100_000, operations: Int = 10_000_000) throws(E) -> NumericalWork {
        NumericalWork(budget:try numerical { () throws(NumericalError) in
            try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:10_000) })
    }
    static func calls(_ count: Int = 1) throws(E) -> FieldConstitutiveWork {
        try field { () throws(FieldOutputError) in try FieldConstitutiveWork(maximumCalls:count) }
    }
    static func location(_ barycentric: [Double] = [0.25,0.25,0.25,0.25],cell: UInt64 = 50,revision: UInt64 = 7) throws(E) -> Tet4FieldLocation {
        try field { () throws(FieldOutputError) in try Tet4FieldLocation(meshRevision:revision,cell:cell,barycentric:barycentric) }
    }
    static func fieldPolicy(minimumVolume: Double = 1e-12, cancelled: @escaping @Sendable () -> Bool = {false}) throws(E) -> FieldOutputPolicy {
        try field { () throws(FieldOutputError) in
            try FieldOutputPolicy(maximumNodes:4,maximumCells:1,maximumMaterials:1,maximumLocations:1,
                maximumIdentifierBytes:128,maximumScalars:100_000,minimumCurrentVolume:minimumVolume,minimumVolumeRatio:0.1,
                barycentricTolerance:1e-10,deformationTolerance:1e-10,strainTolerance:1e-10,stressTolerance:1e-9,
                volumeTolerance:1e-10,forceTolerance:1e-9,momentTolerance:1e-9,powerTolerance:1e-9,energyTolerance:1e-9,isCancelled:cancelled)
        }
    }
    static func prepared(revision: UInt64 = 7, operatingShear: Double = 0, cancelled: @escaping @Sendable () -> Bool = {false}) throws(E) -> ModalReducedModel {
        let frame=try model { () throws(ModelError) in try EntityID(kind:.frame,key:"modal-frame") }
        let materialID=try model { () throws(ModelError) in try EntityID(kind:.material,key:"modal-material") }
        let provenance=try model { () throws(ModelError) in try SourceProvenance(source:"modal-mesh",revision:revision) }
        let materialSource=try model { () throws(ModelError) in try SourceProvenance(source:"modal-material-source",revision:3) }
        let cellSource=try model { () throws(ModelError) in try SourceProvenance(source:"modal-cell",revision:2) }
        let elasticity=try material { () throws(MaterialError) in try IsotropicElasticity(bulkModulus:12,shearModulus:3) }
        let domain=try material { () throws(MaterialError) in try StrainDomain(maximumStrainNorm:0.5,minimumVolumeRatio:0.2) }
        let law=try material { () throws(MaterialError) in try PolynomialHyperelasticity(elasticity:elasticity,nonlinearModulus:0,domain:domain) }
        let assigned=try flexible { () throws(FlexibleError) in try FlexibleMaterial(identifier:materialID,source:materialSource,law:law,referenceDensity:6,massDampingRate:0.25) }
        let points: [Vector3]=[.zero,.unitX,.unitY,.unitZ]
        let nodes=points.enumerated().map { FlexibleNode(identifier:UInt64(10+$0.offset),referencePosition:$0.element,boundaryGroup:UInt64(100+$0.offset)) }
        let cell=try flexible { () throws(FlexibleError) in try TetrahedronCell(identifier:50,nodes:[0,1,2,3],material:materialID,source:cellSource) }
        let raw=try flexible { () throws(FlexibleError) in try TetrahedralMesh(frame:frame,revision:revision,source:provenance,nodes:nodes,cells:[cell],materials:[assigned]) }
        let admission=try flexible { () throws(FlexibleError) in try MeshAdmission(maximumNodes:4,maximumCells:1,maximumMaterials:1,minimumReferenceVolume:1e-12,inverseRelativeTolerance:1e-12) }
        var work=try Self.work()
        let validator:any TetrahedralMeshValidating=TetrahedralMeshValidator()
        let mesh=try flexible { () throws(FlexibleError) in try validator.validate(raw,admission:admission,work:&work) }
        let structural=try Self.structural { () throws(StructuralError) in
            try StructuralPolicy(maximumCoordinates:12,maximumMetadataBytes:1024,energyScale:1,timeScale:1,
                spectralTolerance:1e-12,positiveMassThreshold:1e-12,originalResidualTolerance:1e-9,zeroEigenvalueThreshold:1e-12,isCancelled:cancelled) }
        let policy=try modal { () throws(ModalReductionError) in try ModalReductionPolicy(structural:structural,maximumPorts:0,massGramTolerance:1e-9,projectedResidualTolerance:1e-9,interfacePowerTolerance:1e-9) }
        let envelope=try modal { () throws(ModalReductionError) in
            try ModalReductionEnvelope(minimumTime:0,maximumTime:10,maximumAngularFrequency:0,
                maximumNormalizedDisplacement:10,maximumNormalizedVelocity:10,maximumFullResidual:1,maximumReferenceDisplacementError:1) }
        let maps=ModalReductionMaps(identity:"no-ports",inputDimensions:[],inputMap:[],inputCoefficientDimensions:[],interfaceDimensions:[],interfaceMap:[],interfaceCoefficientDimensions:[])
        let operatingPositions=try [Vector3.zero,Vector3.unitX,vector(operatingShear,1,0),Vector3.unitZ]
        let state=NodalState(frame:frame,meshRevision:revision,nodeIdentifiers:[10,11,12,13],positions:operatingPositions,velocities:[Vector3](repeating:.zero,count:4))
        var calls=try flexible { () throws(FlexibleError) in try ConstitutiveCallWork(maximumCalls:13) }
        let reducer:any ModalReducing=ReferenceModalReducer()
        return try modal { () throws(ModalReductionError) in
            try reducer.tetrahedra(mesh,operatingState:state,fixedCoordinates:[0,1,2,4,5,8],coordinateScale:1,
                retainedModes:[0,1,2,3,4,5],maps:maps,envelope:envelope,policy:policy,constitutiveWork:&calls,work:&work) }
    }
    static func projected(_ model: ModalReducedModel,_ full: [Double]) throws(E) -> [Double] {
        try require(full.count==12 && model.count==6 && model.pencil.count==6,"Original complete basis dimensions")
        let physical=model.pencil.binding.retainedCoordinates.map { full[$0] }
        var modal=[Double](repeating:0,count:6)
        for j in 0..<6 {
            for i in 0..<6 { for k in 0..<6 { modal[j]+=model.basis[i*6+j]*model.pencil.mass[i*6+k]*physical[k] } }
        }
        for i in 0..<6 {
            var recovered=0.0
            for j in 0..<6 { recovered+=model.basis[i*6+j]*modal[j] }
            try near(recovered,physical[i],"Independent full physical coordinate recovery")
        }
        return modal
    }
    static func state(_ model: ModalReducedModel,shear: Double = 0.2,rate: Double = 0.3) throws(E) -> ModalReducedState {
        var d=[Double](repeating:0,count:12),v=d;d[6]=shear;v[6]=rate
        let q=try projected(model,d),velocity=try projected(model,v)
        var work=try Self.work();let reducer:any ModalReducing=ReferenceModalReducer()
        return try modal { () throws(ModalReductionError) in try reducer.initialState(model,coordinates:q,velocities:velocity,time:0.5,work:&work) }
    }
    static func query(_ state: ModalReducedState,location supplied: Tet4FieldLocation? = nil,policy suppliedPolicy: FieldOutputPolicy? = nil) throws(E) -> ModalTet4StressOutput {
        let selected: Tet4FieldLocation,policy: FieldOutputPolicy
        if let supplied { selected=supplied } else { selected=try location() }
        if let suppliedPolicy { policy=suppliedPolicy } else { policy=try fieldPolicy() }
        var work=try Self.work(),calls=try Self.calls();let reducer:any ModalReducing=ReferenceModalReducer()
        return try modal { () throws(ModalReductionError) in try reducer.tetrahedralStress(state,expectedBinding:state.model.pencil.binding,location:selected,geometryRevision:4,
            fieldPolicy:policy,constitutiveWork:&calls,work:&work) }
    }
    static func expect(_ predicate: (ModalReductionError) -> Bool,_ body: () throws(ModalReductionError) -> Void) throws(E) {
        do { try body() } catch { guard predicate(error) else { throw .modal(error) };return }
        throw .assertion("Expected original typed modal refusal")
    }
}
