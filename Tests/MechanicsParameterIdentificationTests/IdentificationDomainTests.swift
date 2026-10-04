import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct IdentificationDomainTests {
    @Test func correlatedActualMechanicsReportsNullDirectionInsteadOfEstimate() throws {
        let p=try IdentificationFixtures.problem(correlated:true)
        let f=try IdentificationFixtures.failure { try IdentificationFixtures.estimate(p) }
        guard case let .unidentifiable(rank,direction,null,residual)=f.cause else { Issue.record("Expected physical rank refusal");return }
        #expect(rank == 1 && direction.count == 2 && null.count == 2 && residual == 0)
        for o in p.observations {
            #expect(IdentificationFixtures.close(o.state.acceleration[0],2*o.state.v[0]))
            #expect(IdentificationFixtures.close(o.state.acceleration[0]*null[0]+o.state.v[0]*null[1],0))
            let forceA=2*o.state.acceleration[0]+0.5*o.state.v[0]
            let forceB=1.5*o.state.acceleration[0]+1.5*o.state.v[0]
            #expect(IdentificationFixtures.close(forceA,forceB) && IdentificationFixtures.close(forceA,o.appliedForceNewtons))
        }
        #expect(f.phase == .identifiability && !f.failedSupplierWorkUnavailable && f.work.operations > 0)
    }
    @Test func nearCorrelationIsIndeterminateAtCallerThreshold() throws {
        let source=try IdentificationFixtures.source(),clean=try IdentificationFixtures.synthetic(source,correlated:true)
        let state=clean[1].state
        var observations=clean
        observations[1]=ForceObservation(state:try KinematicState(revision:state.revision,time:state.time,q:state.q,v:state.v,
            acceleration:[state.acceleration[0]+1e-9]),appliedForceNewtons:clean[1].appliedForceNewtons,forceStandardDeviationNewtons:1)
        let p=try IdentificationFixtures.problem(source:source,observations:observations)
        let f=try IdentificationFixtures.failure { try IdentificationFixtures.estimate(p,policy:IdentificationFixtures.policy(rank:1e-6)) }
        guard case let .rankIndeterminate(pivot,threshold)=f.cause else { Issue.record("Expected indeterminate rank");return }
        #expect(pivot > 0 && pivot <= threshold && f.phase == .identifiability)
    }
    @Test func staleObservationAndNonpositiveNoiseAreRefusedBeforeSampling() throws {
        let p=try IdentificationFixtures.problem(),o=p.observations[0]
        for variant in 0..<2 {
            let state=try KinematicState(revision:variant == 0 ? 6 : 7,time:o.state.time,q:o.state.q,v:o.state.v,acceleration:o.state.acceleration)
            let bad=ForceObservation(state:state,appliedForceNewtons:o.appliedForceNewtons,forceStandardDeviationNewtons:variant == 0 ? 1 : 0)
            let f=try IdentificationFixtures.failure { try IdentificationFixtures.estimate(IdentificationFixtures.problem(source:p.source,observations:[bad,p.observations[1]])) }
            guard case .invalidObservation=f.cause else { Issue.record("Expected observation refusal");continue }
            #expect(f.phase == .admission && f.modelValidationAttempts == 0 && f.loadWork.consumed == 0)
        }
    }
    @Test func invalidUnitsBoundsAndUnsupportedRotationAreExplicit() throws {
        let p=try IdentificationFixtures.problem()
        let metadata=try OptimizationMetadata(identity:p.metadata.identity,provenance:p.metadata.provenance,variableIDs:p.metadata.variableIDs,
            variableReferences:[SIReferenceQuantity(magnitude:1,dimension:.length),p.metadata.variableReferences[1]],objectiveReference:p.metadata.objectiveReference)
        let bad=PhysicalIdentificationProblem(source:p.source,observations:p.observations,metadata:metadata,lowerBounds:p.lowerBounds,upperBounds:p.upperBounds)
        let units=try IdentificationFixtures.failure { try IdentificationFixtures.estimate(bad) }
        guard case .invalidUnits=units.cause else { Issue.record("Expected unit refusal");return }
        let bounds=try IdentificationFixtures.failure { try IdentificationFixtures.estimate(IdentificationFixtures.problem(lower:[0,0])) }
        guard case .invalidBounds=bounds.cause else { Issue.record("Expected mass domain refusal");return }
        let source=try IdentificationFixtures.source(prismatic:false)
        let rotated=try IdentificationFixtures.failure { try IdentificationFixtures.estimate(IdentificationFixtures.problem(source:source,observations:p.observations)) }
        guard case .unsupportedDomain=rotated.cause else { Issue.record("Expected unimplemented mechanical domain");return }
        #expect(rotated.phase == .admission && rotated.modelValidationAttempts == 0)
    }
    @Test func constitutiveStrokeEnvelopeRetainsActualLoadFailure() throws {
        let p=try IdentificationFixtures.problem(),o=p.observations[0]
        let bad=ForceObservation(state:try KinematicState(revision:7,time:0,q:[11],v:o.state.v,acceleration:o.state.acceleration),
            appliedForceNewtons:o.appliedForceNewtons,forceStandardDeviationNewtons:1)
        let f=try IdentificationFixtures.failure { try IdentificationFixtures.estimate(IdentificationFixtures.problem(source:p.source,observations:[bad,p.observations[1]])) }
        guard case .loads(.outsideDomain)=f.cause else { Issue.record("Expected actual load-domain failure");return }
        #expect(f.phase == .physicalDesign && f.loadWork.consumed > 0)
    }
}
