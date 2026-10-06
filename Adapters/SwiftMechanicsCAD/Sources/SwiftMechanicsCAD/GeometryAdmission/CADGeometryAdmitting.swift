import CADCore
import CADIR

public protocol CADGeometryAdmitting: Sendable {
    func admit(document: CADDocument, occurrences: [CADOccurrenceRequest],
               tolerance: ModelingTolerance, limits: CADGeometryLimits,
               work: inout CADAdapterWork) throws(CADAdapterError) -> CADGeometryAdmission
}
