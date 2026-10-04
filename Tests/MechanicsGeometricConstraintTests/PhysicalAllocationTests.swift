import SwiftMechanics
import Testing

@Suite struct PhysicalAllocationTests {
    private func rows(_ system:GeometricConstraintSystem) throws->GeometricPhysicalRowWitness {
        var work=try GeometricFixtures.work()
        let provider:any HolonomicGeometryProviding=GeometricRelationEvaluator(),state=system.model.descriptor.initialState
        let sample=try provider.evaluate(system,state:state,policy:GeometricFixtures.evaluation(),work:&work)
        return try provider.physicalRows(system,state:state,supplied:sample,policy:GeometricPhysicalFixtures.policy(),work:&work)
    }
    private func policy(_ n:Int,rowCancel:Bool=false,rankCancel:Bool=false,bodies:Int=12) throws->GeometricPhysicalAllocationPolicy {
        try GeometricPhysicalAllocationPolicy(rows:GeometricPhysicalFixtures.policy(bodies:bodies,cancelled:rowCancel),
            rank:GeometricFixtures.policy(n,cancelled:{rankCancel}).constraints)
    }
    private func certificate(_ system:GeometricConstraintSystem) throws->GeometricPhysicalAllocationWitness {
        let supplied=try rows(system),policy=try self.policy(system.layout.scales.count)
        var work=try GeometricFixtures.work()
        let provider:any GeometricPhysicalAllocationProviding=GeometricPhysicalAllocationEvaluator()
        return try provider.physicalAllocation(system,state:system.model.descriptor.initialState,supplied:supplied,policy:policy,work:&work)
    }
    @Test(.timeLimit(.minutes(1))) func ordinaryCoincidenceRetainsOriginalRowsAndMultiplierNullity() throws {
        let model=try GeometricFixtures.fourbar(planar:true),system=try GeometricFixtures.system(model,rows:GeometricFixtures.loopRows(),scales:[2,3,4])
        let result=try certificate(system)
        #expect(result.rows.rows.map({$0.rowID}) == [11,12,13])
        #expect(result.originalRank.rank == 2 && result.originalRank.reactionNullity == 1)
        #expect(!result.originalRank.reactionsUnique && !result.multipliersUnique && result.physicalWrenchesUnique)
        #expect(result.activeRowIDs == [11,12] && result.zeroRowIDs == [13])
        let zero=try #require(result.rows.rows.last)
        #expect(zero.isStructuralZero)
        #expect(zero.first.linearGradient == .zero && zero.first.angularGradient == .zero)
        #expect(zero.second.linearGradient == .zero && zero.second.angularGradient == .zero)
        #expect(result.rows.original.velocity.rows[6..<9].allSatisfy({$0 == 0}))
        // Any finite structural-Z multiplier, not just the solver's zero representative, contributes no physical load.
        for multiplier in [-7.0,0,11] {
            #expect(try zero.first.linearGradient.scaled(by:multiplier) == .zero)
            #expect(try zero.second.angularGradient.scaled(by:multiplier) == .zero)
        }
        var work=try GeometricFixtures.work()
        let accepted=try GeometricPhysicalAllocationAcceptance.validated(result,system:system,state:model.descriptor.initialState,policy:self.policy(3),work:&work)
        #expect(accepted.rows.rows == result.rows.rows && accepted.originalRank.dependentRowIDs == [13])
        #expect(work.operations > 0 && work.peakScalarStorage > 0)
    }
    @Test(.timeLimit(.minutes(1))) func distanceNormalizationPreservesIndependentPhysicalLoad() throws {
        let model=try GeometricPhysicalFixtures.sliders()
        let one=try GeometricFixtures.system(model,rows:[GeometricPhysicalFixtures.distance(scale:1)])
        let four=try GeometricFixtures.system(model,rows:[GeometricPhysicalFixtures.distance(scale:4)])
        let a=try certificate(one),b=try certificate(four)
        #expect(a.activeRowIDs == [91] && b.activeRowIDs == [91] && a.zeroRowIDs.isEmpty)
        #expect(a.multipliersUnique && b.multipliersUnique)
        let x=try #require(a.rows.rows.first),y=try #require(b.rows.rows.first)
        let expected=try Vector3(-6,0,0)
        #expect(try x.first.linearGradient.scaled(by:3).subtracting(expected).magnitude() < 1e-10)
        #expect(try y.first.linearGradient.scaled(by:48).subtracting(expected).magnitude() < 1e-10)
        #expect(a.rows.metadata != b.rows.metadata)
    }
    @Test(.timeLimit(.minutes(1))) func activeCoincidenceDuplicatesAndToggleCannotCertify() throws {
        let model=try GeometricFixtures.fourbar(planar:true)
        let duplicate=try GeometricFixtures.system(model,rows:GeometricFixtures.loopRows(duplicate:true))
        try ambiguity(duplicate,row:21)
        let toggleModel=try GeometricFixtures.fourbar(angle:0,nonidentityFrame:false,planar:true)
        let toggle=try GeometricFixtures.system(toggleModel,rows:GeometricFixtures.loopRows())
        let original=try rows(toggle)
        #expect(original.original.velocity.rows[0..<3].allSatisfy({$0 == 0}))
        #expect(try #require(original.rows.first).first.linearGradient != .zero)
        try ambiguity(toggle,row:11)
    }
    @Test(.timeLimit(.minutes(1))) func activeDistanceDuplicateRemainsAmbiguous() throws {
        let model=try GeometricPhysicalFixtures.sliders(),first=try GeometricPhysicalFixtures.distance()
        let second=try GeometricRelation(kind:.distance,rowIDs:[92],first:first.first,second:first.second,target:first.target,scale:first.scale)
        try ambiguity(GeometricFixtures.system(model,rows:[first,second]),row:92)
    }
    private func ambiguity(_ system:GeometricConstraintSystem,row:UInt64) throws {
        let supplied=try rows(system),policy=try self.policy(system.layout.scales.count)
        var work=try GeometricFixtures.work(),refused=false
        let provider:any GeometricPhysicalAllocationProviding=GeometricPhysicalAllocationEvaluator()
        do throws(GeometricPhysicalAllocationError) {
            _=try provider.physicalAllocation(system,state:system.model.descriptor.initialState,supplied:supplied,policy:policy,work:&work)
        } catch {
            if case .ambiguousPhysicalRow(let id)=error { #expect(id == row);refused=true }
            else { Issue.record("Expected active physical row ambiguity.") }
        }
        #expect(refused && work.operations > 0)
    }
    @Test(.timeLimit(.minutes(1))) func opaqueForeignSourceAndTimeCannotPublishAuthority() throws {
        let model=try GeometricPhysicalFixtures.sliders()
        let one=try GeometricFixtures.system(model,rows:[GeometricPhysicalFixtures.distance(scale:1)])
        let four=try GeometricFixtures.system(model,rows:[GeometricPhysicalFixtures.distance(scale:4)])
        let original=try certificate(one),suppliedRows=try rows(four),policy=try self.policy(2)
        let provider:any GeometricPhysicalAllocationProviding=AllocationReturningSupplier(witness:original)
        var work=try GeometricFixtures.work(),refused=false
        let foreign=try provider.physicalAllocation(four,state:model.descriptor.initialState,supplied:suppliedRows,policy:policy,work:&work)
        do throws(GeometricPhysicalAllocationError) {
            _=try GeometricPhysicalAllocationAcceptance.validated(foreign,system:four,state:model.descriptor.initialState,policy:policy,work:&work)
        } catch { if case .geometry(.staleSource)=error { refused=true } else { Issue.record("Expected original source rejection.") } }
        // Canonical source metadata is rejected before arithmetic admission or row/rank recomputation.
        #expect(refused && work.operations == 0 && work.peakScalarStorage == 0)
        let later=try GeometricFixtures.state(model.descriptor.initialState,time:0.25)
        try work.chargeOperations(3)
        var timeRefused=false
        do throws(GeometricPhysicalAllocationError) {
            _=try GeometricPhysicalAllocationAcceptance.validated(original,system:one,state:later,policy:policy,work:&work)
        } catch { if case .geometry(.staleSource)=error { timeRefused=true } else { Issue.record("Expected exact-time source rejection.") } }
        #expect(timeRefused && work.operations == 3 && work.peakScalarStorage == 0)
    }
    @Test(.timeLimit(.minutes(1))) func cancellationCapacityAndNumericalLimitsRetainKnownPrefix() throws {
        let model=try GeometricFixtures.fourbar(planar:true),system=try GeometricFixtures.system(model,rows:GeometricFixtures.loopRows())
        let supplied=try rows(system),state=model.descriptor.initialState
        let provider:any GeometricPhysicalAllocationProviding=GeometricPhysicalAllocationEvaluator()
        for rowCancelled in [false,true] {
            let policy=try self.policy(3,rowCancel:rowCancelled,rankCancel:!rowCancelled)
            var work=try GeometricFixtures.work();try work.chargeOperations(3)
            var refused=false
            do throws(GeometricPhysicalAllocationError) { _=try provider.physicalAllocation(system,state:state,supplied:supplied,policy:policy,work:&work) }
            catch { if case .cancelled=error { refused=true } else { Issue.record("Expected cancellation.") } }
            #expect(refused && work.operations == 3)
        }
        let bounded=try policy(3,bodies:1)
        var work=try GeometricFixtures.work(),capacityRefused=false
        do throws(GeometricPhysicalAllocationError) { _=try provider.physicalAllocation(system,state:state,supplied:supplied,policy:bounded,work:&work) }
        catch { if case .geometry(.capacityExceeded)=error { capacityRefused=true } else { Issue.record("Expected body capacity refusal.") } }
        #expect(capacityRefused)
        let policy=try self.policy(3)
        for storage in [true,false] {
            var limited=try GeometricFixtures.work(storage:storage ? 0 : 4_000_000,operations:storage ? 50_000_000 : 0)
            var refused=false
            do throws(GeometricPhysicalAllocationError) { _=try provider.physicalAllocation(system,state:state,supplied:supplied,policy:policy,work:&limited) }
            catch { if case .geometry(.numerical)=error { refused=true } else { Issue.record("Expected numerical limit.") } }
            #expect(refused)
        }
    }
    @Test(.timeLimit(.minutes(1))) func independentRowsPolicyAndSpatialCertificateAreExplicitRefusals() throws {
        let independent=try GeometricFixtures.policy(2,rank:.requireIndependentRows).constraints
        let rowPolicy=try GeometricPhysicalFixtures.policy()
        var policyRefused=false
        do throws(GeometricPhysicalAllocationError) {
            _=try GeometricPhysicalAllocationPolicy(rows:rowPolicy,rank:independent)
        } catch { if case .invalidPolicy=error { policyRefused=true } }
        #expect(policyRefused)
        let model=try GeometricPhysicalFixtures.sliders(planar:false),system=try GeometricFixtures.system(model,rows:[GeometricPhysicalFixtures.distance()])
        let supplied=try rows(system),policy=try self.policy(2)
        var work=try GeometricFixtures.work(),refused=false
        do throws(GeometricPhysicalAllocationError) {
            _=try GeometricPhysicalAllocationEvaluator().physicalAllocation(system,state:model.descriptor.initialState,supplied:supplied,policy:policy,work:&work)
        } catch { if case .geometry(.unsupportedDomain)=error { refused=true } else { Issue.record("Expected additive planar-only refusal.") } }
        #expect(refused)
    }
}
