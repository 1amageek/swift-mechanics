/// Ordered SI parameters: m, hx, hy, hz, Ioxx, Ioyy, Iozz, Ioxy, Ioxz, Ioyz.
public struct RigidInertialParameterBinding: Sendable {
    public let body: EntityID
    public let frame: EntityID
    public let modelRevision: UInt64
    public let representation: InertialRepresentation3D
    public let referencePose: RigidTransform
    public let parameterIDs: [UInt64]
    public let parameterDimensions: [PhysicalDimension]
    public let firstMoment: Vector3
    public let inertiaAtOrigin: Matrix3

    public init(body record: BodyRecord3D, modelRevision: UInt64, parameterIDs: [UInt64]) throws(InertialParameterError) {
        guard let representation = record.inertia else { throw .invalidInput }
        guard parameterIDs.count == 10 else { throw .invalidShape }
        for i in parameterIDs.indices {
            for j in 0..<i { guard parameterIDs[i] != parameterIDs[j] else { throw .invalidInput } }
        }
        let p = representation.properties
        self.firstMoment = try InertialParameterArithmetic.core { () throws(CoreError) in try p.centerOfMass.scaled(by: p.mass) }
        self.inertiaAtOrigin = try InertialParameterArithmetic.core { () throws(CoreError) in
            try p.inertiaAtCenter.adding(InertialParameterArithmetic.parallelAxis(p.centerOfMass).scaled(by: p.mass))
        }
        self.body = record.id; self.frame = record.frame; self.referencePose = record.bodyToWorld
        self.modelRevision = modelRevision; self.representation = representation; self.parameterIDs = parameterIDs
        let firstMomentDimension = PhysicalDimension(length: 1,mass: 1)
        let tensorDimension = PhysicalDimension(length: 2,mass: 1)
        self.parameterDimensions = [.mass,firstMomentDimension,firstMomentDimension,firstMomentDimension,
            tensorDimension,tensorDimension,tensorDimension,tensorDimension,tensorDimension,tensorDimension]
    }
}
