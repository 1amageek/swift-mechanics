@testable import SwiftMechanics
import Testing
struct BucklingPhysicsTests {
    @Test func assembledPinnedBeamBucklingRefinesToEulerLoad() throws {
        let service:any BucklingAnalyzing=ReferenceBucklingAnalyzer();var errors:[Double]=[]
        for elements in [1,2,4,8] {
            let beam=try StructuralFixtures.beam(elements:elements);var w=try StructuralFixtures.work()
            let result=try service.beam(beam,fixedCoordinates:[0,beam.coordinateCount-2],expectedRevision:1,policy:StructuralFixtures.policy(),work:&w)
            let exact=3.141592653589793*3.141592653589793*beam.youngModulus*beam.beam.secondMoment/(beam.beam.length*beam.beam.length)
            errors.append(abs(result.criticalLoad/exact-1));#expect(result.maximumOriginalResidual<1e-6)
            var normalization=0.0
            for i in result.mode.indices { for j in result.mode.indices { normalization+=result.mode[i]*beam.geometricStiffness[result.retainedCoordinates[i]*beam.coordinateCount+result.retainedCoordinates[j]]*result.mode[j] } }
            #expect(abs(normalization-1)<1e-6)
        }
        for i in 1..<errors.count { #expect(errors[i]<errors[i-1]) };#expect(errors.last!<1e-4)
    }
    @Test func nonlinearTrussEnergyGradientTangentAndCriticalPointHaveIndependentOracles() throws {
        let model=try StructuralFixtures.truss(),service:any BucklingAnalyzing=ReferenceBucklingAnalyzer(),policy=try StructuralFixtures.policy();var w=try StructuralFixtures.work()
        let y=0.35,h=1e-5,point=try service.truss(model,height:y,expectedRevision:1,policy:policy,work:&w)
        let plus=try service.truss(model,height:y+h,expectedRevision:1,policy:policy,work:&w),minus=try service.truss(model,height:y-h,expectedRevision:1,policy:policy,work:&w)
        #expect(StructuralFixtures.close((plus.energy-minus.energy)/(2*h),-point.downwardLoad,1e-7))
        #expect(StructuralFixtures.close(-(plus.downwardLoad-minus.downwardLoad)/(2*h),point.verticalTangent,1e-7))
        let critical=try service.criticalTruss(model,lowerHeight:0,upperHeight:0.5,positionTolerance:1e-10,expectedRevision:1,policy:policy,work:&w)
        // Independent cubic length condition l^3=l0*a^2 evaluated to high precision.
        #expect(abs(critical.point.height-0.2778800910751648)<1e-8);#expect(abs(critical.point.downwardLoad-38.383739817434744)<1e-7)
        #expect(critical.lowerHeight<=0.2778800910751648);#expect(critical.upperHeight>=0.2778800910751648)
        #expect(critical.normalizedTangentResidual<1e-6)
        let branch=try service.continueTruss(model,heights:[0.5,0.35,0.2,0.1],descending:true,expectedRevision:1,policy:policy,work:&w)
        #expect(branch.points[0].classification == .positive);#expect(branch.points[2].classification == .negative)
        #expect(branch.points[1].downwardLoad>branch.points[0].downwardLoad);#expect(branch.points[3].downwardLoad<branch.points[2].downwardLoad)
    }
    @Test func branchBracketDomainAndIterationFailuresDoNotBecomeBuckling() throws {
        let model=try StructuralFixtures.truss(),service:any BucklingAnalyzing=ReferenceBucklingAnalyzer(),policy=try StructuralFixtures.policy();var w=try StructuralFixtures.work()
        #expect(throws:StructuralError.self) { try service.continueTruss(model,heights:[0.5,0.2,0.35],descending:true,expectedRevision:1,policy:policy,work:&w) }
        #expect(throws:StructuralError.self) { try service.criticalTruss(model,lowerHeight:0.35,upperHeight:0.5,positionTolerance:1e-8,expectedRevision:1,policy:policy,work:&w) }
        #expect(throws:StructuralError.self) { try service.truss(model,height:10,expectedRevision:1,policy:policy,work:&w) }
        var exhausted=try StructuralFixtures.work(iterations:0)
        do throws(StructuralError) { _=try service.criticalTruss(model,lowerHeight:0,upperHeight:0.5,positionTolerance:1e-10,expectedRevision:1,policy:policy,work:&exhausted);Issue.record("Budget failure reported critical load") }
        catch { if case .nonConvergence = error {} else { Issue.record("Wrong failure") } }
        let beam=try StructuralFixtures.beam()
        do throws(StructuralError) { _=try service.nonlinearBeam(beam,policy:policy,work:&w);Issue.record("Deferred beam accepted") } catch { if case .unsupportedDomain = error {} else { Issue.record("Wrong failure") } }
    }
}
