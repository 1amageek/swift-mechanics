import SwiftMechanics

public enum SpatialProjectionQualificationCases {
    private static func check(_ condition: Bool, _ message: String) throws {
        guard condition else { throw SpatialProjectionQualificationError.assertion(message) }
    }
    private static func close(_ actual: Double, _ expected: Double, _ message: String) throws {
        try check(actual.isFinite && expected.isFinite && abs(actual-expected) <= 2e-9+2e-9*abs(expected), message)
    }
    private static func refuse(_ select: (SpatialFluidError) -> Bool, _ label: String,
                              _ call: () throws(SpatialFluidError) -> Void) throws {
        do { try call() } catch { try check(select(error),label+" wrong typed failure");return }
        throw SpatialProjectionQualificationError.unexpectedSuccess(label)
    }
    private static func numericalRefusal(_ select: (NumericalError) -> Bool, _ label: String,
                                        _ call: () throws(NumericalError) -> Void) throws {
        do { try call() } catch { try check(select(error),label+" wrong numerical failure");return }
        throw SpatialProjectionQualificationError.unexpectedSuccess(label)
    }
    private static var service: any SpatialFlowOperating {
        ReferenceSpatialFlowSolver(pressureSolver: MatrixFreeSpatialPressureSolver())
    }
    public static func potentialSolenoidalProjection() throws {
        let f=try SpatialProjectionQualificationFixture(grid: SpatialProjectionQualificationFixture.makeGrid())
        let original=f.potentialAndSolenoidal(),dt=0.02
        var fields=original.solenoidal
        for k in 0..<f.grid.nz { for j in 0..<f.grid.ny { for i in 0..<f.grid.nx {
            for axis in 0..<3 { fields[axis][f.index(i,j,k)] += dt/f.grid.density*f.gradient(original.potential,axis,i,j,k) }
        } } }
        let state=try f.state(fields),unchanged=state,policy=try SpatialProjectionQualificationFixture.policy()
        var work=try NumericalWork(budget: SpatialProjectionQualificationFixture.budget())
        let result=try service.project(state: state,duration: dt,policy: policy,work: &work)
        let output=[result.state.u,result.state.v,result.state.w]
        var loss=0.0,pressureMean=0.0
        for k in 0..<f.grid.nz { for j in 0..<f.grid.ny { for i in 0..<f.grid.nx {
            let row=f.index(i,j,k)
            try close(result.state.pressure[row],original.potential[row],"original3D potential/gauge")
            try close(f.divergence(output,i,j,k),0,"every corrected3D cell divergence")
            try close(-f.laplacian(result.state.pressure,i,j,k),-f.grid.density/dt*f.divergence(fields,i,j,k),"original pressure RHS")
            pressureMean += result.state.pressure[row]
            for axis in 0..<3 {
                try close(output[axis][row],original.solenoidal[axis][row],"original solenoidal face")
                let delta=output[axis][row]-fields[axis][row]
                loss += f.grid.cellMass*delta*delta/2
                try close(delta/dt+f.gradient(result.state.pressure,axis,i,j,k)/f.grid.density,0,"original correction equation")
            }
        } } }
        try close(pressureMean/Double(f.grid.count),0,"mean pressure gauge")
        try close(result.evidence.projectionLoss,loss,"full projection loss")
        try close(f.energy(output)-f.energy(fields)+loss,0,"orthogonal projection energy")
        for axis in 0..<3 { try close(f.momentum(output)[axis],f.momentum(fields)[axis],"all3 periodic momenta") }
        try close(f.grid.totalMass,2*f.grid.lengthX*f.grid.lengthY*f.grid.lengthZ,"SI periodic mass")
        try check(state == unchanged && result.state.time == state.time && result.state.sequence == state.sequence && result.state.source == state.source,"project-only authority")
    }
    public static func originalPressureEquation() throws {
        let f=try SpatialProjectionQualificationFixture(grid: SpatialProjectionQualificationFixture.makeGrid())
        let phi=f.potentialAndSolenoidal().potential
        var rhs=[Double](repeating: 0,count: f.grid.count)
        for k in 0..<f.grid.nz { for j in 0..<f.grid.ny { for i in 0..<f.grid.nx { rhs[f.index(i,j,k)] = -f.laplacian(phi,i,j,k) } } }
        let solver: any SpatialPressureSolving=MatrixFreeSpatialPressureSolver(),policy=try SpatialProjectionQualificationFixture.policy()
        let result=try solver.solve(grid: f.grid,rightHandSide: rhs,tolerance: policy.linearTolerance,
            budget: SpatialProjectionQualificationFixture.budget(),isCancelled: { false })
        for i in phi.indices { try close(result.pressure[i],phi[i],"direct real CG3D original potential") }
        try check(result.originalResidual <= 1e-8 && result.work.iterations > 0,"CG original residual not iteration-only")
        let bad=[Double](repeating: 1,count: f.grid.count),budget=try SpatialProjectionQualificationFixture.budget()
        try numericalRefusal({ if case .nonConvergence = $0 { true } else { false } },"incompatible periodic RHS") { () throws(NumericalError) in
            _ = try solver.solve(grid: f.grid,rightHandSide: bad,tolerance: policy.linearTolerance,budget: budget,isCancelled: { false })
        }
    }
    public static func thirdAxisShear() throws {
        let f=try SpatialProjectionQualificationFixture(grid: SpatialProjectionQualificationFixture.makeGrid(nx: 3,ny: 4,nz: 4))
        let profile=[0.1,0,-0.1,0],dt=0.01,policy=try SpatialProjectionQualificationFixture.policy()
        for component in [0,2] {
            var fields=(0..<3).map { _ in [Double](repeating: 0,count: f.grid.count) }
            for k in 0..<f.grid.nz { for j in 0..<f.grid.ny { for i in 0..<f.grid.nx {
                fields[component][f.index(i,j,k)]=profile[component == 0 ? k : j]
            } } }
            let state=try f.state(fields),source=try SpatialProjectionQualificationFixture.source()
            var work=try NumericalWork(budget: SpatialProjectionQualificationFixture.budget())
            let result=try service.step(state: state,source: source,duration: dt,policy: policy,work: &work)
            let output=[result.state.u,result.state.v,result.state.w],factor=1-2*f.grid.nu*dt
            var expectedLoss=0.0,expectedInjection=0.0
            for row in 0..<f.grid.count {
                for axis in 0..<3 { try close(output[axis][row],fields[axis][row]*(axis == component ? factor : 1),"z variation / third component shear") }
                expectedLoss += 2*f.grid.cellMass*f.grid.nu*fields[component][row]*fields[component][row]
                expectedInjection += f.grid.cellMass*dt*dt*4*f.grid.nu*f.grid.nu*fields[component][row]*fields[component][row]/2
            }
            try close(result.evidence.viscousLossPower,expectedLoss,"one-mode actual shear viscous loss")
            try close(result.evidence.explicitTimeInjection,expectedInjection,"one-mode explicit injection")
            try close(result.evidence.donorLossPower,0,"crossflow absent donor")
            try close(f.energy(output)-f.energy(fields),-dt*expectedLoss+expectedInjection,"original third-axis energy")
            try check(result.evidence.viscousLossPower > 0 && f.energy(output) < f.energy(fields),"positive viscosity physical decay")
        }
    }
    public static func donorMomentumEnergy() throws {
        let f=try SpatialProjectionQualificationFixture(grid: SpatialProjectionQualificationFixture.makeGrid())
        let fields=f.potentialAndSolenoidal().solenoidal,source=try SpatialProjectionQualificationFixture.source(0.02,-0.01,0.03),dt=0.01
        let state=try f.state(fields),oracle=f.predictor(state,source: source,dt: dt),policy=try SpatialProjectionQualificationFixture.policy()
        var work=try NumericalWork(budget: SpatialProjectionQualificationFixture.budget())
        let result=try service.step(state: state,source: source,duration: dt,policy: policy,work: &work),output=[result.state.u,result.state.v,result.state.w]
        for k in 0..<f.grid.nz { for j in 0..<f.grid.ny { for i in 0..<f.grid.nx {
            let row=f.index(i,j,k)
            try close(f.divergence(output,i,j,k),0,"full3D step original divergence")
            try close(-f.laplacian(result.state.pressure,i,j,k),-f.grid.density/dt*f.divergence(oracle.fields,i,j,k),"independent donor predictor original RHS")
            for axis in 0..<3 {
                try close((output[axis][row]-fields[axis][row])/dt-oracle.rates[axis][row]+f.gradient(result.state.pressure,axis,i,j,k)/f.grid.density,0,"independent face flux full momentum")
            }
        } } }
        try close(result.evidence.viscousLossPower,oracle.viscousPower,"independent full3D viscous work")
        try close(result.evidence.donorLossPower,oracle.donorPower,"independent full3D donor work")
        try close(result.evidence.sourcePower,oracle.sourcePower,"independent source power")
        try close(result.evidence.divergenceTransportPower,oracle.divergencePower,"original dual divergence work")
        try close(result.evidence.explicitTimeInjection,oracle.injection,"independent explicit injection")
        try check(oracle.donorPower > 0 && oracle.viscousPower > 0,"all3 cross-axis nonzero transport")
        let sourceValues=[source.accelerationX,source.accelerationY,source.accelerationZ]
        for axis in 0..<3 { try close(f.momentum(output)[axis]-f.momentum(fields)[axis],f.grid.totalMass*dt*sourceValues[axis],"full3D source momentum") }
        let expected=dt*(oracle.sourcePower-oracle.viscousPower-oracle.donorPower+oracle.divergencePower)+oracle.injection-result.projection.projectionLoss+result.projection.pressureResidualWork
        try close(f.energy(output)-f.energy(fields),expected,"independent complete3D energy balance")
    }
    public static func uniformSourceEvolution() throws {
        let f=try SpatialProjectionQualificationFixture(grid: SpatialProjectionQualificationFixture.makeGrid())
        let values=[0.1,-0.2,0.3],fields=values.map { [Double](repeating: $0,count: f.grid.count) },dt=0.01
        let source=try SpatialProjectionQualificationFixture.source(0.2,0.3,-0.1),accelerations=[0.2,0.3,-0.1],state=try f.state(fields),original=state
        var work=try NumericalWork(budget: SpatialProjectionQualificationFixture.budget())
        let result=try service.step(state: state,source: source,duration: dt,policy: SpatialProjectionQualificationFixture.policy(),work: &work)
        let output=[result.state.u,result.state.v,result.state.w]
        for axis in 0..<3 { for value in output[axis] { try close(value,values[axis]+dt*accelerations[axis],"uniform exact acceleration") }
            try close(f.momentum(output)[axis]-f.momentum(fields)[axis],f.grid.totalMass*dt*accelerations[axis],"uniform three-axis impulse")
        }
        var sourcePower=0.0,injection=0.0
        for axis in 0..<3 { sourcePower += f.grid.totalMass*values[axis]*accelerations[axis];injection += f.grid.totalMass*dt*dt*accelerations[axis]*accelerations[axis]/2 }
        try close(result.evidence.sourcePower,sourcePower,"exact held source work")
        try close(f.energy(output)-f.energy(fields),dt*sourcePower+injection,"uniform exact energy")
        try check(state == original && result.state.time == state.time+dt && result.state.sequence == state.sequence+1 && result.state.source == source,"once-only state/source/time authority")
    }
    public static func domainAndSupplierRefusals() throws {
        let f=try SpatialProjectionQualificationFixture(grid: SpatialProjectionQualificationFixture.makeGrid())
        let policy=try SpatialProjectionQualificationFixture.policy(),dt=0.01
        try refuse({ $0 == .invalidInput },"too few third-axis cells") { () throws(SpatialFluidError) in
            _ = try SpatialGrid(id: f.grid.id, revision: f.grid.revision, frame: f.grid.frame, source: f.grid.source,
                nx: f.grid.nx, ny: f.grid.ny, nz: 2, lengthX: f.grid.lengthX, lengthY: f.grid.lengthY,
                lengthZ: f.grid.lengthZ, density: f.grid.density, viscosity: f.grid.viscosity, limits: f.grid.limits)
        }
        let original=f.potentialAndSolenoidal(),divergent=try f.state([original.potential,original.potential,original.potential])
        var work=try NumericalWork(budget: SpatialProjectionQualificationFixture.budget())
        for mode in [SpatialProjectionQualificationPressureFault.Mode.wrongEquation,.wrongSize,.wrongBudget,.supplierFailure] {
            let injected: any SpatialFlowOperating=ReferenceSpatialFlowSolver(pressureSolver: SpatialProjectionQualificationPressureFault(mode: mode))
            try refuse({ error in
                switch (mode,error) {
                case (.wrongEquation,.originalResidual),(.wrongSize,.staleBinding): true
                case (.wrongBudget,.numerical(.invalidPolicy,true)),(.supplierFailure,.numerical(.nonConvergence,true)): true
                default: false
                }
            },"actual injected pressure supplier") { () throws(SpatialFluidError) in
                _ = try injected.project(state: divergent,duration: dt,policy: policy,work: &work)
            }
        }
        let state=try f.state(original.solenoidal),unchanged=state,source=try SpatialProjectionQualificationFixture.source()
        try refuse({ $0 == .originalResidual },"divergent step entry") { () throws(SpatialFluidError) in
            _ = try service.step(state: divergent,source: source,duration: dt,policy: policy,work: &work)
        }
        try refuse({ $0 == .domain },"zero duration") { () throws(SpatialFluidError) in
            _ = try service.project(state: state,duration: 0,policy: policy,work: &work)
        }
        let exhausted=try f.state(original.solenoidal,sequence: UInt64.max)
        try refuse({ $0 == .capacity },"sequence overflow") { () throws(SpatialFluidError) in
            _ = try service.step(state: exhausted,source: source,duration: dt,policy: policy,work: &work)
        }
        let fast=try f.state((0..<3).map { _ in [Double](repeating: 10,count: f.grid.count) })
        try refuse({ $0 == .stability },"original advective CFL") { () throws(SpatialFluidError) in
            _ = try service.step(state: fast,source: source,duration: 0.1,policy: policy,work: &work)
        }
        let tooLarge=try SpatialProjectionQualificationFixture.source(11)
        try refuse({ $0 == .domain },"source envelope") { () throws(SpatialFluidError) in
            _ = try service.step(state: state,source: tooLarge,duration: dt,policy: policy,work: &work)
        }
        try check(state == unchanged,"refused operation leaves original input")
    }
    @available(macOS 15.0, *)
    public static func workAndCancellation() throws {
        let f=try SpatialProjectionQualificationFixture(grid: SpatialProjectionQualificationFixture.makeGrid(nx: 3,ny: 3,nz: 3)),n=f.grid.count
        let solver: any SpatialPressureSolving=MatrixFreeSpatialPressureSolver(),policy=try SpatialProjectionQualificationFixture.policy()
        let rhs=[Double](repeating: 0,count: n),operations=65*n+2
        let budget=try SpatialProjectionQualificationFixture.budget(storage: 6*n,operations: operations,iterations: 0)
        let counter=SpatialProjectionQualificationCounter(threshold: Int.max)
        let solution=try solver.solve(grid: f.grid,rightHandSide: rhs,tolerance: policy.linearTolerance,budget: budget,isCancelled: { counter.cancelled() })
        try check(solution.work.operations == operations && solution.work.iterations == 0 && solution.work.peakScalarStorage == 6*n,"independently counted zero-RHS pressure ledger")
        try check(counter.calls == 11*n+3,"zero-RHS complete cancellation checkpoint count")
        for limit in [0,4*n-1,operations-1] {
            let limited=try SpatialProjectionQualificationFixture.budget(storage: 6*n,operations: limit,iterations: 0)
            let early=SpatialProjectionQualificationCounter(threshold: Int.max)
            try numericalRefusal({ if case .resourceLimit(.arithmeticOperations,let bound) = $0 { return bound == limit };return false },"zero-RHS operation refusal") { () throws(NumericalError) in
                _ = try solver.solve(grid: f.grid,rightHandSide: rhs,tolerance: policy.linearTolerance,budget: limited,isCancelled: { early.cancelled() })
            }
            if limit < 4*n { try check(early.calls == 1,"initialization refused before vector construction/input traversal") }
        }
        let smallStorage=try SpatialProjectionQualificationFixture.budget(storage: 6*n-1,operations: operations,iterations: 0)
        try numericalRefusal({ if case .resourceLimit(.scalarStorage,_) = $0 { true } else { false } },"original pressure storage refusal") { () throws(NumericalError) in
            _ = try solver.solve(grid: f.grid,rightHandSide: rhs,tolerance: policy.linearTolerance,budget: smallStorage,isCancelled: { false })
        }
        for threshold in [1,2,11*n+3] {
            let cancelled=SpatialProjectionQualificationCounter(threshold: threshold)
            try numericalRefusal({ $0 == .cancelled },"pre/during/final pressure publication cancellation") { () throws(NumericalError) in
                _ = try solver.solve(grid: f.grid,rightHandSide: rhs,tolerance: policy.linearTolerance,budget: budget,isCancelled: { cancelled.cancelled() })
            }
            try check(cancelled.calls == threshold,"exact original cancellation checkpoint")
        }
        let state=try f.state((0..<3).map { _ in rhs }),original=state
        let callerBudget=try SpatialProjectionQualificationFixture.budget(storage: 20*n,operations: 374*n+45,iterations: 0)
        var work=NumericalWork(budget: callerBudget)
        _ = try service.project(state: state,duration: 0.01,policy: policy,work: &work)
        try check(work.operations == 374*n+45 && work.peakScalarStorage == 20*n,"exact zero-RHS caller/supplier accounting")
        let tight=try SpatialProjectionQualificationFixture.budget(storage: 14*n-1)
        var failed=NumericalWork(budget: tight)
        try refuse({ if case .numerical(.resourceLimit(.scalarStorage,_),false) = $0 { true } else { false } },"known caller storage prefix") { () throws(SpatialFluidError) in
            _ = try service.project(state: state,duration: 0.01,policy: policy,work: &failed)
        }
        try check(failed.operations == 0 && failed.peakScalarStorage == 0 && state == original,"no work/reset/success after storage refusal")
    }
    public static func nativeTaskCancellation() async throws {
        let task=Task { () throws -> NumericalWork in
            withUnsafeCurrentTask { $0?.cancel() }
            let f=try SpatialProjectionQualificationFixture(grid: SpatialProjectionQualificationFixture.makeGrid())
            let state=try f.state((0..<3).map { _ in [Double](repeating: 0,count: f.grid.count) })
            var work=try NumericalWork(budget: SpatialProjectionQualificationFixture.budget())
            let policy=try SpatialProjectionQualificationFixture.policy()
            try refuse({ $0 == .cancelled },"actual Native task cancellation") { () throws(SpatialFluidError) in
                _ = try service.project(state: state,duration: 0.01,policy: policy,work: &work)
            }
            return work
        }
        let work=try await task.value
        try check(work.operations == 0 && work.peakScalarStorage == 0 && work.iterations == 0,"actual pre-cancelled operation prefix")
    }
}
