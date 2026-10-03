import MechanicsCore
import MechanicsModel
import MechanicsNumerics
import MechanicsFlexible
internal enum PatchArithmetic {
    static func check(_ p: PatchPolicy) throws(PatchError) { guard !Task.isCancelled, !p.isCancelled() else { throw .cancelled } }
    static func charge(_ n: Int,_ w: inout NumericalWork) throws(PatchError) { guard !Task.isCancelled else { throw .cancelled }; do { try w.chargeOperations(n) } catch { throw .numerical(error) } }
    static func product(_ a: Int,_ b: Int) throws(PatchError) -> Int { do { return try NumericalWork.product(a,b) } catch { throw .numerical(error) } }
    static func sum(_ a: Int,_ b: Int) throws(PatchError) -> Int { do { return try NumericalWork.sum(a,b) } catch { throw .numerical(error) } }
    static func storage(_ n: Int,_ w: inout NumericalWork) throws(PatchError) { do { try w.requireStorage(n) } catch { throw .numerical(error) } }
    static func finite(_ x: Double) throws(PatchError) -> Double { guard x.isFinite else { throw .nonFiniteResult }; return x }
    static func core<T>(_ f: () throws(CoreError) -> T,_ w: inout NumericalWork) throws(PatchError) -> T { try charge(1,&w); do { return try f() } catch { throw .core(error) } }
    static func add(_ a: Vector3,_ b: Vector3,_ w: inout NumericalWork) throws(PatchError) -> Vector3 { try core({ () throws(CoreError) in try a.adding(b)},&w) }
    static func sub(_ a: Vector3,_ b: Vector3,_ w: inout NumericalWork) throws(PatchError) -> Vector3 { try core({ () throws(CoreError) in try a.subtracting(b)},&w) }
    static func scale(_ a: Vector3,_ s: Double,_ w: inout NumericalWork) throws(PatchError) -> Vector3 { try core({ () throws(CoreError) in try a.scaled(by:s)},&w) }
    static func dot(_ a: Vector3,_ b: Vector3,_ w: inout NumericalWork) throws(PatchError) -> Double { try core({ () throws(CoreError) in try a.dot(b)},&w) }
    static func cross(_ a: Vector3,_ b: Vector3,_ w: inout NumericalWork) throws(PatchError) -> Vector3 { try core({ () throws(CoreError) in try a.cross(b)},&w) }
    static func norm(_ a: Vector3,_ w: inout NumericalWork) throws(PatchError) -> Double { try core({ () throws(CoreError) in try a.magnitude()},&w) }
    static func bytes(_ key: String,_ p: PatchPolicy,_ w: inout NumericalWork) throws(PatchError) { var i=key.utf8.makeIterator(); while true { try check(p); try charge(2,&w); if i.next() == nil { break } } }
    static func same(_ a: EntityID,_ b: EntityID,_ p: PatchPolicy,_ w: inout NumericalWork) throws(PatchError) -> Bool { try bytes(a.key,p,&w); try bytes(b.key,p,&w); try charge(1,&w); return a == b }
    @inline(never)
    static func admit(_ body: PressureBody,_ plane: RigidPressurePlane,_ p: PatchPolicy,_ w: inout NumericalWork) throws(PatchError) -> NodalPressureField {
        try check(p)
        let mesh=body.mesh.mesh, state=body.state, n=mesh.nodes.count
        guard n <= p.maximumNodes, mesh.cells.count <= p.maximumCells else { throw .capacityExceeded }
        guard body.body.id.kind == .body, plane.body.id.kind == .body, plane.frame.id.kind == .frame else { throw .invalidInput }
        guard !(try same(body.body.id,plane.body.id,p,&w)) else { throw .invalidInput }
        guard body.body.revision == p.expectedModelRevision, plane.body.revision == p.expectedModelRevision, plane.frame.revision == p.expectedModelRevision,
            mesh.revision == p.expectedMeshRevision, state.meshRevision == mesh.revision, plane.revision == p.expectedPlaneRevision else { throw .staleRepresentation }
        guard let field=body.field else { throw .missingPressureField }
        guard field.meshRevision == mesh.revision, field.revision == p.expectedPressureRevision else { throw .staleRepresentation }
        guard try same(mesh.frame,state.frame,p,&w), try same(mesh.frame,field.frame,p,&w), try same(mesh.frame,plane.frame.id,p,&w) else { throw .frameMismatch }
        guard state.nodeIdentifiers.count == n, state.positions.count == n, state.velocities.count == n, field.nodeIdentifiers.count == n, field.pressurePascals.count == n,
            field.materialIdentifiers.count == mesh.materials.count else { throw .invalidLayout }
        try bytes(field.source.source,p,&w); try bytes(mesh.source.source,p,&w); try charge(1,&w)
        guard field.source == mesh.source else { throw .staleRepresentation }
        for i in mesh.materials.indices { try check(p); guard try same(field.materialIdentifiers[i],mesh.materials[i].identifier,p,&w) else { throw .incompatibleMaterial } }
        for i in 0..<n {
            try check(p); try charge(4,&w)
            guard state.nodeIdentifiers[i] == mesh.nodes[i].identifier, field.nodeIdentifiers[i] == mesh.nodes[i].identifier else { throw .invalidLayout }
            guard field.pressurePascals[i].isFinite, field.pressurePascals[i] >= 0, field.pressurePascals[i] <= p.maximumPressure else { throw .invalidInput }
        }
        guard abs(try norm(plane.normal,&w)-1) <= p.normalTolerance else { throw .invalidInput }
        return field
    }
}
