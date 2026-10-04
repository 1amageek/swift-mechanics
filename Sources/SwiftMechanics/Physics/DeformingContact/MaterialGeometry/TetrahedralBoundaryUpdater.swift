public struct TetrahedralBoundaryUpdater: DeformingSurfaceUpdating {
    public init() {}
    @inline(never)
    public func extract(_ validated: ValidatedTetrahedralMesh, body: ModelReference, policy p: DeformingContactPolicy, work: inout NumericalWork) throws(DeformingContactError) -> MaterialSurface {
        let mesh=validated.mesh
        try SurfaceArithmetic.check(p)
        guard body.id.kind == .body, mesh.nodes.count <= p.maximumNodes, mesh.cells.count <= p.maximumCells else { throw .capacityExceeded }
        try SurfaceArithmetic.text(body.id.key,p,&work); try SurfaceArithmetic.text(mesh.frame.key,p,&work)
        let count=try SurfaceArithmetic.numerical { () throws(NumericalError) in try NumericalWork.product(4,mesh.cells.count) }
        let storage=try SurfaceArithmetic.numerical { () throws(NumericalError) in try NumericalWork.product(24,count) }
        try SurfaceArithmetic.numerical { () throws(NumericalError) in try work.requireStorage(storage) }
        var faces: [BoundaryTriangle]=[]; faces.reserveCapacity(count)
        let local=[[1,2,3],[0,3,2],[0,1,3],[0,2,1]]
        for cell in mesh.cells { for opposite in 0..<4 {
            try SurfaceArithmetic.charge(32,p,&work)
            faces.append(BoundaryTriangle(feature:try SurfaceFeatureID(cell:cell.identifier,oppositeNode:opposite),nodes:local[opposite].map { cell.nodes[$0] }))
        } }
        var boundary: [BoundaryTriangle]=[]; boundary.reserveCapacity(min(count,p.maximumFaces))
        for i in faces.indices {
            var matches=0
            for j in faces.indices where i != j {
                try SurfaceArithmetic.charge(32,p,&work)
                if faces[i].nodes.allSatisfy({ faces[j].nodes.contains($0) }) {
                    matches += 1
                    let a=faces[i].nodes, c=faces[j].nodes
                    guard (0..<3).contains(where: { c[$0] == a[0] && c[($0+1)%3] == a[2] && c[($0+2)%3] == a[1] }) else { throw .invalidTopology }
                }
            }
            guard matches <= 1 else { throw .invalidTopology }
            if matches == 0 { guard boundary.count < p.maximumFaces else { throw .capacityExceeded }; boundary.append(faces[i]) }
        }
        try SurfaceArithmetic.check(p)
        return MaterialSurface(body:body,mesh:validated,triangles:boundary)
    }
    @inline(never)
    public func update(_ surface: MaterialSurface, state: NodalState, geometryRevision: UInt64, time: Double,
                       previous: DeformingSurfaceSnapshot?, policy p: DeformingContactPolicy, work: inout NumericalWork) throws(DeformingContactError) -> DeformingSurfaceSnapshot {
        let mesh=surface.mesh.mesh
        try SurfaceArithmetic.check(p)
        guard mesh.nodes.count <= p.maximumNodes, mesh.cells.count <= p.maximumCells, surface.triangles.count <= p.maximumFaces else { throw .capacityExceeded }
        try SurfaceArithmetic.text(state.frame.key,p,&work); try SurfaceArithmetic.text(mesh.frame.key,p,&work); try SurfaceArithmetic.text(surface.body.id.key,p,&work)
        guard time.isFinite, time >= 0, state.frame == mesh.frame, state.meshRevision == mesh.revision,
              state.nodeIdentifiers.count == mesh.nodes.count, state.positions.count == mesh.nodes.count, state.velocities.count == mesh.nodes.count else { throw .staleMesh }
        for i in mesh.nodes.indices { try SurfaceArithmetic.charge(1,p,&work); guard state.nodeIdentifiers[i] == mesh.nodes[i].identifier else { throw .staleMesh } }
        if let previous {
            guard previous.surface.triangles.count <= p.maximumFaces, previous.state.positions.count <= p.maximumNodes,
                  previous.state.velocities.count <= p.maximumNodes else { throw .capacityExceeded }
            try SurfaceArithmetic.text(previous.surface.body.id.key,p,&work)
            guard previous.surface === surface,
                  time >= previous.timeSeconds, geometryRevision >= previous.geometryRevision else { throw .staleGeometry }
            if previous.state.positions != state.positions || previous.state.velocities != state.velocities {
                guard geometryRevision > previous.geometryRevision else { throw .staleGeometry }
            }
        }
        for cell in mesh.cells {
            try SurfaceArithmetic.charge(128,p,&work)
            let volume=try SurfaceArithmetic.core { () throws(CoreError) in try state.positions[cell.nodes[1]].subtracting(state.positions[cell.nodes[0]]).dot(state.positions[cell.nodes[2]].subtracting(state.positions[cell.nodes[0]]).cross(state.positions[cell.nodes[3]].subtracting(state.positions[cell.nodes[0]])))/6 }
            guard volume >= p.minimumVolume else { throw .invertedCell }
        }
        for face in surface.triangles {
            try SurfaceArithmetic.charge(128,p,&work)
            let area=try SurfaceArithmetic.core { () throws(CoreError) in try state.positions[face.nodes[1]].subtracting(state.positions[face.nodes[0]]).cross(state.positions[face.nodes[2]].subtracting(state.positions[face.nodes[0]])).magnitude() }
            guard area >= p.minimumDoubleArea else { throw .degenerateFace }
        }
        try SurfaceArithmetic.check(p)
        return DeformingSurfaceSnapshot(surface:surface,state:state,geometryRevision:geometryRevision,time:time)
    }
    @inline(never)
    public func point(_ material: SurfaceMaterialPoint, in snapshot: DeformingSurfaceSnapshot, policy p: DeformingContactPolicy, work: inout NumericalWork) throws(DeformingContactError) -> SurfacePointKinematics {
        try SurfaceQueryAdmission.snapshot(snapshot,policy:p,work:&work)
        guard abs(material.barycentric.reduce(0,+)-1) <= p.rotationTolerance else { throw .invalidInput }
        guard let face=snapshot.surface.triangles.first(where: { $0.feature == material.feature }) else { throw .staleMesh }
        var position=Vector3.zero,velocity=Vector3.zero
        for i in 0..<3 { try SurfaceArithmetic.charge(32,p,&work)
            position=try SurfaceArithmetic.core { () throws(CoreError) in try position.adding(snapshot.state.positions[face.nodes[i]].scaled(by:material.barycentric[i])) }
            velocity=try SurfaceArithmetic.core { () throws(CoreError) in try velocity.adding(snapshot.state.velocities[face.nodes[i]].scaled(by:material.barycentric[i])) }
        }
        try SurfaceArithmetic.check(p)
        return SurfacePointKinematics(position:position,velocity:velocity)
    }
}
