public struct ToothMaterialTangent: Equatable, Sendable {
    public let directionInCollider: Vector3
    public init(directionInCollider: Vector3) throws(ToothContactError) {
        self.directionInCollider=try ToothArithmetic.core { () throws(CoreError) in try directionInCollider.normalized() }
    }
}
