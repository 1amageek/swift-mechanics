import Testing
import CMechanicsMath
import MechanicsNumerics
import MechanicsFluids
struct PressureProjectionTests {
    @Test func nonSquareMACPotentialRecoveryIncludesGaugeRowAndSolenoidalField() throws {
        let g=try PlanarFixtures.grid(nx:5,ny:7,lengthX:3,lengthY:2.5,rho:2),dt=0.02
        var phi=[Double](repeating:0,count:g.count),psi=[Double](repeating:0,count:g.count)
        for j in 0..<g.ny { for i in 0..<g.nx { let k=j*g.nx+i
            phi[k]=0.3*sm_cos(2*PlanarFixtures.pi*(Double(i)+0.5)/Double(g.nx))+0.2*sm_cos(2*PlanarFixtures.pi*(Double(j)+0.5)/Double(g.ny))
            psi[k]=0.1*sm_sin(2*PlanarFixtures.pi*Double(i)/Double(g.nx))*sm_sin(2*PlanarFixtures.pi*Double(j)/Double(g.ny))
        } }
        var u=[Double](repeating:0,count:g.count),v=[Double](repeating:0,count:g.count),solU=u,solV=v
        for j in 0..<g.ny { for i in 0..<g.nx { let k=j*g.nx+i,l=j*g.nx+(i+g.nx-1)%g.nx,b=((j+g.ny-1)%g.ny)*g.nx+i
            let r=j*g.nx+(i+1)%g.nx,t=((j+1)%g.ny)*g.nx+i
            solU[k]=(psi[t]-psi[k])/g.dy+0.4;solV[k] = -(psi[r]-psi[k])/g.dx-0.2
            u[k]=solU[k]+dt/g.density*(phi[k]-phi[l])/g.dx
            v[k]=solV[k]+dt/g.density*(phi[k]-phi[b])/g.dy
        } }
        let old=try PlanarFixtures.state(g,u:u,v:v);#expect(abs(PlanarFixtures.divergence(old,at:0)) > 1e-4)
        var work=try PlanarFixtures.work();let result=try PlanarFixtures.solver().project(state:old,duration:dt,policy:PlanarFixtures.policy(),work:&work)
        #expect(result.state.pressure[0] == 0);#expect(result.state.time == old.time);#expect(result.state.sequence == old.sequence)
        for k in 0..<g.count {
            #expect(abs(result.state.u[k]-solU[k]) < 1e-9);#expect(abs(result.state.v[k]-solV[k]) < 1e-9)
            #expect(abs(result.state.pressure[k]-(phi[k]-phi[0])) < 1e-8)
            #expect(abs(PlanarFixtures.divergence(result.state,at:k)) < 1e-9)
            let i=k%g.nx,j=k/g.nx,l=j*g.nx+(i+g.nx-1)%g.nx,r=j*g.nx+(i+1)%g.nx
            let b=((j+g.ny-1)%g.ny)*g.nx+i,t=((j+1)%g.ny)*g.nx+i,p=result.state.pressure
            let lap=(p[l]-2*p[k]+p[r])/(g.dx*g.dx)+(p[b]-2*p[k]+p[t])/(g.dy*g.dy)
            #expect(abs(lap-g.density/dt*PlanarFixtures.divergence(old,at:k)) < 1e-8)
        }
        #expect(abs(result.evidence.meanMomentumResidualX) < 1e-9);#expect(abs(result.evidence.meanMomentumResidualY) < 1e-9)
        #expect(result.evidence.projectionLoss > 0);#expect(abs(result.evidence.energyDefect) < 1e-9)
        #expect(old.u == u);#expect(old.v == v)
    }
    @Test func pinnedPressureGaugeAndAlreadySolenoidalProjection() throws {
        let g=try PlanarFixtures.grid(),old=try PlanarFixtures.vortex(g)
        var work=try PlanarFixtures.work();let result=try PlanarFixtures.solver().project(state:old,duration:0.01,policy:PlanarFixtures.policy(),work:&work)
        for k in 0..<g.count { #expect(abs(result.state.u[k]-old.u[k]) < 1e-10);#expect(abs(result.state.v[k]-old.v[k]) < 1e-10) }
        #expect(result.state.pressure[0] == 0);#expect(result.evidence.projectionLoss < 1e-16)
        // Gauge is a pinned value; pressure mean is deliberately not constrained.
    }
    @Test func wrongActualEquationCannotBypassOriginalPressureAndDivergence() throws {
        let g=try PlanarFixtures.grid(nx:4,ny:4),n=g.count
        var u=[Double](repeating:0,count:n),v=[Double](repeating:0,count:n);u[1]=1;v[2] = -0.5
        let state=try PlanarFixtures.state(g,u:u,v:v),p=try PlanarFixtures.policy()
        var w=try PlanarFixtures.work();let solver:any PlanarFlowOperating=ReferencePlanarFlowSolver(linear:PlanarWrongEquationSolver())
        PlanarFixtures.failure(.originalResidual) { () throws(PlanarFluidError) in _=try solver.project(state:state,duration:0.01,policy:p,work:&w) }
    }
}
