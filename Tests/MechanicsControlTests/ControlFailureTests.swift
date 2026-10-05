import SwiftMechanics
import Testing

@Suite struct ControlFailureTests {
    @Test func unitsTimeTickModeAndForeignSampleRefused() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let (p,l,c)=try ControlFixtures.plant(),s=try ControlFixtures.session(plant:p,law:l,policy:c)
        defer { _=s.shutdown() }
        let before=try s.checkpoint(codec:NativeRuntimeCheckpointCodec())
        for input in [try ControlFixtures.input(s,plant:p,dimension:.mass),try ControlFixtures.input(s,plant:p,timeOffset:0.01),try ControlFixtures.input(s,plant:p,tickOffset:1),try ControlFixtures.input(s,plant:p,mode:.velocity)] {
            _=try ControlFixtures.failure { _=try s.step(input:input) };#expect(try s.checkpoint(codec:NativeRuntimeCheckpointCodec()) == before)
        }
        let (other,ol,oc)=try ControlFixtures.plant(model:ControlFixtures.model(v:1)),os=try ControlFixtures.session(plant:other,law:ol,policy:oc)
        defer { _=os.shutdown() }
        _=try ControlFixtures.failure { _=try s.step(input:ControlFixtures.input(os,plant:other)) }
        #expect(try s.checkpoint(codec:NativeRuntimeCheckpointCodec()) == before)
    }
    @Test func endpointEnvelopeRollsBack() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let (p,l,c)=try ControlFixtures.plant(speed:0.1),s=try ControlFixtures.session(plant:p,law:l,policy:c)
        defer { _=s.shutdown() }
        let before=try s.checkpoint(codec:NativeRuntimeCheckpointCodec()),error=try ControlFixtures.failure { _=try s.step(input:ControlFixtures.input(s,plant:p)) }
        if case .originalEvidenceRejected=error.cause {} else { Issue.record("Expected physical endpoint envelope refusal") }
        #expect(try s.checkpoint(codec:NativeRuntimeCheckpointCodec()) == before)
    }
    @Test func boundedFeedthroughGraphRejectsCyclesAndUnits() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let graph:any ControlGraphAdmitting=ReferenceControlGraph(),policy=try ControlFixtures.policy();var w=try ControlFixtures.work()
        let edges=[ControlConnection(source:0,destination:1,dimension:.length),ControlConnection(source:1,destination:0,dimension:.length)]
        try graph.admit(dimensions:[.length,.length],directFeedthrough:[false,true],connections:edges,policy:policy,work:&w)
        let e=try ControlFixtures.failure { try graph.admit(dimensions:[.length,.length],directFeedthrough:[true,true],connections:edges,policy:policy,work:&w) }
        if case .algebraicLoop=e.cause {} else { Issue.record("Expected algebraic loop") }
        _=try ControlFixtures.failure { try graph.admit(dimensions:[.mass,.length],directFeedthrough:[false,true],connections:edges,policy:policy,work:&w) }
        var zero=try ControlFixtures.work(operations:0)
        _=try ControlFixtures.failure { try graph.admit(dimensions:[.length,.length],directFeedthrough:[false,true],connections:edges,policy:policy,work:&zero) }
    }
    @Test func modelMetadataPayloadAndScalarCapacityBoundaries() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        _=try ControlFixtures.failure { _=try ControlFixtures.plant(model:ControlFixtures.model(translation:false)) }
        _=try ControlFixtures.failure { _=try ControlFixtures.plant(policy:ControlFixtures.policy(metadata:1)) }
        let (p,l,c)=try ControlFixtures.plant(policy:ControlFixtures.policy(bytes:176))
        _=try ControlFixtures.failure { _=try ControlFixtures.session(plant:p,law:l,policy:c) }
        let low=try ControlFixtures.policy(scalars:512),parts=try ControlFixtures.plant(policy:low),s=try ControlFixtures.session(plant:parts.0,law:parts.1,policy:low)
        defer { _=s.shutdown() }
        let old=try s.checkpoint(codec:NativeRuntimeCheckpointCodec())
        _=try ControlFixtures.failure { _=try s.step(input:ControlFixtures.input(s,plant:parts.0)) }
        #expect(try s.checkpoint(codec:NativeRuntimeCheckpointCodec()) == old)
    }
    @Test func operationActuationAndClockLimitBoundaries() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        for policy in [try ControlFixtures.policy(operations:100),try ControlFixtures.policy(actuation:300)] {
            let (p,l,c)=try ControlFixtures.plant(policy:policy),s=try ControlFixtures.session(plant:p,law:l,policy:c)
            defer { _=s.shutdown() }
            _=try ControlFixtures.failure { _=try s.step(input:ControlFixtures.input(s,plant:p)) }
        }
        let clock=try ControlClock(epochSeconds:1e16,periodSeconds:0.01,maximumTimeSeconds:1e16+100,maximumTicks:10)
        _=try ControlFixtures.failure { _=try clock.end(after:0) }
        let short=try ControlClock(epochSeconds:0,periodSeconds:0.1,maximumTimeSeconds:1,maximumTicks:1)
        _=try ControlFixtures.failure { _=try short.end(after:1) }
    }
    @Test func realSupplierResetsAndOriginalResidualPoisoningStopOnce() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let (p,l,c)=try ControlFixtures.plant()
        for fault in [ControlFaultDrive.Fault.resetBoth,.resetBothThenThrow] {
            let s=try ControlFixtures.session(plant:p,law:l,policy:c,factory:ReferenceControlSessionFactory(drives:ControlFaultDrive(fault:fault,cancellation:nil)))
            defer { _=s.shutdown() }
            let old=try s.checkpoint(codec:NativeRuntimeCheckpointCodec()),error=try ControlFixtures.failure { _=try s.step(input:ControlFixtures.input(s,plant:p)) }
            if case .invalidSupplierLedger=error.cause {} else { Issue.record("Expected ledger reset refusal") }
            #expect(error.failedSupplierWorkUnavailable);#expect((error.actuationWork?.used ?? 0) > 0);#expect((error.numericalWork?.operations ?? 0) > 0)
            #expect(try s.checkpoint(codec:NativeRuntimeCheckpointCodec()) == old)
        }
        for fault in [ControlFaultEquations.Fault.poisonedForce,.resetThenThrow] {
            let s=try ControlFixtures.session(plant:p,law:l,policy:c,factory:ReferenceControlSessionFactory(equations:ControlFaultEquations(fault:fault)))
            defer { _=s.shutdown() }
            let old=try s.checkpoint(codec:NativeRuntimeCheckpointCodec()),error=try ControlFixtures.failure { _=try s.step(input:ControlFixtures.input(s,plant:p)) }
            if fault == .poisonedForce { if case .originalEvidenceRejected=error.cause {} else { Issue.record("Poisoned physical evidence accepted") } }
            else { #expect(error.failedSupplierWorkUnavailable) }
            #expect(try s.checkpoint(codec:NativeRuntimeCheckpointCodec()) == old)
        }
    }
    @Test func cancellationClosureReplacementCannotPublish() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let owner=ControlCancellationOwner(),policy=try ControlFixtures.policy(cancel:{owner.read()}),parts=try ControlFixtures.plant(policy:policy)
        let s=try ControlFixtures.session(plant:parts.0,law:parts.1,policy:policy,factory:ReferenceControlSessionFactory(drives:ControlFaultDrive(fault:.replaceCancellation,cancellation:owner)))
        defer { _=s.shutdown() }
        let old=try ControlFixtures.observation(s).accepted
        let error=try ControlFixtures.failure { _=try s.step(input:ControlFixtures.input(s,plant:parts.0)) }
        if case .actuation(.cancelled)=error.cause {} else { Issue.record("Expected original actuation cancellation authority") }
        let bytes=try s.checkpoint(codec:NativeRuntimeCheckpointCodec()),checkpoint=try NativeRuntimeCheckpointCodec().decode(bytes,capacity:policy.runtimeCapacity)
        #expect(checkpoint == old.checkpoint)
    }
}
