import CADIR
import SwiftMechanics

/// Original CAD dimensions are SI, independent of the document display units.
public struct CADInvoluteGearWitness: Sendable {
    public let source: CADSourceIdentity
    public let occurrence: CADOccurrence
    public let toothCount: Int
    public let dimensions: [InvoluteGearFeature.Dimension: Double]
    public let doubleHelical: Bool
    public let maximumSegments: Int
    public let localOrigin: Vector3
    public let worldOrigin: Vector3
    public let worldAxis: Vector3
    public let worldToothZero: Vector3

    init(admission: _CADInvoluteGearAdmission) {
        source = admission.source; occurrence = admission.occurrence
        toothCount = admission.feature.toothCount; dimensions = admission.dimensions
        doubleHelical = admission.feature.doubleHelical; maximumSegments = admission.feature.maximumSegments
        localOrigin = admission.localOrigin; worldOrigin = admission.worldOrigin
        worldAxis = admission.worldAxis; worldToothZero = admission.worldToothZero
    }
}
