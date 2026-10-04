/// Actual descriptor inertia, retained in the admitted tree order.
internal enum NonlinearPhysicalInertias: Sendable {
    case spatial([RigidBodyInertia])
    case planar([PlanarRigidBodyInertia])
    var count: Int { switch self { case .spatial(let values): values.count; case .planar(let values): values.count } }
    var isPlanar: Bool { if case .planar = self { return true }; return false }
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    static func bind(_ model: CompiledMechanicalModel) throws(MechanismError) -> NonlinearPhysicalInertias {
        guard let first=model.tree.bodies.first else { throw .unsupportedChart }
        switch first.dimension {
        case .spatial: return .spatial(try NonlinearPhysicalEngine.bind(model))
        case .planar:
            var result: [PlanarRigidBodyInertia] = [];result.reserveCapacity(model.tree.bodies.count)
            for body in model.tree.bodies {
                guard let raw=model.descriptor.bodies.first(where:{$0.id == body.id}),case .planar(let source)=raw,let inertia=source.inertia else { throw .unsupportedChart }
                do throws(DynamicsError) { result.append(try PlanarRigidBodyInertia(body:body.id,frame:body.frame,properties:inertia.properties)) }
                catch { throw .dynamics(error) }
            }
            return .planar(result)
        }
    }
    func input(snapshot: KinematicSnapshot, velocity: [Double]) throws(DynamicsError) -> PhysicalRigidDynamicsInput {
        switch self {
        case .spatial(let values): return PhysicalRigidDynamicsInput(spatial:try RigidDynamicsInput(snapshot:snapshot,velocity:velocity,inertias:values,gravity:nil))
        case .planar(let values): return PhysicalRigidDynamicsInput(planar:try PlanarRigidDynamicsInput(snapshot:snapshot,velocity:velocity,inertias:values,gravity:nil))
        }
    }
}
