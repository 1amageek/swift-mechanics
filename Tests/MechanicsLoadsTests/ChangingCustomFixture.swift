import SwiftMechanics
import Synchronization
@available(macOS 15, *)
final class ChangingCustomFixture: CustomLoadProvider {
    private let value = Mutex(1)
    var identity: Int { value.withLock { $0 } }
    let coordinateKind = ScalarCoordinateKind.translation
    func response(coordinate: Double, rate: Double, state: CustomLoadState, work: inout LoadWork) throws(LoadError) -> ScalarLoadResponse {
        value.withLock { $0 += 1 }
        return try ScalarLoadResponse(conservative: 0, dissipative: 0, coordinateDerivative: 0, rateDerivative: 0, potentialEnergy: 0, dissipatedPower: 0)
    }
}
