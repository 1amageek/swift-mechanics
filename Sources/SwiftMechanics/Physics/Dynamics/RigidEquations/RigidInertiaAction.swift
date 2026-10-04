/// Exact inertia action on the admitted rotational tangent; planar values are not 3D tensors.
internal enum RigidInertiaAction: Sendable {
    case spatial(Matrix3)
    case planar(Double)
    func applied(to angular:Vector3,work:inout NumericalWork) throws(DynamicsError) -> Vector3 {
        switch self {
        case .spatial(let tensor): return try DynamicsArithmetic.apply(tensor,angular,&work)
        case .planar(let polar):
            guard angular.x == 0,angular.y == 0 else { throw .nonplanarInput }
            try DynamicsArithmetic.operations(1,&work)
            return try DynamicsArithmetic.core { () throws(CoreError) in try Vector3(0,0,polar*angular.z) }
        }
    }
}
