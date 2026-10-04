import SwiftMechanics
import Testing

@Suite struct StaticEquilibriumTests {
    @Test func hangingLoadAndSpringEnergyUseOriginalSIUnits()throws {
        let model=try EquilibriumFixtures.springs([100],c:[49],l:[0])
        let value=try EquilibriumFixtures.solve(model)
        #expect(abs(value.position[0]-0.49)<1e-9)
        #expect(abs(value.energy+12.005)<1e-8)
        #expect(abs(100*value.position[0]-49)<1e-7)
        #expect(value.generalizedReaction == [0])
        #expect(value.work.operations>0)
    }
    @Test func scaledCoordinateAndEnergyDoNotAlterPhysicalBalance()throws {
        let chart=try StaticCoordinateChart(stamp:ModelStamp(identity:"equilibrium-fixture",revision:1),frame:EquilibriumFixtures.id(.frame,"world"),coordinateIDs:[1],joints:[EquilibriumFixtures.id(.joint,"joint-0")],dimensions:[.length],scales:[0.01],limits:EquilibriumFixtures.limits())
        let m=try StaticForceModel(identity:"scaled",chart:chart,law:.springs(linear:[200],cubic:[0],constant:[0],loadDirection:[4]),minimumPosition:[-3],maximumPosition:[3],parameterIdentity:"p",minimumParameter:-10,maximumParameter:10,energyScale:2,limits:EquilibriumFixtures.limits())
        let e=try EquilibriumFixtures.solve(m,parameter:2)
        #expect(abs(e.position[0]-0.04)<1e-10)
        #expect(abs(200*e.position[0]-8)<1e-7)
    }
    @Test func redundantSupportsPublishAmbiguousRepresentative()throws {
        let m=try EquilibriumFixtures.springs([10],c:[5],l:[0]);let c=try EquilibriumFixtures.constraints(m,rows:[[1],[2]])
        let e=try EquilibriumFixtures.solve(m,constraints:c)
        #expect(e.rank.reactionNullity==1)
        #expect(e.rowMultipliers[1]==0)
        #expect(abs(e.rowMultipliers[0]-5)<1e-8)
        #expect(abs(e.generalizedReaction[0]+5)<1e-8)
        #expect(e.originalConstraintResidual.allSatisfy{abs($0)<1e-8})
        #expect(abs(e.physicalGradient[0]-e.generalizedReaction[0])<1e-7)
    }
    @Test func uniqueReactionPolicyRejectsRedundancy()throws {
        let m=try EquilibriumFixtures.springs([10]);let c=try EquilibriumFixtures.constraints(m,rows:[[1],[2]])
        do { _=try EquilibriumFixtures.solve(m,constraints:c,policy:EquilibriumFixtures.policy(reaction:.requireUnique));Issue.record("Expected ambiguity") }
        catch let e as EquilibriumError { if case .reactionAmbiguity(let nullity)=e { #expect(nullity==1) } else { Issue.record("Wrong failure") } }
    }
    @Test func everyRetainedConstraintRejectsInconsistentDependentSupport()throws {
        let m=try EquilibriumFixtures.springs([10]);let c=try EquilibriumFixtures.constraints(m,rows:[[1],[2]],constants:[0,-1])
        do { _=try EquilibriumFixtures.solve(m,constraints:c);Issue.record("Expected inconsistent retained row") }
        catch let e as EquilibriumError { if case .constraintFailure(.inconsistent(let id,_),let unknown)=e { #expect(id==101);#expect(unknown) } else { Issue.record("Wrong retained-row failure") } }
    }
    @Test func originalPhysicalResidualRejectsPrematureNumericalAcceptance()throws {
        let m=try EquilibriumFixtures.springs([10],c:[5],energy:1e15)
        do { _=try EquilibriumFixtures.solve(m);Issue.record("Numerical residual may not accept physical imbalance") }
        catch let e as EquilibriumError { if case .originalBalance(let i,let residual)=e { #expect(i==0);#expect(residual == -5) } else { Issue.record("Wrong failure") } }
    }
    @Test func incorrectForceTangentIsRejectedByActualNonlinearDirectionalProbe()throws {
        let m=try EquilibriumFixtures.springs([10],c:[5]);var w=try EquilibriumFixtures.work()
        do { _=try ReferenceEquilibriumSolver(forces:IncorrectTangentForceEvaluator()).solve(m,constraints:nil,initialPosition:[0],parameter:0,time:0,branch:EquilibriumFixtures.branch(),policy:EquilibriumFixtures.policy(),work:&w);Issue.record("Expected derivative rejection") }
        catch let e as EquilibriumError { if case .nonlinear(let f)=e { if case .invalidDerivative=f.cause {} else { Issue.record("Wrong numerical failure") } } else { Issue.record("Wrong failure") } }
    }
    @Test func nonAffineConstraintHasExplicitUnsupportedAdmission()throws {
        let m=try EquilibriumFixtures.springs([10]);let c=try EquilibriumFixtures.constraints(m,rows:[[1]],nonlinearHessian:true)
        do { _=try EquilibriumFixtures.solve(m,constraints:c);Issue.record("Expected unsupported constraint") }
        catch let e as EquilibriumError { if case .unsupportedDomain=e {} else { Issue.record("Wrong failure") } }
    }
    @Test func callerBudgetCancellationAndClosedDomainAreFailures()throws {
        let m=try EquilibriumFixtures.springs([10],c:[5]);let solver=ReferenceEquilibriumSolver()
        var w=try EquilibriumFixtures.work(operations:0)
        do { _=try solver.solve(m,constraints:nil,initialPosition:[0],parameter:0,time:0,branch:EquilibriumFixtures.branch(),policy:EquilibriumFixtures.policy(),work:&w);Issue.record("Expected work budget failure") }
        catch let e as EquilibriumError { if case .nonlinear(let f)=e { #expect(f.termination == .resourceLimit) } else if case .numerical(let n)=e { #expect(n.termination == .resourceLimit) } else { Issue.record("Wrong failure") } }
        w=try EquilibriumFixtures.work()
        do { _=try solver.solve(m,constraints:nil,initialPosition:[0],parameter:0,time:0,branch:EquilibriumFixtures.branch(),policy:EquilibriumFixtures.policy(cancelled:true),work:&w);Issue.record("Expected cancellation") }
        catch let e as EquilibriumError { if case .cancelled=e {} else { Issue.record("Wrong failure") } }
        do { _=try EquilibriumFixtures.solve(m,seed:[4]);Issue.record("Expected closed domain rejection") }
        catch let e as EquilibriumError { if case .outsideDomain=e {} else { Issue.record("Wrong failure") } }
    }
    @Test func finiteCoefficientsOverflowIsNotSuccess()throws {
        let m=try EquilibriumFixtures.springs([Double.greatestFiniteMagnitude],b:[Double.greatestFiniteMagnitude])
        var w=try EquilibriumFixtures.work()
        do { _=try ReferenceStaticForceEvaluator<Double>().gradient(m,point:[2],parameter:0,coordinate:0,work:&w);Issue.record("Expected nonfinite arithmetic") }
        catch let e as StaticForceError { #expect(e == .nonFiniteResult) }
    }
}
