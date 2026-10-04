import SwiftMechanics

internal struct TrajectoryFaultSupplier: PrescribedTrajectorySampling, PrescribedBaseTrajectorySampling, PrescribedTrajectoryBoundaryQuerying {
    enum Mode: Equatable, Sendable { case wrongSource, resetSuccess, resetFailure, knownFailure, unavailableFailure }
    let mode: Mode
    let alternate: PrescribedTrajectoryProgram
    let alternateBase: PrescribedBaseTrajectoryProgram

    private func before(_ work: inout NumericalWork) throws(PrescribedMotionError) {
        if mode == .knownFailure || mode == .unavailableFailure {
            do throws(NumericalError) { try work.chargeOperations(7);if mode == .knownFailure { try work.advanceIteration() } }
            catch { throw .numerical(error) }
            if mode == .knownFailure { throw .outsideDomain };throw .supplierWorkUnavailable
        }
    }
    private func after(_ work: inout NumericalWork) throws(PrescribedMotionError) {
        if mode == .resetSuccess || mode == .resetFailure {
            work = NumericalWork(budget: work.budget)
            if mode == .resetFailure { throw .outsideDomain }
        }
    }
    func sample(_ program: PrescribedTrajectoryProgram,time: Double,policy: PrescribedTrajectoryPolicy,
                work: inout NumericalWork) throws(PrescribedMotionError) -> PrescribedMotionSample {
        try before(&work)
        let result = try AnalyticPrescribedTrajectorySampler().sample(mode == .wrongSource ? alternate : program,time: time,policy: policy,work: &work)
        try after(&work);return result
    }
    func sampleBase(_ program: PrescribedBaseTrajectoryProgram,time: Double,policy: PrescribedTrajectoryPolicy,
                    work: inout NumericalWork) throws(PrescribedMotionError) -> PrescribedBaseMotionSample {
        try before(&work)
        let result = try AnalyticPrescribedBaseTrajectorySampler().sampleBase(mode == .wrongSource ? alternateBase : program,time: time,policy: policy,work: &work)
        try after(&work);return result
    }
    func nextBoundary(_ program: PrescribedTrajectoryProgram,after time: Double,through limit: Double,
                      policy: PrescribedTrajectoryPolicy,work: inout NumericalWork) throws(PrescribedMotionError) -> Double? {
        try before(&work)
        let result = try PrescribedTrajectoryBoundaryQuery().nextBoundary(mode == .wrongSource ? alternate : program,after: time,through: limit,policy: policy,work: &work)
        try after(&work);return result
    }
    func nextBaseBoundary(_ program: PrescribedBaseTrajectoryProgram,after time: Double,through limit: Double,
                          policy: PrescribedTrajectoryPolicy,work: inout NumericalWork) throws(PrescribedMotionError) -> Double? {
        try before(&work)
        let result = try PrescribedTrajectoryBoundaryQuery().nextBaseBoundary(mode == .wrongSource ? alternateBase : program,after: time,through: limit,policy: policy,work: &work)
        try after(&work);return result
    }
}
