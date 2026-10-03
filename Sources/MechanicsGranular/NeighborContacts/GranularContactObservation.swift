import MechanicsCore
import MechanicsContactLaws
public struct GranularContactObservation: Sendable {
    public let bindingIndex: Int
    public let separation: Double
    public let point: Vector3
    public let response: ContactResponse
    internal init(bindingIndex: Int, separation: Double, point: Vector3, response: ContactResponse) {
        self.bindingIndex=bindingIndex; self.separation=separation; self.point=point; self.response=response
    }
}
