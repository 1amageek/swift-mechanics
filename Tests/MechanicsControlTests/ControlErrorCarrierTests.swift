import SwiftMechanics
import Testing

@Suite struct ControlErrorCarrierTests {
    @Test func indirectLayoutAndActualIntegrationRefusalRetainEvidence() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        #expect(MemoryLayout<ControlFailure.Cause>.size < MemoryLayout<IntegrationFailure>.size)
        #expect(MemoryLayout<ControlFailure>.size < MemoryLayout<IntegrationFailure>.size)
        let (plant,law,policy)=try ControlFixtures.plant()
        let session=try ControlFixtures.session(plant:plant,law:law,policy:policy,factory:ReferenceControlSessionFactory(integrator:ControlRefusingIntegrator()))
        defer { _=session.shutdown() }
        let prefix=try ControlFixtures.observation(session).accepted
        let error=try ControlFixtures.failure { _=try session.step(input:ControlFixtures.input(session,plant:plant)) }
        guard case .integration(let supplier)=error.cause else { Issue.record("Original integration failure was erased");return }
        #expect(supplier.cause.code == .invalidInput)
        #expect(supplier.lastAccepted == prefix)
        #expect(supplier.acceptedSteps == 0 && supplier.rejectedTrials == 0)
        #expect(supplier.work.supplierArithmeticCharged == 0 && supplier.work.derivativeCalls == 0)
        #expect(!supplier.work.failedSupplierWorkUnavailable && !error.failedSupplierWorkUnavailable)
        #expect(try ControlFixtures.observation(session).accepted == prefix)
        let retained=error
        guard case .integration(let same)=retained.cause else { Issue.record("Copied immutable error lost payload");return }
        #expect(same.lastAccepted == supplier.lastAccepted && same.work == supplier.work)
    }
    @Test func indirectRuntimeCauseKeepsTypedTruncationAndPrefix() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let (plant,law,policy)=try ControlFixtures.plant(),session=try ControlFixtures.session(plant:plant,law:law,policy:policy)
        defer { _=session.shutdown() }
        _=try session.step(input:ControlFixtures.input(session,plant:plant))
        let prefix=try ControlFixtures.observation(session).accepted
        let error=try ControlFixtures.failure { try session.restart([],codec:NativeRuntimeCheckpointCodec()) }
        guard case .runtime(let supplier)=error.cause else { Issue.record("Original runtime failure was erased");return }
        #expect(supplier.code == .truncatedCheckpoint)
        #expect(supplier.lastAccepted == prefix)
        #expect(!supplier.failedSupplierWorkUnavailable && !error.failedSupplierWorkUnavailable)
        #expect(try ControlFixtures.observation(session).accepted == prefix)
        #expect(error.phase == "restart")
        let retained=ControlFailure(.runtime(supplier),phase:error.phase,failedSupplierWorkUnavailable:error.failedSupplierWorkUnavailable)
        guard case .runtime(let same)=retained.cause else { Issue.record("Copied immutable runtime payload was erased");return }
        #expect(same.code == supplier.code && same.message == supplier.message && same.lastAccepted == supplier.lastAccepted)
    }
}
