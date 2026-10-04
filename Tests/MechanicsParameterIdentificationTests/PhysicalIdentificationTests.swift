import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct PhysicalIdentificationTests {
    @Test func suppliedUnequalForceVariancesChangeInformationWithoutChangingExactFit() throws {
        let p=try IdentificationFixtures.problem(),first=p.observations[0]
        let weighted=[ForceObservation(state:first.state,appliedForceNewtons:first.appliedForceNewtons,forceStandardDeviationNewtons:2),p.observations[1]]
        let result=try IdentificationFixtures.estimate(IdentificationFixtures.problem(source:p.source,observations:weighted))
        #expect(IdentificationFixtures.close(result.massKilograms,2) && IdentificationFixtures.close(result.dampingNewtonSecondsPerMeter,0.5))
        let information=[1.25,-1.75,-1.75,4.25],covariance=[17.0/9,7.0/9,7.0/9,5.0/9]
        for i in 0..<4 {
            #expect(IdentificationFixtures.close(result.normalizedInformationMatrix[i],information[i]))
            #expect(IdentificationFixtures.close(result.unconstrainedGaussianReferenceCovariance[i],covariance[i]))
        }
        #expect(result.objective < 1e-14)
    }
    @Test func actualForwardObservationsRecoverMassDampingAndOriginalInformation() throws {
        let problem=try IdentificationFixtures.problem(),result=try IdentificationFixtures.estimate(problem)
        #expect(IdentificationFixtures.close(problem.observations[0].state.acceleration[0],1))
        #expect(IdentificationFixtures.close(problem.observations[1].state.acceleration[0],-1))
        #expect(IdentificationFixtures.close(result.massKilograms,2))
        #expect(IdentificationFixtures.close(result.dampingNewtonSecondsPerMeter,0.5))
        #expect(result.objective < 1e-14 && result.originalForceResidualsNewtons.allSatisfy { abs($0) < 1e-8 })
        let information=[2.0,-1.0,-1.0,5.0],covariance=[5.0/9,1.0/9,1.0/9,2.0/9]
        for i in 0..<4 {
            #expect(IdentificationFixtures.close(result.normalizedInformationMatrix[i],information[i]))
            #expect(IdentificationFixtures.close(result.unconstrainedGaussianReferenceCovariance[i],covariance[i]))
        }
        #expect(result.identifiableNormalizedDirections == [1,0,0,1])
        #expect(result.noiseAssumption == .independentGaussianForceNoiseKnownVarianceWithExactKinematics)
        #expect(result.originalInformationResidual < 1e-8 && result.originalStationarityResidual < 1e-8)
        #expect(result.modelValidationAttempts == 4 && result.loadWork.consumed == 8)
        #expect(result.work.operations > 0 && result.supplierWork.calls > 0)
    }
    @Test func noisyForceDataReportsRealMisfitAndConditionalReferenceCovariance() throws {
        let source=try IdentificationFixtures.source(),clean=try IdentificationFixtures.synthetic(source,third:true)
        var noisy=clean
        noisy[2]=ForceObservation(state:clean[2].state,appliedForceNewtons:clean[2].appliedForceNewtons+0.1,forceStandardDeviationNewtons:1)
        let result=try IdentificationFixtures.estimate(IdentificationFixtures.problem(source:source,observations:noisy))
        #expect(IdentificationFixtures.close(result.massKilograms,2-0.1/11))
        #expect(IdentificationFixtures.close(result.dampingNewtonSecondsPerMeter,0.5-0.2/11))
        let covariance=[6.0/11,1.0/11,1.0/11,2.0/11]
        for i in 0..<4 { #expect(IdentificationFixtures.close(result.unconstrainedGaussianReferenceCovariance[i],covariance[i])) }
        var independent=0.0
        for i in noisy.indices {
            let expected=result.massKilograms*noisy[i].state.acceleration[0]+result.dampingNewtonSecondsPerMeter*noisy[i].state.v[0]-noisy[i].appliedForceNewtons
            #expect(IdentificationFixtures.close(result.originalForceResidualsNewtons[i],expected))
            independent += 0.5*expected*expected
        }
        #expect(result.objective > 0 && IdentificationFixtures.close(result.objective,independent))
        #expect(result.originalStationarityResidual < 1e-8)
    }
    @Test func physicalScalesAxisRotationAndFixedCOMDoNotChangeParameters() throws {
        let rotated=try IdentificationFixtures.source(rotation:UnitQuaternion(axis:Vector3(1,2,3),angle:0.7),com:Vector3(0.2,-0.3,0.4))
        let result=try IdentificationFixtures.estimate(IdentificationFixtures.problem(source:rotated,scales:[0.25,3]))
        #expect(IdentificationFixtures.close(result.massKilograms,2))
        #expect(IdentificationFixtures.close(result.dampingNewtonSecondsPerMeter,0.5))
        let covariance=[5.0/9,1.0/9,1.0/9,2.0/9]
        for i in 0..<4 { #expect(IdentificationFixtures.close(result.unconstrainedGaussianReferenceCovariance[i],covariance[i])) }
        #expect(result.objective < 1e-14)
    }
    @Test func activeMassBoundRetainsOriginalKKTAndDoesNotClaimBoundedCovariance() throws {
        let result=try IdentificationFixtures.estimate(IdentificationFixtures.problem(upper:[1.8,4]))
        #expect(IdentificationFixtures.close(result.massKilograms,1.8))
        #expect(IdentificationFixtures.close(result.dampingNewtonSecondsPerMeter,0.46))
        #expect(IdentificationFixtures.close(result.objective,0.036))
        #expect(IdentificationFixtures.close(result.optimizationCertificate.upperMultipliers[0],0.36))
        #expect(result.activeUpperBounds == [true,false] && result.activeLowerBounds == [false,false])
        #expect(IdentificationFixtures.close(result.unconstrainedGaussianReferenceCovariance[0],5.0/9))
        #expect(result.originalStationarityResidual < 1e-8)
    }
    @Test func callerWorkspaceReusePreservesIssuedObservationsAndEarlierEstimate() throws {
        let problem=try IdentificationFixtures.problem(),service:any PhysicalParameterIdentifying=PhysicalMassDamperIdentifier()
        var workspace=IdentificationWorkspace(),loads=try IdentificationFixtures.loadWork(),calls=try IdentificationFixtures.calls(),work=try IdentificationFixtures.work()
        let first=try service.estimate(problem,policy:IdentificationFixtures.policy(),workspace:&workspace,loadWork:&loads,supplierWork:&calls,work:&work)
        let second=try service.estimate(problem,policy:IdentificationFixtures.policy(),workspace:&workspace,loadWork:&loads,supplierWork:&calls,work:&work)
        #expect(IdentificationFixtures.close(first.massKilograms,second.massKilograms))
        #expect(first.originalForceResidualsNewtons == second.originalForceResidualsNewtons)
        #expect(problem.observations[0].state.v == [1] && problem.observations[0].state.revision == 7)
        #expect(second.work.operations > first.work.operations && second.loadWork.consumed > first.loadWork.consumed)
    }
}
