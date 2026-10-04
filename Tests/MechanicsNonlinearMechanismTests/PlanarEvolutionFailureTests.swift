import SwiftMechanics
import Testing

@Suite struct PlanarEvolutionFailureTests {
    @Test(.timeLimit(.minutes(1))) func wrongActualSourceAndLateEnergyFailureKeepAcceptedHistoryRandomAndKnownPrefix() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try GeometricEvolutionFourBar(planar:true)
            for fault in [PlanarEvolutionFaultKernel.Fault.wrongSource,.resetSuccess,.resetFailure,.cancel] {
                let equation=try PlanarEvolutionFixtures.equation(fixture,kernel:PlanarEvolutionFaultKernel(model:fixture.model,fault:fault))
                let (session,continuation)=try PlanarEvolutionFixtures.session(equation);defer { _=session.shutdown() }
                let evolution=ProjectedNonlinearMechanismEvolution(),prefix=try evolution.advance(session,equations:equation,continuation:continuation,to:0.05).accepted
                let saved=try session.checkpoint(codec:NativeRuntimeCheckpointCodec())
                do throws(NonlinearMechanismFailure) { _=try evolution.advance(session,equations:equation,continuation:continuation,to:0.1);Issue.record("Planar faulty supplier published") }
                catch {
                    #expect(error.lastAccepted == prefix);#expect(error.work.supplierArithmeticCharged > 0)
                    switch fault {
                    case .wrongSource: #expect(error.cause.code == .invalidState)
                    case .resetSuccess,.resetFailure: #expect(error.cause.code == .invalidOwnerAccess);#expect(error.work.failedSupplierWorkUnavailable)
                    case .cancel: #expect(error.cause.code == .cancelled);#expect(!error.work.failedSupplierWorkUnavailable)
                    }
                }
                #expect(session.snapshot() == prefix);#expect(try session.checkpoint(codec:NativeRuntimeCheckpointCodec()) == saved)
            }
        }
    }
    @Test(.timeLimit(.minutes(1))) func inconsistentInitialLoopAndPublicationCapacityAreExplicitRefusals() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let fixture=try GeometricEvolutionFourBar(planar:true),equation=try PlanarEvolutionFixtures.equation(fixture)
            let initial=fixture.model.descriptor.initialState
            var q=initial.q;q[fixture.couplerIndex]+=0.01
            let physical=try KinematicState(revision:initial.revision,time:0,q:q,v:initial.v,acceleration:initial.acceleration)
            let (session,_)=try PlanarEvolutionFixtures.session(equation);defer { _=session.shutdown() }
            let prefix=session.snapshot()
            do throws(RuntimeFailure) {
                _=try session.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) in
                    var work=NumericalWork(budget:equation.publicationBudget)
                    try equation.validateInitial(time:physical.time,point:physical.q+physical.v,work:&work,control:control)
                    return .reject
                }
                Issue.record("Inconsistent planar initial loop admitted")
            } catch { #expect(error.code == .invalidState) }
            #expect(session.snapshot() == prefix)
            let tiny=try NumericalBudget(scalarStorage:1,arithmeticOperations:100,iterations:1),admission=try NonlinearMechanismFixtures.admission()
            do throws(RuntimeFailure) {
                _=try GeometricMechanismEquation(identity:equation.descriptor.identity,geometry:equation.geometry,drive:equation.drive,policy:equation.policy,
                    projection:equation.projection,maximumStageChartCorrection:0.01,publicationBudget:tiny,admission:admission,maximumIdentityBytes:50000,
                    physicalKernel:RigidEquationKernel(),physicalSolver:MassWeightedMechanismSolver(physicalDynamics:DenseRigidDynamics(physicalEquations:RigidEquationKernel()),physicalEquations:RigidEquationKernel()))
                Issue.record("Planar publication capacity bypassed")
            } catch { #expect(error.code == .capacityExceeded) }
        }
    }
}
