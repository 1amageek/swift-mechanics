import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ContactBoundaryTests {
    @Test(arguments:[0.0,-0.0005,-0.02]) func onsetNeighborhoodAndForceClampRefuse(_ separation: Double) throws {
        let pair=try ContactDerivativeFixtures.pair()
        let input=try ContactDerivativeFixtures.input(s:separation,vn:separation == -0.02 ? 1 : 0)
        let history=try ContactDerivativeFixtures.history(pair,input:input), policy=try ContactDerivativeFixtures.policy()
        let direction=try ContactDirection(separation:0,relativeVelocity:.zero)
        var work=try ContactDerivativeFixtures.work()
        do {
            _=try ExactContactDifferentiator().contact(input:input,pair:pair,accepted:history,direction:direction,policy:policy,work:&work)
            Issue.record("Nonsmooth neighborhood was accepted")
        } catch { guard case .nonsmoothBoundary=error else { throw error } }
        #expect(work.operations < 1000)
    }
    @Test func originalDomainAndUnsupportedFrictionRefuse() throws {
        let pair=try ContactDerivativeFixtures.pair(), input=try ContactDerivativeFixtures.input(s:-0.5)
        let history=try ContactDerivativeFixtures.history(pair,input:input), policy=try ContactDerivativeFixtures.policy()
        let direction=try ContactDirection(separation:0,relativeVelocity:.zero)
        var work=try ContactDerivativeFixtures.work()
        do { _=try ExactContactDifferentiator().contact(input:input,pair:pair,accepted:history,direction:direction,policy:policy,work:&work); Issue.record("Domain accepted") }
        catch { guard case .outsideDomain=error else { throw error } }
        let friction=ContactFrictionLaw.elasticCoulomb(try ContactFrictionParameters(staticFirst:0.8,staticSecond:0.8,dynamicFirst:0.4,dynamicSecond:0.4,tangentialStiffness:2000,transitionSpeed:0.1))
        let fp=try ContactDerivativeFixtures.pair(friction:friction), fi=try ContactDerivativeFixtures.input()
        let fh=try ContactDerivativeFixtures.history(fp,input:fi)
        do { _=try ExactContactDifferentiator().contact(input:fi,pair:fp,accepted:fh,direction:direction,policy:policy,work:&work); Issue.record("Friction accepted") }
        catch { guard case .unsupportedDomain=error else { throw error } }
    }
    @Test func impactThresholdAndNeighborhoodAreExactRefusals() throws {
        let pair=try ContactDerivativeFixtures.pair(.hertz(coefficient:1000,effectiveRadius:1,maximumPenetration:0.5,maximumNormalSpeed:100),loss:.separateImpact(restitution:0.6,thresholdSpeed:1))
        let direction=try ContactImpactDirection(approachSpeed:1,incomingNormalEnergy:1), policy=try ContactDerivativeFixtures.policy()
        for speed in [1.0,0.995,1.005] {
            var work=try ContactDerivativeFixtures.work()
            do { _=try ExactContactDifferentiator().impact(pair:pair,approachSpeed:speed,incomingNormalEnergy:1,direction:direction,policy:policy,work:&work); Issue.record("Threshold accepted") }
            catch { guard case .nonsmoothBoundary=error else { throw error } }
        }
    }
    @Test func staleHistoryAndMetadataCapacityFailBeforeOpaqueWork() throws {
        let pair=try ContactDerivativeFixtures.pair(), changed=try ContactDerivativeFixtures.pair(.linear(stiffness:1001,damping:20,maximumPenetration:0.5,maximumNormalSpeed:100))
        let input=try ContactDerivativeFixtures.input(), history=try ContactDerivativeFixtures.history(pair,input:input)
        let direction=try ContactDirection(separation:0,relativeVelocity:.zero), policy=try ContactDerivativeFixtures.policy()
        var work=try ContactDerivativeFixtures.work()
        do { _=try ExactContactDifferentiator().contact(input:input,pair:changed,accepted:history,direction:direction,policy:policy,work:&work); Issue.record("Changed source accepted") }
        catch { guard case .law(.staleHistory)=error else { throw error } }
        let small=try ContactDerivativeFixtures.policy(bytes:1)
        do { _=try ExactContactDifferentiator().contact(input:input,pair:pair,accepted:history,direction:direction,policy:small,work:&work); Issue.record("Metadata accepted") }
        catch { guard case .law(.resourceLimit)=error else { throw error } }
    }
}
