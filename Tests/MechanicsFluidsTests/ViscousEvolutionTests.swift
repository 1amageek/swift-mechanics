import SwiftMechanics
import Testing
#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("No admitted scalar mathematics platform module is available.")
#endif
struct ViscousEvolutionTests {
    @Test func sineDecayTimeAndMeshRefinementWithActualEvolution() throws {
        let pi=3.14159265358979323846,T=1/(pi*pi),expected=0.36787944117144233
        var previous=Double.infinity
        for steps in [1,4,16,64] {
            let c=try FluidFixtures.channel(cells:32),b=try FluidFixtures.boundary()
            var initial=[Double](repeating:0,count:32)
            for i in initial.indices { initial[i]=sin(pi*(Double(i)+0.5)/32) }
            var state=try FluidFixtures.state(channel:c,boundary:b,velocities:initial)
            var work=try FluidFixtures.work()
            for _ in 0..<steps {
                let result=try FluidFixtures.solver().step(state:state,boundary:b,duration:T/Double(steps),policy:FluidFixtures.policy(),work:&work)
                #expect(result.balance.numericalDissipation > 0)
                #expect(result.balance.viscousPower > 0)
                let energyDefect=try #require(result.balance.energyDefect)
                #expect(energyDefect.magnitude < 1e-9)
                state=result.state
            }
            let amplitude=state.velocities[15]/initial[15],error=abs(amplitude-expected)
            #expect(error < previous); previous=error
            #expect(state.sequence == UInt64(steps)); #expect(abs(state.time-T) < 1e-14)
            #expect(initial[15] > state.velocities[15])
        }
        #expect(previous < 0.004)
        var meshPrevious=Double.infinity
        for n in [4,8,16] {
            let c=try FluidFixtures.channel(cells:n),b=try FluidFixtures.boundary()
            var u=[Double](repeating:0,count:n); for i in u.indices { u[i]=sin(pi*(Double(i)+0.5)/Double(n)) }
            let old=try FluidFixtures.state(channel:c,boundary:b,velocities:u),dt=0.001
            var w=try FluidFixtures.work(); let result=try FluidFixtures.solver().step(state:old,boundary:b,duration:dt,policy:FluidFixtures.policy(),work:&w)
            // Independent continuum BE amplitude isolates spatial discretization error.
            let error=abs(result.state.velocities[0]/u[0]-1/(1+pi*pi*dt))
            #expect(error < meshPrevious/3.9); meshPrevious=error
        }
    }
    @Test func changedWallLoadDoesWorkWithoutResetAndInputRemainsOwned() throws {
        let c=try FluidFixtures.channel(cells:4),b=try FluidFixtures.boundary(),old=try FluidFixtures.state(channel:c,boundary:b)
        let moved=try FluidFixtures.boundary(upper:2,gradient:-1),dt=0.1
        var w=try FluidFixtures.work(); let result=try FluidFixtures.solver().step(state:old,boundary:moved,duration:dt,policy:FluidFixtures.policy(),work:&w)
        #expect(old.time == 0); #expect(old.sequence == 0); #expect(old.velocities == [0,0,0,0])
        #expect(result.state.boundary == moved); #expect(result.balance.boundaryPower > 0)
        #expect(abs(result.balance.kineticEnergy+dt*result.balance.viscousPower+result.balance.numericalDissipation-dt*(result.balance.sourcePower+result.balance.boundaryPower)) < 1e-10)
        let g=c.conductance,m=c.cellMass,f=c.wallArea*c.spacing
        for i in 0..<4 {
            let left=i == 0 ? 2*g*result.state.velocities[i] : g*(result.state.velocities[i]-result.state.velocities[i-1])
            let right=i == 3 ? 2*g*(2-result.state.velocities[i]) : g*(result.state.velocities[i+1]-result.state.velocities[i])
            #expect(abs(m*result.state.velocities[i]/dt-(right-left)-f) < 1e-10)
        }
    }
    @Test func budgetsCancellationAndOriginalAuthority() throws {
        let c=try FluidFixtures.channel(),b=try FluidFixtures.boundary(gradient:-2),old=try FluidFixtures.state(channel:c,boundary:b)
        let p=try FluidFixtures.policy(); var tiny=NumericalWork(budget:try NumericalBudget(scalarStorage:0,arithmeticOperations:1000,iterations:10))
        #expect(throws:FluidError.self) { _=try FluidFixtures.solver().step(state:old,boundary:b,duration:0.1,policy:p,work:&tiny) }
        var enoughStorage=NumericalWork(budget:try NumericalBudget(scalarStorage:10000,arithmeticOperations:0,iterations:10))
        #expect(throws:FluidError.self) { _=try FluidFixtures.solver().steady(state:old,boundary:b,policy:p,work:&enoughStorage) }
        var w=try FluidFixtures.work(); let cancelled=try FluidFixtures.policy(cancel:{true})
        FluidFixtures.failure(.cancelled) { () throws(FluidError) in _=try FluidFixtures.solver().steady(state:old,boundary:b,policy:cancelled,work:&w) }
        let wrong=ReferenceViscousChannelSolver(linear:ZeroForcingFluidSolver(),fields:ReferenceFluidFieldBuilder())
        FluidFixtures.failure(.originalResidual) { () throws(FluidError) in _=try wrong.steady(state:old,boundary:b,policy:p,work:&w) }
        #expect(old.sequence == 0)
    }

    @Test func stationaryWallLargeStepDissipatesAndSupplierIterationFailureIsExplicit() throws {
        let c=try FluidFixtures.channel(cells:4),b=try FluidFixtures.boundary(),old=try FluidFixtures.state(channel:c,boundary:b,velocities:[1,2,3,4])
        var w=try FluidFixtures.work(); let p=try FluidFixtures.policy()
        let result=try FluidFixtures.solver().step(state:old,boundary:b,duration:10,policy:p,work:&w)
        let originalKinetic=0.5*c.cellMass*(1+4+9+16)
        #expect(result.balance.kineticEnergy < originalKinetic)
        #expect(result.balance.sourcePower == 0);#expect(result.balance.boundaryPower == 0)
        #expect(abs(result.balance.kineticEnergy-originalKinetic+10*result.balance.viscousPower+result.balance.numericalDissipation) < 1e-9)
        var noIterations=NumericalWork(budget:try NumericalBudget(scalarStorage:10000,arithmeticOperations:100000,iterations:0))
        do throws(FluidError) { _=try FluidFixtures.solver().step(state:old,boundary:b,duration:0.1,policy:p,work:&noIterations);Issue.record("Expected actual supplier iteration limit") }
        catch { if case .numerical(.resourceLimit(resource:.iterations,limit:0),failedSupplierWorkUnavailable:true)=error {} else { Issue.record("Incorrect unavailable supplier failure") } }
    }
}
