import CADCore
import CADIR
import SwiftMechanics

@available(macOS 15, *)
public protocol CADGearReinitializationPreparing: Sendable {
    func initialize(document: CADDocument, occurrences: [CADOccurrenceRequest],
                    tolerance: ModelingTolerance, limits: CADGeometryLimits,
                    recipe: any CADGearRuntimeRecipeBuilding, runtime: CADGearRuntimePolicy,
                    time: Double, work: inout CADAdapterWork, transmissionWork: inout NumericalWork)
        throws(CADGearReinitializationError) -> CADGearRuntimeContext
    func prepare(source: CADGearRuntimeContext, expectedSource: RuntimeCheckpoint,
                 document: CADDocument, occurrences: [CADOccurrenceRequest],
                 tolerance: ModelingTolerance, limits: CADGeometryLimits,
                 recipe: any CADGearRuntimeRecipeBuilding, choice: CADGearReinitializationChoice,
                 work: inout CADAdapterWork, transmissionWork: inout NumericalWork)
        throws(CADGearReinitializationError) -> CADPreparedGearReinitialization
}
