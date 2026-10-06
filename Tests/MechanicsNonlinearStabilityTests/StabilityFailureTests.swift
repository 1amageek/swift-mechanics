import SwiftMechanics
import Testing

@Suite struct StabilityFailureTests {
    private func initial(_ source: NonlinearStabilitySource,_ policy: NonlinearStabilityPolicy,_ work: inout NumericalWork) throws -> NonlinearStabilityState {
        let u=0.67
        return try ReferenceNonlinearStabilityContinuation().start(source,position:StabilityFixtures.seed(u:u,v:0),parameter:u+u*u*u,
            initialDirection:[-1,-1,-2,-(1+3*u*u)],policy:policy,work:&work)
    }
    @Test func sourceAndMetricOwnersCannotBeSubstituted() throws {
        var w=try StabilityFixtures.work();let s=try StabilityFixtures.source(work:&w),p=try StabilityFixtures.policy(),state=try initial(s,p,&w)
        let changedLaw=try StabilityFixtures.source(linear:[-1,-1,1.1],work:&w)
        let changedMass=try StabilityFixtures.source(masses:[1,1,2],work:&w)
        let sameValues=try StabilityFixtures.source(work:&w)
        for other in [changedLaw,changedMass,sameValues] {
            do { _=try ReferenceNonlinearStabilityContinuation().advance(other,state:state,arcStep:0.05,policy:p,work:&w);Issue.record("Changed owner accepted") }
            catch { guard case .staleSource=error.cause else { Issue.record("Wrong failure");return };#expect(error.priorAcceptedState===state) }
        }
        let otherPolicy=try StabilityFixtures.policy()
        do { _=try ReferenceNonlinearStabilityContinuation().advance(s,state:state,arcStep:0.05,policy:otherPolicy,work:&w);Issue.record("Changed policy accepted") }
        catch { guard case .staleSource=error.cause else { Issue.record("Wrong failure");return } }
    }
    @Test func nonlinearRowsRedundantRowsAndOneFreeCoordinateRefused() throws {
        var w=try StabilityFixtures.work()
        for row in [[[-1.0,-1,1],[-2,-2,2]],[[1.0,0,0],[0,1,0]]] {
            do { _=try StabilityFixtures.source(rows:row,work:&w);Issue.record("Unsupported rows accepted") }
            catch let failure as NonlinearStabilityFailure { guard case .unsupportedDomain=failure.cause else { Issue.record("Wrong failure");return } }
        }
        do { _=try StabilityFixtures.source(nonlinearRow:true,work:&w);Issue.record("Nonlinear row accepted") }
        catch let failure as NonlinearStabilityFailure { guard case .unsupportedDomain=failure.cause else { Issue.record("Wrong failure");return } }
    }
    @Test func immediateCancellationAndOriginalStabilityStayDistinct() throws {
        var w=try StabilityFixtures.work();let s=try StabilityFixtures.source(work:&w),p=try StabilityFixtures.policy(cancel:{true})
        do { _=try initial(s,p,&w);Issue.record("Cancellation accepted") }
        catch let failure as NonlinearStabilityFailure { guard case .cancelled=failure.cause else { Issue.record("Wrong failure");return };#expect(!failure.failedSupplierWorkUnavailable) }
    }
    @available(macOS 15.0, *)
    @Test func lateSpectralCancellationAndCorruptedLedgerAreAuthoritative() throws {
        var w=try StabilityFixtures.work();let s=try StabilityFixtures.source(work:&w)
        let flag=StabilityCancellation(),p=try StabilityFixtures.policy(spectralCancel:{flag.read()})
        let solver=ReferenceNonlinearStabilityContinuation(spectrum:LateStabilityCancellation(cancellation:flag)),u=0.67
        do { _=try solver.start(s,position:StabilityFixtures.seed(u:u,v:0),parameter:u+u*u*u,initialDirection:[-1,-1,-2,-2],policy:p,work:&w);Issue.record("Late spectral cancellation accepted") }
        catch { guard case .spectral(.cancelled)=error.cause else { Issue.record("Wrong failure");return };#expect(error.work==w) }
        let normal=try StabilityFixtures.policy(),before=w
        do { _=try ReferenceNonlinearStabilityContinuation(spectrum:ResetStabilityLedger()).start(s,position:StabilityFixtures.seed(u:u,v:0),parameter:u+u*u*u,initialDirection:[-1,-1,-2,-2],policy:normal,work:&w);Issue.record("Reset supplier accepted") }
        catch { guard case .invalidSupplierWork=error.cause else { Issue.record("Wrong failure");return };#expect(error.failedSupplierWorkUnavailable);#expect(w.operations>before.operations) }
    }
    @Test func originalEvidenceRejectsFalseEigenvaluesAndFalseDerivative() throws {
        var w=try StabilityFixtures.work();let s=try StabilityFixtures.source(work:&w),p=try StabilityFixtures.policy(),u=0.67
        do { _=try ReferenceNonlinearStabilityContinuation(spectrum:FalseStabilityModes()).start(s,position:StabilityFixtures.seed(u:u,v:0),parameter:u+u*u*u,
            initialDirection:[-1,-1,-2,-2],policy:p,work:&w);Issue.record("False spectrum accepted") }
        catch { guard case .originalResidualRejected=error.cause else { Issue.record("Wrong failure");return } }
        do { _=try ReferenceNonlinearStabilityContinuation(forces:FalseStabilityTangent()).start(s,position:StabilityFixtures.seed(u:u,v:0),parameter:u+u*u*u,
            initialDirection:[-1,-1,-2,-2],policy:p,work:&w);Issue.record("False tangent accepted") }
        catch { guard case .derivativeMismatch=error.cause else { Issue.record("Wrong failure");return } }
    }
    @Test func unknownFailedLinearWorkRemainsUnavailable() throws {
        var w=try StabilityFixtures.work();let s=try StabilityFixtures.source(work:&w),p=try StabilityFixtures.policy(),u=0.67
        do { _=try ReferenceNonlinearStabilityContinuation(linear:RejectStabilityLinear()).start(s,position:StabilityFixtures.seed(u:u,v:0),parameter:u+u*u*u,
            initialDirection:[-1,-1,-2,-2],policy:p,work:&w);Issue.record("Failed solver accepted") }
        catch { guard case .linear(.singular)=error.cause else { Issue.record("Wrong failure");return };#expect(error.failedSupplierWorkUnavailable);#expect(error.work==w) }
    }
    @Test func correctionFailureAndPointLimitPreserveAcceptedState() throws {
        var w=try StabilityFixtures.work();let s=try StabilityFixtures.source(work:&w),p=try StabilityFixtures.policy(nonlinearIterations:0)
        let state=try ReferenceNonlinearStabilityContinuation().start(s,position:[0,0,0],parameter:0,initialDirection:[1,1,2,1],policy:p,work:&w)
        let original=state.point.position
        do { _=try ReferenceNonlinearStabilityContinuation().advance(s,state:state,arcStep:0.08,policy:p,work:&w);Issue.record("Zero-iteration correction accepted") }
        catch { guard case .nonlinear(let failure)=error.cause else { Issue.record("Wrong failure");return };#expect(failure.work.iterations==0);#expect(error.priorAcceptedState===state);#expect(state.point.position==original) }
        let limit=try StabilityFixtures.policy(maximumPoints:1),limited=try initial(s,limit,&w)
        do { _=try ReferenceNonlinearStabilityContinuation().advance(s,state:limited,arcStep:0.05,policy:limit,work:&w);Issue.record("Point limit ignored") }
        catch { guard case .capacityExceeded=error.cause else { Issue.record("Wrong failure");return };#expect(error.priorAcceptedState===limited) }
    }
    @Test(arguments:[NumericalResource.scalarStorage,.arithmeticOperations,.iterations]) func resourceCeilingsAreActual(resource: NumericalResource) throws {
        var setup=try StabilityFixtures.work();let s=try StabilityFixtures.source(work:&setup),p=try StabilityFixtures.policy(),state=try initial(s,p,&setup)
        var w=try StabilityFixtures.work(storage:resource == .scalarStorage ? 0 : 500000,operations:resource == .arithmeticOperations ? 0 : 100000000,iterations:resource == .iterations ? 0 : 10000)
        do { _=try ReferenceNonlinearStabilityContinuation().advance(s,state:state,arcStep:0.05,policy:p,work:&w);Issue.record("Resource ceiling ignored") }
        catch { guard case .numerical(.resourceLimit(let actual,_))=error.cause else { Issue.record("Wrong failure");return };#expect(actual==resource);#expect(error.work==w);#expect(error.priorAcceptedState===state) }
    }
    @Test func ownedMetadataEnvelopeRejectsPreviouslyAdmittedLongKeys() throws {
        var w=try StabilityFixtures.work();let original=try StabilityFixtures.source(work:&w)
        let small=try EquilibriumLimits(coordinates:8,rows:4,cases:1000,identifierBytes:1,bodies:16),before=w
        do { _=try NonlinearStabilitySource(model:original.model,constraints:original.constraints,compiled:original.compiled,
            branch:original.branch,time:original.time,limits:small,work:&w);Issue.record("Source ignored its current key envelope") }
        catch { guard case .capacityExceeded=error.cause else { Issue.record("Wrong failure");return };#expect(error.work==w);#expect(w.operations==before.operations+2) }
    }
    @Test func exhaustedCriticalRefinementCannotPublishCandidate() throws {
        var w=try StabilityFixtures.work();let source=try StabilityFixtures.source(work:&w),policy=try StabilityFixtures.policy(criticalIterations:1)
        let solver=ReferenceNonlinearStabilityContinuation();var state=try initial(source,policy,&w)
        var bracket:(NonlinearStabilityState,NonlinearStabilityState)?
        for _ in 0..<20 {
            let old=state;state=try solver.advance(source,state:state,arcStep:0.06,policy:policy,work:&w)
            if old.point.stiffnessEigenvalues[0]*state.point.stiffnessEigenvalues[0]<0 { bracket=(old,state);break }
        }
        let endpoints=try #require(bracket)
        do { _=try solver.critical(source,left:endpoints.0,right:endpoints.1,policy:policy,work:&w);Issue.record("Exhausted refinement published") }
        catch { guard case .unresolvedCriticalPoint=error.cause else { Issue.record("Wrong failure");return };#expect(error.priorAcceptedState===endpoints.1);#expect(error.work==w) }
    }
    @Test func independentRowAdmissionIsActualAndBounded() throws {
        var w=try StabilityFixtures.work()
        do { _=try StabilityFixtures.source(linear:[1,2,3,4],cubic:[1,2,3,4],load:[1,1,1,1],rows:[[1,0,-1,0],[2,0,-2,0]],work:&w);Issue.record("Dependent linkage admitted") }
        catch let error as NonlinearStabilityFailure { guard case .unsupportedDomain=error.cause else { Issue.record("Wrong failure");return };#expect(error.work==w) }
    }
    @Test func chartStampCannotBorrowUnrelatedCompiledInertia() throws {
        var w=try StabilityFixtures.work();let source=try StabilityFixtures.source(work:&w),c=source.model.chart,m=source.model
        let chart=try StaticCoordinateChart(stamp:ModelStamp(identity:c.stamp.identity,revision:c.stamp.revision+1),frame:c.frame,coordinateIDs:c.coordinateIDs,
            joints:c.joints,dimensions:c.dimensions,scales:c.scales,limits:StabilityFixtures.limits())
        let altered=try StaticForceModel(identity:m.identity,chart:chart,law:m.law,minimumPosition:m.minimumPosition,maximumPosition:m.maximumPosition,
            parameterIdentity:m.parameterIdentity,minimumParameter:m.minimumParameter,maximumParameter:m.maximumParameter,energyScale:m.energyScale,limits:StabilityFixtures.limits())
        let limit=try StabilityFixtures.limits()
        do { _=try NonlinearStabilitySource(model:altered,constraints:source.constraints,compiled:source.compiled,branch:source.branch,time:source.time,
            limits:limit,work:&w);Issue.record("Unrelated chart borrowed compiled mass") }
        catch { guard case .staleSource=error.cause else { Issue.record("Wrong failure");return };#expect(error.work==w) }
    }
    @Test func criticalRefusalDoesNotClaimPhysicalInstability() throws {
        var w=try StabilityFixtures.work();let s=try StabilityFixtures.source(work:&w),p=try StabilityFixtures.policy(),state=try initial(s,p,&w)
        let next=try ReferenceNonlinearStabilityContinuation().advance(s,state:state,arcStep:0.01,policy:p,work:&w)
        do { _=try ReferenceNonlinearStabilityContinuation().critical(s,left:state,right:next,policy:p,work:&w);Issue.record("No-bracket critical point accepted") }
        catch { guard case .noCriticalBracket=error.cause else { Issue.record("Wrong failure");return } }
        let other=try initial(s,p,&w)
        do { _=try ReferenceNonlinearStabilityContinuation().critical(s,left:state,right:other,policy:p,work:&w);Issue.record("Separate lineage accepted") }
        catch { guard case .staleSource=error.cause else { Issue.record("Wrong failure");return } }
    }
}
