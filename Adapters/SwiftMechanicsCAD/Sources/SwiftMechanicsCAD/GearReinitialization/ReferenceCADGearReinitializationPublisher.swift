import SwiftMechanics

@available(macOS 15, *)
public struct ReferenceCADGearReinitializationPublisher: CADGearReinitializationPublishing {
    public init() {}
    public func publish(_ prepared: CADPreparedGearReinitialization, in session: any RuntimeModelReplacing)
        throws(CADGearReinitializationError) -> RuntimeAcceptedState {
        do { return try session.replaceModel(prepared.replacement) }
        catch { throw .runtime(error) }
    }
}
