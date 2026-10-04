import SwiftMechanics
import Synchronization
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class StatefulBoundaryForceProvider: DifferentiatedForceProviding, Sendable {
    let changed = Mutex(false)
    let cancel: Bool
    init(cancel: Bool) { self.cancel=cancel }
    var metadata: ForceDerivativeMetadata {
        let changed=changed.withLock { $0 }
        return ForceDerivativeMetadata(revision:7,coordinateCount:changed && !cancel ? 2 : 1,parameterIDs:[101],
            parameterDimensions:[PhysicalDimension(length:2,mass:1,angle:-2)],availability:.analytic)
    }
    func value(_ snapshot: KinematicSnapshot, state: KinematicState, parameters: [Double], into output: inout [Double],
               work: inout NumericalWork) throws(DerivativeError) {
        do { try work.chargeOperations(2) } catch { throw .numerical(error) }
        output[0] = -parameters[0]*state.q[0]
        changed.withLock { $0=true }
    }
    func direction(_ tangent: TreeTangent, state: KinematicState, treeDirection: TreeDirection, parameters: [Double], parameterDirection: [Double],
                   into output: inout [Double], work: inout NumericalWork) throws(DerivativeError) {
        throw .callbackFailure
    }
}
