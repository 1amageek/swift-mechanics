import SwiftMechanics
import Testing

struct HydraulicFixture {
    static func work(scalars: Int = 32, operations: Int = 4096, cancelled: Bool = false) throws -> ActuationWork {
        ActuationWork(budget: try ActuationBudget(maximumWork: operations, maximumScalars: scalars,
            maximumBytes: 0, maximumBindings: 0, maximumMetadataBytes: 128, isCancelled: { cancelled }))
    }
    static func near(_ a: Double, _ b: Double, absolute: Double = 1e-10, relative: Double = 1e-10) -> Bool {
        abs(a-b) <= absolute + relative * max(abs(a), abs(b))
    }
    static func balanced(_ r: HydraulicElementResponse) {
        #expect(near(r.fluidPower, r.storagePower + r.dissipatedPower))
        #expect(near(r.balanceResidual, 0))
        #expect(r.storedEnergy >= 0 && r.dissipatedPower >= 0)
    }
    static func cylinder(leakage: Double = 1e-5) throws -> DoubleActingHydraulicCylinder {
        try DoubleActingHydraulicCylinder(firstArea: 0.01, secondArea: 0.006,
            firstReferenceVolume: 0.1, secondReferenceVolume: 0.08,
            firstBulkModulus: 1000, secondBulkModulus: 800, leakageConductance: leakage,
            maximumPressure: 200, maximumFlow: 1, maximumStroke: 5, maximumRelativeVolumeChange: 0.1)
    }
    static func cylinderSample(_ law: any HydraulicCylinderEvaluating, stroke: Double = 0.1,
                               velocity: Double = 0.2, p1: Double = 100, p2: Double = 40,
                               q1: Double = 0.003, q2: Double = -0.001,
                               work: inout ActuationWork) throws -> HydraulicCylinderResponse {
        try law.evaluate(stroke: stroke, velocity: velocity, firstPressure: p1, secondPressure: p2,
            firstFlow: q1, secondFlow: q2, work: &work)
    }
}
