import SwiftMechanics
import Testing
struct GranularReplayTests {
    @Test func weightedPhysicalDistributionKeepsActualRandomContinuation() throws {
        let templates=[try GranularDistributionTemplate(weight:1,radius:0.1,density:1000,material:GranularFixtures.ref("a",.material)),
            try GranularDistributionTemplate(weight:3,radius:0.2,density:2000,material:GranularFixtures.ref("b",.material))]
        var n=try GranularFixtures.numerical(), s=try GranularFixtures.supplier()
        let service: any GranularSampling=SeededGranularSampler(), random=RuntimeRandomState(seed:123)
        let result=try service.sample(count:20,templates:templates,random:random,policy:GranularFixtures.policy(),numericalWork:&n,supplierWork:&s)
        var expected=random
        for sample in result.samples {
            let draw=try expected.next(), index=draw%4 == 0 ? 0 : 1
            #expect(sample.templateIndex == index)
            #expect(sample.material == templates[index].material)
            #expect(GranularFixtures.close(sample.mass,(4.0/3.0)*Double.pi*templates[index].density*templates[index].radius*templates[index].radius*templates[index].radius))
        }
        #expect(result.random == expected && result.random.draws == 20)
        #expect(result.samples.contains { $0.templateIndex == 0 } && result.samples.contains { $0.templateIndex == 1 })
    }
    @Test func checkpointReplaysEveryBristleBasisMotionAndRngField() throws {
        var rng=RuntimeRandomState(seed:123); _=try rng.next(); _=try rng.next()
        let initial=try GranularFixtures.prepare(motions:[GranularMotion(position:Vector3(0,0,0.49))],plane:true,planeVelocity:.unitX,friction:true,random:rng)
        var w=GranularWorkspace(); let prefix=try GranularFixtures.step(initial,workspace:&w).state
        var n=try GranularFixtures.numerical()
        let service: any GranularCheckpointing=ValueGranularCheckpoints()
        let checkpoint=try service.capture(prefix,policy:GranularFixtures.policy(),work:&n)
        let restored=try service.restore(checkpoint,model:initial.model,policy:GranularFixtures.policy(),work:&n)
        var a=prefix,b=restored,wa=GranularWorkspace(),wb=GranularWorkspace()
        for _ in 0..<20 { a=try GranularFixtures.step(a,workspace:&wa).state; b=try GranularFixtures.step(b,workspace:&wb).state }
        #expect(GranularFixtures.same(a,b))
        #expect(a.contacts[0].history.sequence == 21 && a.random.draws == 2)
        #expect(checkpoint.state.contacts[0].history.sequence == 1)
    }
    @Test func rejectionDoesNotAdvanceAcceptedPhysicalOrHistoryState() throws {
        let initial=try GranularFixtures.prepare(motions:[GranularMotion(position:Vector3(0,0,0.49))],plane:true,friction:true)
        var workspace=GranularWorkspace()
        do { _=try GranularFixtures.step(initial,policy:GranularFixtures.policy(neighbors:0),workspace:&workspace); Issue.record("Expected neighbor failure") }
        catch let error as GranularError { guard case .capacity(resource:"neighbors",limit:0)=error else { Issue.record("Wrong failure"); return } }
        var fresh=GranularWorkspace()
        let afterFailure=try GranularFixtures.step(initial,workspace:&workspace), direct=try GranularFixtures.step(initial,workspace:&fresh)
        #expect(GranularFixtures.same(afterFailure.state,direct.state))
        #expect(initial.contacts[0].history.sequence == 0 && initial.timeSeconds == 0)
    }
}
