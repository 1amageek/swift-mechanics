import SwiftMechanics
import Testing

@Suite struct EquilibriumLinearizationTests {
    @Test func pendulumUsesActualMassAndOriginalDirectionalStiffness()throws {
        let model=try EquilibriumFixtures.pendulum();let point=try EquilibriumFixtures.solve(model)
        let compiled=try EquilibriumFixtures.compiled(angle:true);let mass=try EquilibriumFixtures.dynamics(compiled,q:point.position)
        let reduction=EquilibriumReduction(freeCoordinates:1,basis:[1],damping:[0.9],outputRows:1,outputMap:[1],outputDimensions:[.angle])
        var w=try EquilibriumFixtures.work();let value=try ReferenceEquilibriumLinearizer().linearize(point,compiled:compiled,dynamics:mass,reduction:reduction,policy:EquilibriumFixtures.linearPolicy(),work:&w)
        #expect(abs(value.reducedMass[0]-3)<1e-10)
        #expect(abs(value.reducedStiffness[0]-20)<1e-10)
        #expect(value.stateMatrix[0]==0);#expect(value.stateMatrix[1]==1)
        #expect(abs(value.stateMatrix[2]+20.0/3)<1e-9);#expect(abs(value.stateMatrix[3]+0.3)<1e-9)
        #expect(abs(value.inputMatrix[1]-1.0/3)<1e-9)
        #expect(value.outputMatrix==[1,0])
        #expect(value.maximumDirectionalError<1e-5);#expect(value.maximumInertialError<1e-9)
    }
    @Test func suppliedConstrainedBasisProducesIndependentAnalyticReduction()throws {
        let model=try EquilibriumFixtures.springs([10,20],c:[5,7],l:[2,4]);let constraints=try EquilibriumFixtures.constraints(model,rows:[[1,1],[2,2]])
        let point=try EquilibriumFixtures.solve(model,constraints:constraints)
        #expect(abs(point.position[0]+2.0/30)<1e-8);#expect(abs(point.position[1]-2.0/30)<1e-8)
        let compiled=try EquilibriumFixtures.compiled(2);let mass=try EquilibriumFixtures.dynamics(compiled,q:point.position)
        let reduction=EquilibriumReduction(freeCoordinates:1,basis:[1,-1],damping:[1,0,0,2],outputRows:1,outputMap:[1,2],outputDimensions:[.length])
        var w=try EquilibriumFixtures.work();let value=try ReferenceEquilibriumLinearizer().linearize(point,compiled:compiled,dynamics:mass,reduction:reduction,policy:EquilibriumFixtures.linearPolicy(2),work:&w)
        #expect(abs(value.reducedMass[0]-5)<1e-10);#expect(abs(value.reducedStiffness[0]-30)<1e-10)
        #expect(abs(value.reducedDamping[0]-3)<1e-10)
        #expect(abs(value.stateMatrix[2]+6)<1e-9);#expect(abs(value.inputMatrix[1]+0.4)<1e-9)
        #expect(value.outputMatrix==[-1,0])
    }
    @Test func basisThatViolatesAnyRetainedConstraintFails()throws {
        let model=try EquilibriumFixtures.springs([10,20]);let c=try EquilibriumFixtures.constraints(model,rows:[[1,1]])
        let point=try EquilibriumFixtures.solve(model,constraints:c);let compiled=try EquilibriumFixtures.compiled(2);let mass=try EquilibriumFixtures.dynamics(compiled,q:point.position)
        let reduction=EquilibriumReduction(freeCoordinates:1,basis:[1,1],damping:[0,0,0,0],outputRows:1,outputMap:[1,0],outputDimensions:[.length]);var w=try EquilibriumFixtures.work();let policy=try EquilibriumFixtures.linearPolicy(2)
        do { _=try ReferenceEquilibriumLinearizer().linearize(point,compiled:compiled,dynamics:mass,reduction:reduction,policy:policy,work:&w);Issue.record("Expected original constraint direction failure") }
        catch { if case .invalidReduction=error {} else { Issue.record("Wrong reduction failure") } }
    }
    @Test func zeroBasisMustFailActualSPDRankAdmission()throws {
        let model=try EquilibriumFixtures.springs([10]);let point=try EquilibriumFixtures.solve(model);let compiled=try EquilibriumFixtures.compiled();let mass=try EquilibriumFixtures.dynamics(compiled,q:point.position)
        let reduction=EquilibriumReduction(freeCoordinates:1,basis:[0],damping:[0],outputRows:1,outputMap:[1],outputDimensions:[.length]);var w=try EquilibriumFixtures.work();let policy=try EquilibriumFixtures.linearPolicy()
        do { _=try ReferenceEquilibriumLinearizer().linearize(point,compiled:compiled,dynamics:mass,reduction:reduction,policy:policy,work:&w);Issue.record("Expected SPD failure even zero RHS") }
        catch { if case .linear(.nonPositiveDefinite,let unknown)=error { #expect(unknown) } else { Issue.record("Wrong rank failure") } }
    }
    @Test func originalGradientProbeRejectsFalseAnalyticTangentAtZeroResidual()throws {
        let point=try EquilibriumFixtures.solve(EquilibriumFixtures.pendulum());let compiled=try EquilibriumFixtures.compiled(angle:true);let mass=try EquilibriumFixtures.dynamics(compiled,q:point.position)
        let reduction=EquilibriumReduction(freeCoordinates:1,basis:[1],damping:[0],outputRows:1,outputMap:[1],outputDimensions:[.angle]);var w=try EquilibriumFixtures.work();let policy=try EquilibriumFixtures.linearPolicy()
        do { _=try ReferenceEquilibriumLinearizer(forces:IncorrectTangentForceEvaluator()).linearize(point,compiled:compiled,dynamics:mass,reduction:reduction,policy:policy,work:&w);Issue.record("Expected original derivative rejection") }
        catch { if case .derivativeMismatch(let i,let e)=error { #expect(i==0);#expect(e>19) } else { Issue.record("Wrong derivative failure") } }
    }
    @Test func movedOperatingPointAndNonzeroVelocityCannotReuseMassBinding()throws {
        let point=try EquilibriumFixtures.solve(EquilibriumFixtures.pendulum());let compiled=try EquilibriumFixtures.compiled(angle:true)
        let reduction=EquilibriumReduction(freeCoordinates:1,basis:[1],damping:[0],outputRows:1,outputMap:[1],outputDimensions:[.angle]);let policy=try EquilibriumFixtures.linearPolicy()
        for mass in [try EquilibriumFixtures.dynamics(compiled,q:[0.2]),try EquilibriumFixtures.dynamics(compiled,q:[0],velocity:[0.1])] {
            var w=try EquilibriumFixtures.work()
            do { _=try ReferenceEquilibriumLinearizer().linearize(point,compiled:compiled,dynamics:mass,reduction:reduction,policy:policy,work:&w);Issue.record("Expected operating point mismatch") }
            catch { if case .operatingPointMismatch=error {} else { Issue.record("Wrong binding failure") } }
        }
    }
    @Test func probeOutsideCalibratedEnvelopeAndStorageBudgetFailExplicitly()throws {
        let model=try EquilibriumFixtures.springs([10],c:[30],l:[0]);let point=try EquilibriumFixtures.solve(model,seed:[3]);let compiled=try EquilibriumFixtures.compiled();let mass=try EquilibriumFixtures.dynamics(compiled,q:point.position)
        let reduction=EquilibriumReduction(freeCoordinates:1,basis:[1],damping:[0],outputRows:1,outputMap:[1],outputDimensions:[.length]);let policy=try EquilibriumFixtures.linearPolicy()
        var w=try EquilibriumFixtures.work()
        do { _=try ReferenceEquilibriumLinearizer().linearize(point,compiled:compiled,dynamics:mass,reduction:reduction,policy:policy,work:&w);Issue.record("Expected domain failure during original probe") }
        catch { if case .force(.outsideDomain)=error {} else { Issue.record("Wrong probe domain failure") } }
        w=try EquilibriumFixtures.work(storage:0)
        do { _=try ReferenceEquilibriumLinearizer().linearize(point,compiled:compiled,dynamics:mass,reduction:reduction,policy:policy,work:&w);Issue.record("Expected storage limit") }
        catch { if case .numerical(.resourceLimit)=error {} else { Issue.record("Wrong storage failure") } }
    }

    @Test func cancellationAfterFinalActualInputSolvePreventsPublication() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else {
            Issue.record("The cancellation owner requires the declared Synchronization availability.")
            return
        }
        let point = try EquilibriumFixtures.solve(EquilibriumFixtures.pendulum())
        let compiled = try EquilibriumFixtures.compiled(angle: true)
        let mass = try EquilibriumFixtures.dynamics(compiled, q: point.position)
        let reduction = EquilibriumReduction(freeCoordinates: 1, basis: [1], damping: [0.9], outputRows: 1, outputMap: [1], outputDimensions: [.angle])
        let actual = FinalSolveCancellingLinearSolver()
        let original = try EquilibriumFixtures.linearPolicy()
        let policy = try EquilibriumLinearizationPolicy(limits: original.limits, capability: original.capability, tolerance: original.tolerance,
            displacementProbe: original.displacementProbe, parameterProbe: original.parameterProbe,
            derivativeAbsoluteTolerances: original.derivativeAbsoluteTolerances, derivativeRelativeTolerance: original.derivativeRelativeTolerance,
            constraintTolerance: original.constraintTolerance, inertialAbsoluteTolerances: original.inertialAbsoluteTolerances,
            isCancelled: { actual.isCancelled })
        let service: any EquilibriumLinearizing = ReferenceEquilibriumLinearizer(linear: actual)
        var work = try EquilibriumFixtures.work()
        do {
            _ = try service.linearize(point, compiled: compiled, dynamics: mass, reduction: reduction, policy: policy, work: &work)
            Issue.record("A cancelled final solve may not publish a linearization.")
        } catch {
            if case .cancelled = error {} else { Issue.record("Expected the final publication cancellation failure.") }
        }
        #expect(actual.completedCalls == 4)
        #expect(actual.isCancelled)
        #expect(work.operations > 0)
        #expect(point.position == [0])
    }

}
