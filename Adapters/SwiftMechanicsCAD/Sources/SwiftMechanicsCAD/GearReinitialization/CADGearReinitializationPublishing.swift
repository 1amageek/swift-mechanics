import SwiftMechanics

@available(macOS 15, *)
public protocol CADGearReinitializationPublishing: Sendable {
    func publish(_ prepared: CADPreparedGearReinitialization, in session: any RuntimeModelReplacing)
        throws(CADGearReinitializationError) -> RuntimeAcceptedState
}
