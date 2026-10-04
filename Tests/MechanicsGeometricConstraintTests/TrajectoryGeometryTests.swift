import SwiftMechanics
import Testing
import Foundation

@Suite struct TrajectoryGeometryTests {
    @Test func sourceTaggedRootRetainsActualLayoutAndStrictCanonicalChartWithoutQuadraticPayload() throws {
        for planar in [true,false] {
            let fixture=try TrajectoryGeometryFixtures(planar:planar),state=fixture.model.descriptor.initialState
            #expect(fixture.system.prescribedRoot == nil && fixture.system.prescribedMotion == nil)
            let provider:any PrescribedRootBindingProviding=try #require(fixture.system.rootBinding)
            #expect(provider.knownCoordinates == Array(state.v.indices) && provider.dynamicCoordinates.isEmpty)
            var work=try GeometricFixtures.work()
            let sample=try GeometricRelationEvaluator().evaluate(fixture.system,state:state,policy:GeometricFixtures.evaluation(),work:&work)
            #expect(sample.values.isEmpty && sample.velocity.rows.isEmpty && sample.velocity.layout.scales.count == state.v.count)
            let time=0.4,base=try provider.sample(time:time,work:&work),theta=0.2*sin(time)+0.3*(1-cos(time)),w=0.2*cos(time)+0.3*sin(time)
            #expect(abs(base.q[0]-(1+0.4*sin(time)+0.3*(1-cos(time)))) < 1e-12)
            if planar { #expect(abs(base.q[2]-(0.4+theta)) < 1e-12) }
            else {
                #expect(abs(base.q[3]-cos(theta/2)*cos(0.2)) < 1e-12)
                #expect(abs(base.q[5]-sin(theta/2)*sin(0.2)) < 1e-12)
                #expect(abs(base.v[4]-sin(0.4)*w) < 1e-12 && abs(base.v[5]-cos(0.4)*w) < 1e-12)
            }
            var q=state.q;q[0]+=0.001
            let changed=try KinematicState(revision:1,time:0,q:q,v:state.v,acceleration:state.acceleration),policy=try GeometricFixtures.evaluation()
            do throws(GeometricConstraintError) { try provider.validate(changed,work:&work);Issue.record("Changed original root accepted") }
            catch { if case .staleSource=error {} else { Issue.record("Wrong canonical source refusal") } }
            let outside=try KinematicState(revision:1,time:3,q:state.q,v:state.v,acceleration:state.acceleration)
            do throws(GeometricConstraintError) { _=try GeometricRelationEvaluator().evaluate(fixture.system,state:outside,policy:policy,work:&work);Issue.record("Outside law accepted") }
            catch { if case .motion(.outsideDomain)=error {} else { Issue.record("Wrong domain refusal") } }
        }
    }
    @Test func completeAnchorTrajectoryMatchesActualPlacementAndIndependentOriginalDerivatives() throws {
        let old=try PrescribedGeometryFixture(),law=old.program.motions[0],d=old.model.descriptor
        var work=try GeometricFixtures.work()
        let policy=try PrescribedTrajectoryPolicy(motion:old.program.policy,maximumSegments:2)
        let harmonic=try HarmonicPrescribedMotion(frame:law.frame,parentFrame:law.parentFrame,referenceTime:0,initialPose:law.initialPose,
            translationSine:law.translationRate,translationCosine:law.translationAcceleration.scaled(by:-1),rotationAxis:.unitZ,
            angularSine:0.5,angularCosine:-0.2,frequency:1,phase:0,minimumTime:0,maximumTime:2,maximumIdentifierBytes:100)
        let program=try PrescribedTrajectoryProgram(trajectories:[.harmonic(harmonic)],policy:policy,work:&work)
        let initialSamples=try AnalyticPrescribedTrajectorySampler().sample(program,time:0,policy:policy,work:&work).anchors
        let initial=try KinematicState(revision:1,time:0,q:d.initialState.q,v:d.initialState.v,acceleration:d.initialState.acceleration,prescribedAnchors:initialSamples)
        let descriptor=try MechanicalDescriptor(identity:d.identity,revision:d.revision,bodies:d.bodies,joints:d.joints,root:d.root,rootBase:d.rootBase,
            rootAuthority:d.rootAuthority,worldFrame:d.worldFrame,initialState:initial,representationRequirements:d.representationRequirements,features:d.features,extensions:d.extensions)
        let model=try ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()).compile(descriptor,policy:old.model.policy),original=try old.system(alignment:false)
        let capacity=try GeometricConstraintCapacity(maximumBodies:8,maximumPositions:8,maximumVelocities:8,maximumRows:8,maximumMetadataBytes:30000)
        let system=try GeometricConstraintSystem(model:model,layout:original.layout,relations:original.relations,minimumPosition:original.minimumPosition,
            maximumPosition:original.maximumPosition,minimumTime:0,maximumTime:2,capacity:capacity,work:&work,prescribedTrajectory:program)
        let t=0.2,q=0.35,v=0.7,a=0.4,anchors=try AnalyticPrescribedTrajectorySampler().sample(program,time:t,policy:policy,work:&work).anchors
        let state=try KinematicState(revision:1,time:t,q:[q],v:[v],acceleration:[a],prescribedAnchors:anchors)
        let sample=try GeometricRelationEvaluator().evaluate(system,state:state,policy:GeometricFixtures.evaluation(),work:&work)
        let theta=0.4+0.5*sin(t)+0.2*(1-cos(t)),w=0.5*cos(t)+0.2*sin(t),alpha = -0.5*sin(t)+0.2*cos(t)
        let expected=[cos(theta+q)-cos(theta),sin(theta+q)-sin(theta),0]
        let rate=[-sin(theta+q)*(w+v)+sin(theta)*w,cos(theta+q)*(w+v)-cos(theta)*w,0]
        let second=[-sin(theta+q)*(alpha+a)-cos(theta+q)*pow(w+v,2)+sin(theta)*alpha+cos(theta)*w*w,
                    cos(theta+q)*(alpha+a)-sin(theta+q)*pow(w+v,2)-cos(theta)*alpha+sin(theta)*w*w,0]
        for i in 0..<3 {
            let velocity=(sample.velocity.rows[i]*v*system.layout.timeScale/system.layout.scales[0]+sample.velocity.drift[i])/system.layout.timeScale
            let acceleration=(sample.velocity.rows[i]*a*pow(system.layout.timeScale,2)/system.layout.scales[0]+sample.velocity.accelerationBias[i])/pow(system.layout.timeScale,2)
            #expect(abs(sample.values[i]-expected[i]) < 1e-12 && abs(velocity-rate[i]) < 1e-12 && abs(acceleration-second[i]) < 1e-12)
        }
        #expect(system.prescribedMotion == nil && system.prescribedTrajectory?.metadata == program.metadata)
        // A complete, valid mathematical law inventory must still bind actual model frames.
        let wrongFrame=try GeometricFixtures.id(.frame,"different-parent")
        let wrong=try HarmonicPrescribedMotion(frame:wrongFrame,parentFrame:law.parentFrame,referenceTime:0,initialPose:law.initialPose,
            translationSine:law.translationRate,translationCosine:law.translationAcceleration.scaled(by:-1),rotationAxis:.unitZ,
            angularSine:0.5,angularCosine:-0.2,frequency:1,phase:0,minimumTime:0,maximumTime:2,maximumIdentifierBytes:100)
        let wrongProgram=try PrescribedTrajectoryProgram(trajectories:[.harmonic(wrong)],policy:policy,work:&work)
        do throws(GeometricConstraintError) {
            _=try GeometricConstraintSystem(model:model,layout:system.layout,relations:system.relations,minimumPosition:system.minimumPosition,
                maximumPosition:system.maximumPosition,minimumTime:0,maximumTime:2,capacity:capacity,work:&work,prescribedTrajectory:wrongProgram)
            Issue.record("Same inventory shape rebound a different frame")
        } catch { if case .unsupportedDomain=error {} else { Issue.record("Wrong frame binding refusal") } }
    }
}
