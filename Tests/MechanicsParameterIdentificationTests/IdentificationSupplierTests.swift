import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct IdentificationSupplierTests {
    @Test func differentInternallyCertifiedObjectiveCannotPublishPhysicalEstimate() throws {
        let p=try IdentificationFixtures.problem()
        let f=try IdentificationFixtures.failure { try IdentificationFixtures.estimate(p,service:PhysicalMassDamperIdentifier(optimizer:IdentificationFaultOptimizer(mode:.differentObjective))) }
        guard case .originalEvidenceRejected=f.cause else { Issue.record("Expected independent original rejection");return }
        #expect(f.phase == .originalAcceptance && f.lastOriginalResidual != nil && f.work.operations > 0)
    }
    @Test func optimizerNumericalLedgerResetIsUnavailableAndRefused() throws {
        let p=try IdentificationFixtures.problem()
        let f=try IdentificationFixtures.failure { try IdentificationFixtures.estimate(p,service:PhysicalMassDamperIdentifier(optimizer:IdentificationFaultOptimizer(mode:.resetLedger))) }
        guard case .invalidSupplierLedger=f.cause else { Issue.record("Expected optimizer ledger refusal");return }
        #expect(f.phase == .optimization && f.failedSupplierWorkUnavailable && f.work.operations > 0)
    }
    @Test func derivativeResetNumericalOrCallLedgerPreservesKnownPrefix() throws {
        let p=try IdentificationFixtures.problem()
        for mode in [IdentificationFaultDerivative.Mode.resetNumerical,.resetCalls] {
            let f=try IdentificationFixtures.failure { try IdentificationFixtures.estimate(p,service:PhysicalMassDamperIdentifier(derivatives:IdentificationFaultDerivative(mode:mode))) }
            guard case .invalidSupplierLedger=f.cause else { Issue.record("Expected derivative ledger refusal");continue }
            #expect(f.phase == .physicalDesign && f.failedSupplierWorkUnavailable && f.work.operations > 0 && f.supplierWork.calls >= 1)
        }
    }
    @Test func actualDerivativeRefusalKeepsUnderlyingCauseAndAttempt() throws {
        let p=try IdentificationFixtures.problem()
        let f=try IdentificationFixtures.failure { try IdentificationFixtures.estimate(p,service:PhysicalMassDamperIdentifier(derivatives:IdentificationFaultDerivative(mode:.refuse))) }
        guard case .derivative(.derivativeUnavailable)=f.cause else { Issue.record("Expected exact derivative refusal");return }
        #expect(f.phase == .physicalDesign && f.supplierWork.calls == 1 && !f.failedSupplierWorkUnavailable)
    }
    @Test func loadResetRetainsPrimedAttemptAndUnavailableConsumption() throws {
        let p=try IdentificationFixtures.problem()
        let f=try IdentificationFixtures.failure { try IdentificationFixtures.estimate(p,service:PhysicalMassDamperIdentifier(loads:IdentificationFaultLoad(mode:.resetLedger))) }
        guard case .invalidSupplierLedger=f.cause else { Issue.record("Expected load ledger refusal");return }
        #expect(f.phase == .physicalDesign && f.failedSupplierWorkUnavailable && f.loadWork.consumed == 1 && f.supplierWork.calls == 0)
    }
    @Test func forceCorrectButWrongPassivePowerIsRefused() throws {
        let p=try IdentificationFixtures.problem()
        let f=try IdentificationFixtures.failure { try IdentificationFixtures.estimate(p,service:PhysicalMassDamperIdentifier(loads:IdentificationFaultLoad(mode:.wrongPower))) }
        guard case .invalidSupplierOutput=f.cause else { Issue.record("Expected original passive power refusal");return }
        #expect(f.phase == .physicalDesign && f.loadWork.consumed == 2 && !f.failedSupplierWorkUnavailable)
    }
    @Test func opaqueInformationSupplierRefusalStopsAfterOneActualCall() throws {
        guard #available(macOS 15,iOS 18,tvOS 18,watchOS 11,*) else { return }
        let supplier=IdentificationRefusingLinearSolver(),p=try IdentificationFixtures.problem()
        let f=try IdentificationFixtures.failure { try IdentificationFixtures.estimate(p,service:PhysicalMassDamperIdentifier(informationSolver:supplier)) }
        guard case .numerical(.unsupportedCapability)=f.cause else { Issue.record("Expected actual linear supplier refusal");return }
        #expect(supplier.calls == 1 && f.phase == .information && f.failedSupplierWorkUnavailable)
        #expect(f.modelValidationAttempts == 4 && f.lastOriginalResidual != nil && f.lastObjective != nil && f.work.operations > 0)
    }
}
