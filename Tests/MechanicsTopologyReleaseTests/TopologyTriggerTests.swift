import SwiftMechanics
import Testing

@Suite struct TopologyTriggerTests {
    @available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
    private func reaction(_ release:SubtreeRelease,impulse:Bool) throws -> ConstrainedMotion {
        let model=release.sourceModel,snapshot=release.sourceSnapshot,n=model.tree.layout.velocityCount
        var inertias:[RigidBodyInertia]=[]
        for body in snapshot.bodies {
            let record=try #require(model.descriptor.bodies.first(where: { $0.id == body.body }))
            guard case .spatial(let spatial)=record else { throw TopologyReleaseFailure.unsupportedDomain }
            inertias.append(try RigidBodyInertia(body:spatial.id,frame:spatial.frame,properties:#require(spatial.inertia).properties))
        }
        var outer=try TopologyFixtures.work(),dyn=try TopologyFixtures.work(),rank=try TopologyFixtures.work(),linear=try TopologyFixtures.work()
        var load=LoadWork(budget:try LoadBudget(maximumWork:0,maximumScalars:0))
        let system=try RigidEquationKernel().assemble(RigidDynamicsInput(snapshot:snapshot,velocity:release.source.state.v,inertias:inertias,gravity:nil),
            admission:TopologyFixtures.admission(),loadWork:&load,work:&dyn)
        let layout=try ConstraintCoordinateLayout(coordinateIDs:[1,2,3],dimensions:[.angle,.angle,.length],scales:[1,1,1],timeScale:1,revision:model.stamp.revision)
        let sample=VelocityConstraintSample(layout:layout,rowIDs:[1],rows:[0,1,0],drift:[0],accelerationBias:[0],isIntegrable:true)
        let capability=LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky)
        let tolerance=try LinearTolerance<Double>(absoluteResidual:1e-10,relativeResidual:1e-10,pivotThreshold:1e-12)
        let nonlinear=try NonlinearPolicy<Double>(strategy:.lineSearch(contraction:0.5,sufficientDecrease:1e-4,minimumFraction:1e-7),capability:capability,tolerance:tolerance,
            referenceScale:1,minimumDirectionNorm:0,derivativeProbeDistance:1e-6,derivativeAbsoluteTolerance:1e-4,derivativeRelativeTolerance:1e-4,
            maximumFactorEntries:1000,estimateCondition:false,budget:TopologyFixtures.work().budget)
        let constraints=try ConstraintSolvePolicy(evaluation:ConstraintEvaluationPolicy(maximumCoordinates:8,maximumRows:8,expectedLayoutRevision:model.stamp.revision),
            diagonalMetric:[Double](repeating:1,count:n),energyScale:1,rankPolicy:.allowRedundancy,rankRelativeTolerance:1e-10,originalResidualTolerance:1e-8,
            maximumCorrection:100,nonlinear:nonlinear,linearCapability:capability,linearTolerance:tolerance)
        let policy=try MechanismSolvePolicy(dynamics:TopologyFixtures.dynamics(n),constraints:constraints,maximumCoordinates:8,maximumRows:8,originalTolerance:1e-8)
        if impulse { return try MassWeightedMechanismSolver().reconcileVelocity(system,sample:sample,policy:policy,work:&outer,dynamicsWork:&dyn,rankWork:&rank,linearWork:&linear) }
        return try MassWeightedMechanismSolver().acceleration(system,sample:sample,drive:[0,10,0],policy:policy,work:&outer,dynamicsWork:&dyn,rankWork:&rank,linearWork:&linear)
    }
    @Test func scalarForceAndImpulseKeepTheirActualTemporalMeaning() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let model=try TopologyFixtures.model(),release=try TopologyFixtures.release(model,rule:TopologyFixtures.catalog(model).rules[0])
        var w=try TopologyFixtures.work()
        let force=try reaction(release,impulse:false),forceObservation=try #require(TopologyReleaseObservation.scalar(release,reaction:force,threshold:0,work:&w))
        #expect(forceObservation.metric == .torque)
        #expect(forceObservation.observed == force.generalizedReaction[1])
        #expect(try TopologyReleaseObservation.scalar(release,reaction:force,threshold:abs(forceObservation.observed),work:&w) == nil)
        let impulse=try reaction(release,impulse:true),impulseObservation=try #require(TopologyReleaseObservation.scalar(release,reaction:impulse,threshold:0,work:&w))
        #expect(impulseObservation.metric == .angularImpulse)
        #expect(impulseObservation.observed == impulse.generalizedReaction[1])
        let otherModel=try TopologyFixtures.model(floating:true),otherRelease=try TopologyFixtures.release(otherModel,rule:TopologyFixtures.catalog(otherModel).rules[0])
        #expect(throws:TopologyReleaseFailure.self) { try TopologyReleaseObservation.scalar(otherRelease,reaction:force,threshold:0,work:&w) }
    }
}
