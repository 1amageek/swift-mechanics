import SwiftMechanics

internal struct BaseMotionFaultSupplier: PrescribedBaseMotionSampling {
    enum Mode: Sendable { case wrongSource, resetSuccess, resetFailure, knownFailure, unavailableFailure }
    let mode: Mode
    let alternate: PrescribedBaseMotionProgram
    func sampleBase(_ program: PrescribedBaseMotionProgram, time: Double, policy: PrescribedMotionPolicy,
                    work: inout NumericalWork) throws(PrescribedMotionError) -> PrescribedBaseMotionSample {
        if case .wrongSource = mode {
            return try AnalyticPrescribedBaseMotionSampler().sampleBase(alternate, time: time, policy: policy, work: &work)
        }
        if case .knownFailure = mode {
            do throws(NumericalError) { try work.chargeOperations(7); try work.advanceIteration() }
            catch { throw .numerical(error) }
            throw .outsideDomain
        }
        if case .unavailableFailure = mode {
            do throws(NumericalError) { try work.chargeOperations(7) }
            catch { throw .numerical(error) }
            throw .supplierWorkUnavailable
        }
        let original = try AnalyticPrescribedBaseMotionSampler().sampleBase(program, time: time, policy: policy, work: &work)
        work = NumericalWork(budget: work.budget)
        if case .resetFailure = mode { throw .outsideDomain }
        return original
    }
}
