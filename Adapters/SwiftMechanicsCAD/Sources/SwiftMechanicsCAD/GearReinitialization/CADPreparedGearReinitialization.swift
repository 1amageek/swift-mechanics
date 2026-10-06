import SwiftMechanics

@available(macOS 15, *)
public final class CADPreparedGearReinitialization: Sendable {
    public let source: CADGearRuntimeContext
    public let target: CADGearRuntimeContext
    public let expectedSource: RuntimeCheckpoint
    public let checkpoint: RuntimeCheckpoint
    private let request: RuntimeModelReplacement
    // The private request can only be created through the actual preparation admission token.
    var replacement: RuntimeModelReplacement { request }
    init(admission: _CADGearReinitializationAdmission) {
        source = admission.source; target = admission.target
        expectedSource = admission.expectedSource; checkpoint = admission.checkpoint
        request = admission.request
    }
}
