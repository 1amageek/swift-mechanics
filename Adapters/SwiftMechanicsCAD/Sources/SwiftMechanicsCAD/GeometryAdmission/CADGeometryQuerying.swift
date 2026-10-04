import CADKernel
import SwiftMechanics

public protocol CADGeometryQuerying: Sendable {
    var identity: CADSourceIdentity { get }
    var occurrences: [CADOccurrence] { get }
    func anchors(occurrenceID: String, expected: CADSourceIdentity,
                 work: inout CADAdapterWork) throws(CADAdapterError) -> [CADAnchorReference]
    func volume(occurrenceID: String, expected: CADSourceIdentity,
                work: inout CADAdapterWork) throws(CADAdapterError) -> Double
    func surfaceAnchor(_ anchor: CADAnchorReference, nearestTo: Vector3,
                       expected: CADSourceIdentity, options: SurfaceProjectionOptions,
                       work: inout CADAdapterWork) throws(CADAdapterError) -> CADSurfaceWitness
    func edgeFrame(_ anchor: CADAnchorReference, parameter: Double,
                   expected: CADSourceIdentity,
                   work: inout CADAdapterWork) throws(CADAdapterError) -> CADEdgeWitness
    func exactMassProperties(occurrenceID: String, expected: CADSourceIdentity,
                             work: inout CADAdapterWork) throws(CADAdapterError) -> MassProperties3D
}
