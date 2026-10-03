import Testing
import CMechanicsMath
import MechanicsNumerics
import MechanicsFluids
struct PlanarEvolutionTests {
    @Test func actualTwoDimensionalTaylorGreenMeshRefinement() throws {
        let exactAmplitude=0.9900498337491681,T=0.05,steps=10
        var previous=Double.infinity
        for n in [8,12,16] {
            let g=try PlanarFixtures.grid(nx:n,ny:n),initial=try PlanarFixtures.vortex(g),source=try PlanarFixtures.source()
            var state=initial,work=try PlanarFixtures.work(),error=0.0
            let policy=try PlanarFixtures.policy()
            for _ in 0..<steps {
                let result=try PlanarFixtures.solver().step(state:state,source:source,duration:T/Double(steps),policy:policy,work:&work)
                #expect(result.evidence.viscousLossPower > 0);#expect(result.evidence.donorLossPower > 0)
                #expect(result.evidence.maximumAdvectiveFactor > 0);#expect(result.evidence.maximumCourantFactor <= 0.9)
                #expect(result.projection.kineticAfter <= result.evidence.kineticBefore+1e-9)
                #expect(abs(result.evidence.energyDefect) < 1e-8);#expect(result.projection.maximumDivergence < 1e-9)
                state=result.state
            }
            for k in 0..<g.count { error += (state.u[k]-exactAmplitude*initial.u[k])*(state.u[k]-exactAmplitude*initial.u[k])+(state.v[k]-exactAmplitude*initial.v[k])*(state.v[k]-exactAmplitude*initial.v[k]) }
            error=(error/Double(2*g.count)).squareRoot()
            #expect(error < previous);previous=error
            #expect(state.sequence == UInt64(steps));#expect(abs(state.time-T) < 1e-14)
            #expect(state.grid.totalMass == initial.grid.totalMass)
        }
        #expect(previous < 0.02)
    }
    @Test func shearExactDiscreteViscousAmplificationAndTimeRefinement() throws {
        let g=try PlanarFixtures.grid(nx:4,ny:8),dt=0.02,T=0.2,source=try PlanarFixtures.source()
        var u=[Double](repeating:0,count:g.count)
        for j in 0..<g.ny { for i in 0..<g.nx { u[j*g.nx+i]=sm_sin((Double(j)+0.5)*g.dy) } }
        let old=try PlanarFixtures.state(g,u:u,v:[Double](repeating:0,count:g.count)),p=try PlanarFixtures.policy()
        var w=try PlanarFixtures.work();let one=try PlanarFixtures.solver().step(state:old,source:source,duration:dt,policy:p,work:&w)
        let lambda=4*g.nu*sm_sin(PlanarFixtures.pi/Double(g.ny))*sm_sin(PlanarFixtures.pi/Double(g.ny))/(g.dy*g.dy)
        for k in 0..<g.count { #expect(abs(one.state.u[k]-(1-lambda*dt)*u[k]) < 1e-10);#expect(abs(one.state.v[k]) < 1e-10) }
        #expect(one.evidence.donorLossPower < 1e-12)
        // Independent exp(-lambda*T) evaluated with a bounded convergent Taylor series.
        var exact=1.0,term=1.0;for k in 1...24 { term *= -lambda*T/Double(k);exact += term }
        var previous=Double.infinity
        for steps in [1,2,4,8] {
            var state=old,work=try PlanarFixtures.work()
            for _ in 0..<steps { state=try PlanarFixtures.solver().step(state:state,source:source,duration:T/Double(steps),policy:p,work:&work).state }
            let error=abs(state.u[0]/u[0]-exact);#expect(error < previous/1.8);previous=error
        }
    }
    @Test func periodicMassMomentumAndExternalWork() throws {
        let g=try PlanarFixtures.grid(nx:4,ny:5),n=g.count,dt=0.05,source=try PlanarFixtures.source(0.1,-0.2)
        let old=try PlanarFixtures.state(g,u:[Double](repeating:0.5,count:n),v:[Double](repeating:-0.25,count:n))
        var w=try PlanarFixtures.work();let result=try PlanarFixtures.solver().step(state:old,source:source,duration:dt,policy:PlanarFixtures.policy(),work:&w)
        var deltaPX=0.0,deltaPY=0.0
        for k in 0..<n { #expect(abs(result.state.u[k]-0.505) < 1e-12);#expect(abs(result.state.v[k]+0.26) < 1e-12)
            deltaPX += g.cellMass*(result.state.u[k]-old.u[k]);deltaPY += g.cellMass*(result.state.v[k]-old.v[k])
        }
        #expect(abs(deltaPX-g.totalMass*dt*source.accelerationX) < 1e-10)
        #expect(abs(deltaPY-g.totalMass*dt*source.accelerationY) < 1e-10)
        #expect(result.state.source == source);#expect(result.state.grid.totalMass == old.grid.totalMass)
        #expect(result.evidence.viscousLossPower < 1e-12);#expect(result.evidence.donorLossPower < 1e-12)
        #expect(abs(result.projection.kineticAfter-result.evidence.kineticBefore-dt*result.evidence.sourcePower-result.evidence.explicitTimeInjection) < 1e-9)
    }
}
