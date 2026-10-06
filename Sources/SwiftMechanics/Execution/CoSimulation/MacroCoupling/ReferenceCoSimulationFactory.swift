@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct ReferenceCoSimulationFactory: CoSimulationCreating, Sendable {
    public init() {}
    public func make(first: CoSimulationParticipantConfiguration, second: CoSimulationParticipantConfiguration,
                     coupling: CoSimulationCoupling, budget: CoSimulationBudget) throws(CoSimulationFailure) -> any CoSimulationOperating {
        guard first.identity != second.identity, first.plant.model.stamp.identity != second.plant.model.stamp.identity,
              first.plant.port.binding.actuator != second.plant.port.binding.actuator, first.clock == second.clock else { throw .refusal(.unsupportedDomain) }
        var ledger=CoSimulationWorkLedger(budget:budget)
        var a: PrismaticCoSimulationParticipant?, b: PrismaticCoSimulationParticipant?
        do throws(CoSimulationFailure) {
            try ledger.reserve(.cold,first)
            var aw=NumericalWork(budget:first.control.numerical)
            do { a=try PrismaticCoSimulationParticipant(configuration:first,work:&aw) }
            catch { try ledger.record(aw,expectedBudget:first.control.numerical); throw error }
            try ledger.record(aw,expectedBudget:first.control.numerical)
            try ledger.reserve(.cold,second)
            var bw=NumericalWork(budget:second.control.numerical)
            do { b=try PrismaticCoSimulationParticipant(configuration:second,work:&bw) }
            catch { try ledger.record(bw,expectedBudget:second.control.numerical); throw error }
            try ledger.record(bw,expectedBudget:second.control.numerical)
            guard let a, let b else { throw .refusal(.originalEvidenceRejected) }
            try ledger.reserve(.observe,first); let ao=try a.observe()
            try ledger.reserve(.observe,second); let bo=try b.observe()
            guard ao.controller.tick == 0, bo.controller.tick == 0, !ao.controller.issued, !bo.controller.issued,
                  ao.accepted.checkpoint.physical.time == bo.accepted.checkpoint.physical.time else { throw .refusal(.staleBoundary) }
            let boundary=CoSimulationBoundary(first:ao,second:bo,work:ledger,defect:0)
            return HeldPrismaticCoSimulation(first:a,second:b,coupling:coupling,boundary:boundary)
        } catch {
            _=a?.shutdown(); _=b?.shutdown()
            throw CoSimulationFailure(error.cause,recovery:error.recoveryFailures,work:ledger,unavailable:error.failedSupplierWorkUnavailable)
        }
    }
}
