import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ConstraintFailureTests {
    @Test func contradictoryRowsAndForbiddenAmbiguityFailExplicitly() throws {
        let duplicate=try ConstraintFixtures.system([ConstraintFixtures.affine(),ConstraintFixtures.affine(id:2)])
        var work=try ConstraintFixtures.work()
        do { _=try WeightedConstraintAssembler().assemble(duplicate,initialPosition:[0,0],time:0,policy:ConstraintFixtures.policy(rank:.requireIndependentRows),work:&work); Issue.record("Expected ambiguity.") }
        catch let error as ConstraintError { if case .rankAmbiguity(let rank,let rows)=error { #expect(rank == 1); #expect(rows == 2) } else { Issue.record("Wrong failure: \(error)") } }
        let contradictory=try ConstraintFixtures.system([ConstraintFixtures.affine(),ConstraintFixtures.affine(id:2,constant:-2)])
        work=try ConstraintFixtures.work()
        do { _=try WeightedConstraintAssembler().assemble(contradictory,initialPosition:[0,0],time:0,policy:ConstraintFixtures.policy(),work:&work); Issue.record("Expected original contradiction.") }
        catch let error as ConstraintError { if case .inconsistent(let id,let value)=error { #expect(id == 2); #expect(value > 0.9) } else { Issue.record("Wrong failure: \(error)") } }
    }
    @Test func prematureNumericalAcceptanceAndExcessCorrectionAreRejected() throws {
        let system=try ConstraintFixtures.system([ConstraintFixtures.affine()])
        var work=try ConstraintFixtures.work()
        do { _=try WeightedConstraintAssembler().assemble(system,initialPosition:[0,0],time:0,policy:ConstraintFixtures.policy(internalTolerance:10),work:&work); Issue.record("Expected original rejection.") }
        catch let error as ConstraintError { if case .inconsistent=error {} else { Issue.record("Wrong failure: \(error)") } }
        work=try ConstraintFixtures.work()
        do { _=try WeightedConstraintAssembler().assemble(system,initialPosition:[0,0],time:0,policy:ConstraintFixtures.policy(correction:0.1),work:&work); Issue.record("Expected correction limit.") }
        catch let error as ConstraintError { if case .correctionExceeded=error {} else { Issue.record("Wrong failure: \(error)") } }
    }
    @Test func capacitiesDomainsMalformedDerivativeAndCancellationFailBeforePublication() throws {
        let system=try ConstraintFixtures.system([ConstraintFixtures.affine()]), evaluator: any ConstraintEvaluating=QuadraticConstraintEvaluator()
        var work=try ConstraintFixtures.work()
        do { _=try evaluator.evaluate(system,position:[20,0],velocity:[0,0],time:0,policy:ConstraintFixtures.evaluation(),work:&work); Issue.record("Expected domain failure.") } catch let error as ConstraintError { if case .outsideDomain=error {} else { Issue.record("Wrong failure.") } }
        let bad=QuadraticConstraint(id:1,constant:0,linear:[0,0],hessian:[1,2,0,1],timeLinear:0,timeQuadratic:0,mixedTime:[0,0])
        work=try ConstraintFixtures.work()
        do { _=try evaluator.evaluate(ConstraintFixtures.system([bad]),position:[0,0],velocity:[0,0],time:0,policy:ConstraintFixtures.evaluation(),work:&work); Issue.record("Expected nonsymmetric derivative failure.") } catch let error as ConstraintError { if case .invalidInput=error {} else { Issue.record("Wrong failure.") } }
        work=try ConstraintFixtures.work()
        do { _=try WeightedConstraintAssembler().assemble(system,initialPosition:[0,0],time:0,policy:ConstraintFixtures.policy(cancelled:{true}),work:&work); Issue.record("Expected cancellation.") } catch let error as ConstraintError { if case .cancelled=error {} else { Issue.record("Wrong failure.") } }
        let tiny=try ConstraintEvaluationPolicy(maximumCoordinates:1,maximumRows:1,expectedLayoutRevision:7)
        work=try ConstraintFixtures.work()
        do { _=try evaluator.evaluate(system,position:[0,0],velocity:[0,0],time:0,policy:tiny,work:&work); Issue.record("Expected capacity.") } catch let error as ConstraintError { if case .capacityExceeded=error {} else { Issue.record("Wrong failure.") } }
    }
    @Test func outerAndNestedResourceLimitsRetainActualFailures() throws {
        let system=try ConstraintFixtures.system([ConstraintFixtures.affine()])
        for smallStorage in [false,true] {
            var work=try ConstraintFixtures.work(storage:smallStorage ? 1 : 100_000,operations:smallStorage ? 1000 : 0)
            do { _=try WeightedConstraintAssembler().assemble(system,initialPosition:[0,0],time:0,policy:ConstraintFixtures.policy(),work:&work); Issue.record("Expected outer resource limit.") }
            catch let error as ConstraintError { if case .numerical(.resourceLimit)=error {} else { Issue.record("Wrong failure: \(error)") } }
        }
        for fill in [false,true] {
            var work=try ConstraintFixtures.work()
            do { _=try WeightedConstraintAssembler().assemble(system,initialPosition:[0,0],time:0,policy:ConstraintFixtures.policy(nonlinearIterations:fill ? 1000 : 0,maximumFactorEntries:fill ? 0 : 1000),work:&work); Issue.record("Expected supplier resource limit.") }
            catch let error as ConstraintError { if case .nonlinear(let failure)=error { #expect(failure.lastResidual != nil); #expect(failure.work.operations > 0) } else { Issue.record("Wrong failure: \(error)") } }
        }
        let sample=VelocityConstraintSample(layout:try ConstraintFixtures.layout(),rowIDs:[1],rows:[1,1],drift:[0],accelerationBias:[0],isIntegrable:true)
        var work=try ConstraintFixtures.work(), linear=try ConstraintFixtures.work(storage:1)
        do { _=try WeightedConstraintAssembler().projectVelocity(sample,initialVelocity:[1,0],policy:ConstraintFixtures.policy(),work:&work,linearWork:&linear); Issue.record("Expected linear resource limit.") }
        catch let error as ConstraintError { if case .linear(.resourceLimit,let unavailable)=error { #expect(unavailable) } else { Issue.record("Wrong failure: \(error)") } }
    }
    @Test func unsupportedWrapImpactAndJointChartAreTyped() throws {
        let joint=try JointManifold(.revolute(axis:.unitZ)), evaluator: any ScalarJointPortEvaluating=ScalarJointPortEvaluator()
        var work=try ConstraintFixtures.work()
        do { _=try evaluator.limits(joint,position:0,velocity:0,lower:-1,upper:1,mode:.rowsOnly,impact:.impact(restitution:0.5),wrap:.unwrapped,policy:ConstraintFixtures.evaluation(),work:&work); Issue.record("Expected impact failure.") }
        catch let error as ConstraintError { if case .unsupportedDomain=error {} else { Issue.record("Wrong failure.") } }
        work=try ConstraintFixtures.work()
        do { _=try evaluator.limits(joint,position:0,velocity:0,lower:-1,upper:1,mode:.rowsOnly,impact:.none,wrap:.periodic(period:6.28),policy:ConstraintFixtures.evaluation(),work:&work); Issue.record("Expected wrap failure.") }
        catch let error as ConstraintError { if case .unsupportedDomain=error {} else { Issue.record("Wrong failure.") } }
        work=try ConstraintFixtures.work()
        do { _=try evaluator.limits(JointManifold(.spherical),position:0,velocity:0,lower:-1,upper:1,mode:.rowsOnly,impact:.none,wrap:.unwrapped,policy:ConstraintFixtures.evaluation(),work:&work); Issue.record("Expected chart failure.") }
        catch let error as ConstraintError { if case .unsupportedDomain=error {} else { Issue.record("Wrong failure.") } }
    }
}
