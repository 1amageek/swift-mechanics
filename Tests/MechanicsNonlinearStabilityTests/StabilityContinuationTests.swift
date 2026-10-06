import SwiftMechanics
import Testing

@Suite struct StabilityContinuationTests {
    @Test func symmetricBifurcationAndOriginalPhysicalEvidence() throws {
        var work=try StabilityFixtures.work();let source=try StabilityFixtures.source(work:&work),policy=try StabilityFixtures.policy()
        let solver:any NonlinearStabilityContinuing=ReferenceNonlinearStabilityContinuation()
        let u=0.67
        var state=try solver.start(source,position:StabilityFixtures.seed(u:u,v:0),parameter:u+u*u*u,
            initialDirection:[-1,-1,-2,-(1+3*u*u)],policy:policy,work:&work)
        StabilityPhysicalOracle.check(state.point)
        #expect(state.point.classification == .positive)
        var bracket:(NonlinearStabilityState,NonlinearStabilityState)?
        for _ in 0..<20 {
            let prior=state;state=try solver.advance(source,state:state,arcStep:0.06,policy:policy,work:&work)
            StabilityPhysicalOracle.check(state.point)
            #expect(state.point.work==work)
            if prior.point.stiffnessEigenvalues[0]*state.point.stiffnessEigenvalues[0]<0 { bracket=(prior,state);break }
        }
        let endpoints=try #require(bracket)
        let critical=try solver.critical(source,left:endpoints.0,right:endpoints.1,policy:policy,work:&work)
        StabilityPhysicalOracle.check(critical.point)
        #expect(critical.kind == .bifurcationCandidate)
        #expect(abs(critical.point.position[0]-1/Double(3).squareRoot())<1e-7)
        #expect(abs(critical.point.parameter-4/(3*Double(3).squareRoot()))<1e-7)
        #expect(abs(critical.normalizedLoadProjection)<1e-5)
        #expect(critical.bracketWidth<=policy.criticalWidth)
        #expect(critical.work==work)
        #expect(work.operations>0 && work.iterations>0)
    }
    @Test(arguments:[1.0,-1.0]) func secondaryBranchesPassPhysicalLoadFold(sign: Double) throws {
        var work=try StabilityFixtures.work();let source=try StabilityFixtures.source(work:&work),policy=try StabilityFixtures.policy()
        let solver:any NonlinearStabilityContinuing=ReferenceNonlinearStabilityContinuation()
        let u=0.30,v=sign*(1-3*u*u).squareRoot()
        var state=try solver.start(source,position:StabilityFixtures.seed(u:u,v:v),parameter:4*u-8*u*u*u,
            initialDirection:StabilityFixtures.direction(u:u,sign:sign),policy:policy,work:&work)
        var bracket:(NonlinearStabilityState,NonlinearStabilityState)?;var sawLoadDecrease=false
        for _ in 0..<35 {
            let prior=state;state=try solver.advance(source,state:state,arcStep:0.04,policy:policy,work:&work)
            StabilityPhysicalOracle.check(state.point)
            let actualU=(state.point.position[0]+state.point.position[1])/2,actualV=(state.point.position[0]-state.point.position[1])/2
            #expect(sign*actualV>0)
            #expect(abs(actualV*actualV-(1-3*actualU*actualU))<1e-7)
            #expect(abs(state.point.parameter-(4*actualU-8*actualU*actualU*actualU))<1e-7)
            if prior.point.stiffnessEigenvalues[0]*state.point.stiffnessEigenvalues[0]<0 { bracket=(prior,state) }
            if state.point.parameter<prior.point.parameter { sawLoadDecrease=true }
            if actualU>0.48 { break }
        }
        #expect(sawLoadDecrease)
        #expect(state.point.classification == .negative)
        let endpoints=try #require(bracket)
        let critical=try solver.critical(source,left:endpoints.0,right:endpoints.1,policy:policy,work:&work)
        StabilityPhysicalOracle.check(critical.point)
        #expect(critical.kind == .limitPointCandidate)
        let actualU=(critical.point.position[0]+critical.point.position[1])/2
        #expect(abs(actualU-1/Double(6).squareRoot())<1e-7)
        #expect(abs(critical.point.parameter-8/(3*Double(6).squareRoot()))<1e-7)
        #expect(abs(critical.normalizedLoadProjection)>1e-5)
    }
    @Test func stepRefinementPreservesOriginalBranch() throws {
        var work=try StabilityFixtures.work();let source=try StabilityFixtures.source(work:&work),policy=try StabilityFixtures.policy()
        let solver=ReferenceNonlinearStabilityContinuation(),u=0.3,v=(1-3*u*u).squareRoot()
        let initial=try solver.start(source,position:StabilityFixtures.seed(u:u,v:v),parameter:4*u-8*u*u*u,initialDirection:StabilityFixtures.direction(u:u,sign:1),policy:policy,work:&work)
        let coarse=try solver.advance(source,state:initial,arcStep:0.12,policy:policy,work:&work)
        var fine=initial
        for _ in 0..<4 { fine=try solver.advance(source,state:fine,arcStep:0.03,policy:policy,work:&work) }
        StabilityPhysicalOracle.check(coarse.point);StabilityPhysicalOracle.check(fine.point)
        let uc=(coarse.point.position[0]+coarse.point.position[1])/2,uf=(fine.point.position[0]+fine.point.position[1])/2
        #expect(abs(uc-uf)<0.001)
        #expect(coarse.arcDistance>0 && fine.arcDistance>0)
    }
    @Test func genericFourCoordinatesNonzeroCubicAndUnequalMass() throws {
        var work=try StabilityFixtures.work()
        let source=try StabilityFixtures.source(linear:[2,4,7,11],cubic:[1,2,3,4],load:[1,-2,0.5,3],rows:[[1,2,-1,0]],masses:[1,2,3,4],work:&work)
        let policy=try StabilityFixtures.policy(4),solver=ReferenceNonlinearStabilityContinuation()
        var state=try solver.start(source,position:[0,0,0,0],parameter:0,initialDirection:[0,0,0,0,1],policy:policy,work:&work)
        for _ in 0..<5 {
            state=try solver.advance(source,state:state,arcStep:0.05,policy:policy,work:&work)
            let q=state.point.position,p=state.point.parameter,mu=state.point.rowMultipliers[0]
            let a=[2.0,4,7,11],b=[1.0,2,3,4],load=[1.0,-2,0.5,3],row=[1.0,2,-1,0],mass=[1.0,2,3,4]
            #expect(abs(q[0]+2*q[1]-q[2])<1e-8)
            for i in 0..<4 { #expect(abs(a[i]*q[i]+b[i]*q[i]*q[i]*q[i]-p*load[i]+row[i]*mu)<1e-8) }
            #expect(state.point.stiffnessEigenvalues.count==3)
            for mode in 0..<3 {
                let phi=Array(state.point.modes[mode*4..<mode*4+4]),lambda=state.point.stiffnessEigenvalues[mode]
                var norm=0.0;for i in 0..<4 { norm+=mass[i]*phi[i]*phi[i] }
                #expect(abs(norm-1)<1e-7)
                #expect(abs(phi[0]+2*phi[1]-phi[2])<1e-7)
                let r=(0..<4).map{(a[$0]+3*b[$0]*q[$0]*q[$0]-lambda*mass[$0])*phi[$0]}
                // Independent null directions (-2,1,0,0), (1,0,1,0), (0,0,0,1).
                #expect(abs(-2*r[0]+r[1])<1e-7);#expect(abs(r[0]+r[2])<1e-7);#expect(abs(r[3])<1e-7)
            }
        }
    }
}
