import Testing
import MechanicsCore
import MechanicsModel
import MechanicsNumerics
import MechanicsFluids
struct PlanarAdmissionTests {
    @Test func layoutMaterialsGaugeFiniteAndLimits() throws {
        #expect(throws:PlanarFluidError.self) { _=try PlanarFixtures.grid(nx:2) }
        #expect(throws:PlanarFluidError.self) { _=try PlanarFixtures.grid(nx:100,ny:100) }
        #expect(throws:PlanarFluidError.self) { _=try PlanarFixtures.grid(mu:0) }
        #expect(throws:PlanarFluidError.self) { _=try PlanarFixtures.grid(rho:-1) }
        #expect(throws:PlanarFluidError.self) { _=try PlanarFixtures.grid(lengthX:Double.leastNonzeroMagnitude) }
        let limits=try PlanarLimits(maximumCells:9,maximumMetadataBytes:1,maximumSpeed:1,maximumPressure:1,maximumAcceleration:1,maximumStep:1)
        let frame=try EntityID(kind:.frame,key:"fixed-world"),provenance=try SourceProvenance(source:"input",revision:1)
        PlanarFixtures.failure(.capacity) { () throws(PlanarFluidError) in _=try PlanarGrid(id:"oversized",revision:1,frame:frame,source:provenance,nx:3,ny:3,lengthX:1,lengthY:1,depth:1,density:1,viscosity:1,limits:limits) }
        let g=try PlanarFixtures.grid(),source=try PlanarFixtures.source(),zeros=[Double](repeating:0,count:g.count)
        PlanarFixtures.failure(.staleBinding) { () throws(PlanarFluidError) in _=try PlanarState(grid:g,time:0,sequence:0,u:[],v:zeros,pressure:zeros,source:source) }
        var pressure=zeros;pressure[0]=1
        PlanarFixtures.failure(.invalidInput) { () throws(PlanarFluidError) in _=try PlanarState(grid:g,time:0,sequence:0,u:zeros,v:zeros,pressure:pressure,source:source) }
        var nan=zeros;nan[3] = .nan
        PlanarFixtures.failure(.nonfinite) { () throws(PlanarFluidError) in _=try PlanarState(grid:g,time:0,sequence:0,u:nan,v:zeros,pressure:zeros,source:source) }
        let large=try PlanarFixtures.source(11)
        PlanarFixtures.failure(.domain) { () throws(PlanarFluidError) in _=try PlanarState(grid:g,time:0,sequence:0,u:zeros,v:zeros,pressure:zeros,source:large) }
    }
    @Test func outgoingAndViscousStabilityAndOriginalInitialDivergence() throws {
        let g=try PlanarFixtures.grid(),source=try PlanarFixtures.source(),p=try PlanarFixtures.policy(),solver=PlanarFixtures.solver()
        let fast=try PlanarFixtures.state(g,u:[Double](repeating:3,count:g.count),v:[Double](repeating:0,count:g.count))
        var w=try PlanarFixtures.work()
        PlanarFixtures.failure(.stability) { () throws(PlanarFluidError) in _=try solver.step(state:fast,source:source,duration:0.8,policy:p,work:&w) }
        let viscous=try PlanarFixtures.grid(mu:10),rest=try PlanarFixtures.state(viscous,u:[Double](repeating:0,count:viscous.count),v:[Double](repeating:0,count:viscous.count))
        PlanarFixtures.failure(.stability) { () throws(PlanarFluidError) in _=try solver.step(state:rest,source:source,duration:0.1,policy:p,work:&w) }
        var u=[Double](repeating:0,count:g.count);u[0]=1
        let incompatible=try PlanarFixtures.state(g,u:u,v:[Double](repeating:0,count:g.count))
        PlanarFixtures.failure(.originalResidual) { () throws(PlanarFluidError) in _=try solver.step(state:incompatible,source:source,duration:0.001,policy:p,work:&w) }
        PlanarFixtures.failure(.domain) { () throws(PlanarFluidError) in _=try solver.project(state:fast,duration:0,policy:p,work:&w) }
        let exhausted=try PlanarState(grid:g,time:0,sequence:UInt64.max,u:fast.u,v:fast.v,pressure:fast.pressure,source:source)
        PlanarFixtures.failure(.capacity) { () throws(PlanarFluidError) in _=try solver.step(state:exhausted,source:source,duration:0.001,policy:p,work:&w) }
        #expect(fast.time == 0);#expect(fast.sequence == 0)
    }
    @Test func pressureBudgetsAndActualSupplierIterationFailure() throws {
        let g=try PlanarFixtures.grid(nx:4,ny:4),old=try PlanarFixtures.vortex(g),p=try PlanarFixtures.policy(),solver=PlanarFixtures.solver()
        var zeroStorage=NumericalWork(budget:try NumericalBudget(scalarStorage:0,arithmeticOperations:100000,iterations:1000))
        do throws(PlanarFluidError) { _=try solver.project(state:old,duration:0.01,policy:p,work:&zeroStorage);Issue.record("Expected storage rejection") }
        catch { if case .numerical(.resourceLimit(resource:.scalarStorage,limit:0),failedSupplierWorkUnavailable:false)=error {} else { Issue.record("Incorrect storage failure work authority") } }
        var noIterations=NumericalWork(budget:try NumericalBudget(scalarStorage:100000,arithmeticOperations:100000,iterations:0))
        do throws(PlanarFluidError) { _=try solver.project(state:old,duration:0.01,policy:p,work:&noIterations);Issue.record("Expected real factorization iteration failure") }
        catch { if case .numerical(.resourceLimit(resource:.iterations,limit:0),failedSupplierWorkUnavailable:true)=error {} else { Issue.record("Incorrect supplier failure work authority") } }
        let cancelled=try PlanarFixtures.policy(cancel:{true});var w=try PlanarFixtures.work()
        PlanarFixtures.failure(.cancelled) { () throws(PlanarFluidError) in _=try solver.project(state:old,duration:0.01,policy:cancelled,work:&w) }
        #expect(old.time == 0)
    }
}
