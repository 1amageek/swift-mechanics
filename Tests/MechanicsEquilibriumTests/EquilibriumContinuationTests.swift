import SwiftMechanics
import Testing

@Suite struct EquilibriumContinuationTests {
    @Test func selectedDoubleWellBranchesAndReversibleLoadingRemainExplicit()throws {
        let model=try EquilibriumFixtures.springs([-1],b:[1]);let service:any EquilibriumContinuing=ReferenceEquilibriumContinuation()
        let positive=try EquilibriumFixtures.branch(minimum:0.5,maximum:2,step:0.3,identity:"positive")
        let seed=try EquilibriumContinuationState(model:model,constraints:nil,branch:positive,position:[1],parameter:0,time:0,limits:EquilibriumFixtures.limits())
        let inputs=[EquilibriumLoadCase(identity:"initial",parameter:0,time:0),EquilibriumLoadCase(identity:"loaded",parameter:0.05,time:1),EquilibriumLoadCase(identity:"unloaded",parameter:0,time:2)]
        var w=try EquilibriumFixtures.work();let report=try service.sweep(model,constraints:nil,branch:positive,state:seed,cases:inputs,policy:EquilibriumFixtures.policy(),work:&w)
        #expect(report.acceptedCases==3);#expect(report.continuation.position[0]>0.99);#expect(report.continuation.position[0]<1.01)
        #expect(seed.position==[1]);#expect(seed.accepted==nil)
        if case .accepted(let loaded)=report.cases[1].status { #expect(loaded.position[0]>1);#expect(abs(-loaded.position[0]+loaded.position[0]*loaded.position[0]*loaded.position[0]-0.05)<1e-7) }
        else { Issue.record("Expected loaded branch") }
        let negative=try EquilibriumFixtures.branch(minimum:-2,maximum:-0.5,step:0.3,identity:"negative")
        let negativePoint=try EquilibriumFixtures.solve(model,seed:[-1],branch:negative)
        #expect(negativePoint.position==[-1]);#expect(negativePoint.branch.identity != report.continuation.branch.identity)
        let stationary=try EquilibriumFixtures.solve(model)
        #expect(stationary.position==[0]);#expect(stationary.energy>negativePoint.energy)
    }
    @Test func mixedSweepKeepsFailedSeedAndRecordsPerCaseProvenance()throws {
        let model=try EquilibriumFixtures.springs([1]);let branch=try EquilibriumFixtures.branch(step:0.2)
        let state=try EquilibriumContinuationState(model:model,constraints:nil,branch:branch,position:[0],parameter:0,time:0,limits:EquilibriumFixtures.limits())
        let inputs=[EquilibriumLoadCase(identity:"first",parameter:0.1,time:0),EquilibriumLoadCase(identity:"step-failure",parameter:0.8,time:1),EquilibriumLoadCase(identity:"domain-failure",parameter:200,time:2),EquilibriumLoadCase(identity:"resume",parameter:0.2,time:3)]
        var w=try EquilibriumFixtures.work();let report=try ReferenceEquilibriumContinuation().sweep(model,constraints:nil,branch:branch,state:state,cases:inputs,policy:EquilibriumFixtures.policy(),work:&w)
        #expect(report.acceptedCases==2);#expect(report.attemptedCases==3)
        #expect(abs(report.continuation.position[0]-0.2)<1e-8)
        #expect(report.cases[2].suppliedSeed==report.cases[3].suppliedSeed)
        if case .failed(.branchExceeded)=report.cases[1].status {} else { Issue.record("Expected step failure") }
        if case .failed(.outsideDomain)=report.cases[2].status {} else { Issue.record("Expected domain failure") }
        #expect(report.cases[3].stamp==model.chart.stamp);#expect(report.cases[3].branchIdentity==branch.identity)
    }
    @Test func restoredValueHistoryAgreesAndStaleLawOrBranchIsRejected()throws {
        let model=try EquilibriumFixtures.springs([10]);let branch=try EquilibriumFixtures.branch();let policy=try EquilibriumFixtures.policy()
        let state=try EquilibriumContinuationState(model:model,constraints:nil,branch:branch,position:[0],parameter:0,time:0,limits:EquilibriumFixtures.limits())
        let cases=[EquilibriumLoadCase(identity:"load",parameter:1,time:0)];let service=ReferenceEquilibriumContinuation()
        var w=try EquilibriumFixtures.work();let first=try service.sweep(model,constraints:nil,branch:branch,state:state,cases:cases,policy:policy,work:&w)
        var secondWork=try EquilibriumFixtures.work();let restored=first.continuation
        let replay=try service.sweep(model,constraints:nil,branch:branch,state:restored,cases:cases,policy:policy,work:&secondWork)
        #expect(replay.continuation.position==first.continuation.position);#expect(state.position==[0])
        let changed=try EquilibriumFixtures.springs([11])
        do { _=try service.sweep(changed,constraints:nil,branch:branch,state:restored,cases:cases,policy:policy,work:&w);Issue.record("Expected stale law") }
        catch { if case .staleBinding=error {} else { Issue.record("Wrong stale failure") } }
        let changedBranch=try EquilibriumFixtures.branch(identity:"other")
        do { _=try service.sweep(model,constraints:nil,branch:changedBranch,state:restored,cases:cases,policy:policy,work:&w);Issue.record("Expected stale branch") }
        catch { if case .staleBinding=error {} else { Issue.record("Wrong branch failure") } }
    }
    @Test func exhaustedIterationBudgetStopsRemainingCases()throws {
        let model=try EquilibriumFixtures.springs([10]);let branch=try EquilibriumFixtures.branch();let policy=try EquilibriumFixtures.policy(iterations:0)
        let state=try EquilibriumContinuationState(model:model,constraints:nil,branch:branch,position:[0],parameter:0,time:0,limits:EquilibriumFixtures.limits())
        let cases=[EquilibriumLoadCase(identity:"fails",parameter:1,time:0),EquilibriumLoadCase(identity:"unattempted",parameter:0,time:1)]
        var w=try EquilibriumFixtures.work();let report=try ReferenceEquilibriumContinuation().sweep(model,constraints:nil,branch:branch,state:state,cases:cases,policy:policy,work:&w)
        #expect(report.acceptedCases==0);#expect(report.attemptedCases==1);#expect(report.continuation.position==state.position)
        if case .failed(.nonlinear(let failure))=report.cases[0].status { #expect(failure.termination == .resourceLimit) } else { Issue.record("Expected iteration budget failure") }
        if case .notAttempted=report.cases[1].status {} else { Issue.record("Expected stop") }
    }
    @Test func unavailablePostSolveConstraintFailureWorkStopsSweep()throws {
        let model=try EquilibriumFixtures.springs([10]);let c=try EquilibriumFixtures.constraints(model,rows:[[1],[2]],constants:[0,-1]);let branch=try EquilibriumFixtures.branch()
        let state=try EquilibriumContinuationState(model:model,constraints:c,branch:branch,position:[0],parameter:0,time:0,limits:EquilibriumFixtures.limits())
        var w=try EquilibriumFixtures.work();let report=try ReferenceEquilibriumContinuation().sweep(model,constraints:c,branch:branch,state:state,cases:[EquilibriumLoadCase(identity:"bad-support",parameter:0,time:0),EquilibriumLoadCase(identity:"stop",parameter:0,time:0)],policy:EquilibriumFixtures.policy(),work:&w)
        if case .failed(.constraintFailure(.inconsistent,let unknown))=report.cases[0].status { #expect(unknown) } else { Issue.record("Expected unavailable work failure") }
        if case .notAttempted=report.cases[1].status {} else { Issue.record("Expected stop") }
    }
    @Test func capacityAndMalformedRetainedMetadataRejectBeforeTraversal()throws {
        let model=try EquilibriumFixtures.springs([10]);let branch=try EquilibriumFixtures.branch();let state=try EquilibriumContinuationState(model:model,constraints:nil,branch:branch,position:[0],parameter:0,time:0,limits:EquilibriumFixtures.limits())
        let cases=(0..<17).map { EquilibriumLoadCase(identity:"case-\($0)",parameter:0,time:0) };let policy=try EquilibriumFixtures.policy();var w=try EquilibriumFixtures.work()
        do { _=try ReferenceEquilibriumContinuation().sweep(model,constraints:nil,branch:branch,state:state,cases:cases,policy:policy,work:&w);Issue.record("Expected case capacity") }
        catch { if case .capacityExceeded=error {} else { Issue.record("Wrong capacity failure") } }
        let valid=try EquilibriumFixtures.constraints(model,rows:[[1]])
        let row=QuadraticConstraint(id:100,constant:0,linear:[1],hessian:[0,0],timeLinear:0,timeQuadratic:0,mixedTime:[0])
        let malformed=try QuadraticConstraintSystem(layout:valid.system.layout,rows:[row],minimumPosition:[-3],maximumPosition:[3],minimumTime:-10,maximumTime:10)
        let constraints=StaticConstraints(system:malformed,policy:valid.policy,responseBudget:valid.responseBudget)
        let malformedState=try EquilibriumContinuationState(model:model,constraints:constraints,branch:branch,position:[0],parameter:0,time:0,limits:EquilibriumFixtures.limits())
        do { _=try ReferenceEquilibriumContinuation().sweep(model,constraints:constraints,branch:branch,state:malformedState,cases:[],policy:policy,work:&w);Issue.record("Expected malformed matrix dimensions") }
        catch { if case .invalidInput=error {} else { Issue.record("Wrong dimension failure") } }
    }

}
