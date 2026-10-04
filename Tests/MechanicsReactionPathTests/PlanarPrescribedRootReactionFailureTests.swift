import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct PlanarPrescribedRootReactionFailureTests {
    @Test func actualForeignSystemChangedLawTimeAndRootRowsCannotPublish() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let f=try PlanarPrescribedRootReactionFixtures(),changed=try PlanarPrescribedRootReactionFixtures(angularAcceleration:0.7)
            let rows=try PlanarPrescribedRootReactionFixtures(rootID:201)
            let time=try KinematicState(revision:1,time:0.3,q:f.state.q,v:f.state.v,acceleration:f.state.acceleration)
            let sources=[f.replacing(constraint:changed.constraint),f.replacing(geometry:changed.geometry),
                         f.replacing(state:time),f.replacing(geometry:rows.geometry)]
            for source in sources {
                var work=try PlanarPrescribedRootReactionFixtures.work(),loads=try PlanarPrescribedRootReactionFixtures.loads()
                do throws(PlanarPrescribedRootReactionError) {
                    _=try PlanarPrescribedRootReactionRecovery().recover(source,outputFrame:f.model.tree.worldFrame,policy:f.policy,loadWork:&loads,work:&work)
                    Issue.record("Changed original source accepted")
                } catch {
                    switch error { case .staleSource,.geometry(.staleSource): break; default: Issue.record("Unexpected source rejection") }
                }
            }
        }
    }
    @Test func genuineForeignForceMultipliersAndFreeCoordinateDriveAreRejected() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let f=try PlanarPrescribedRootReactionFixtures(),foreign=try PlanarPrescribedRootReactionFixtures.foreign(f.constraint.system)
            let supplier=PlanarPrescribedRootForeignEquations(query:.force,foreign:foreign)
            let motion=try PlanarPrescribedRootReactionFixtures.solve(f.constraint,drive:[0,0,0],policy:f.policy.mechanism,equations:supplier)
            #expect(motion.system === f.constraint.system)
            #expect(abs(motion.motion.rowMultipliers[0]-f.motion.motion.rowMultipliers[0]) > 1e-5)
            let source=f.replacing(motion:motion)
            var work=try PlanarPrescribedRootReactionFixtures.work(),loads=try PlanarPrescribedRootReactionFixtures.loads()
            do throws(PlanarPrescribedRootReactionError) {
                _=try PlanarPrescribedRootReactionRecovery().recover(source,outputFrame:f.model.tree.worldFrame,policy:f.policy,loadWork:&loads,work:&work)
                Issue.record("Foreign original-force multipliers accepted")
            } catch { if case .originalRootEffort=error {} else { Issue.record("Wrong multiplier rejection") } }
            let slider=try PlanarPrescribedRootReactionFixtures(slider:true,dynamicDrive:1)
            #expect(abs(slider.motion.motion.values[3]-0.5) < 1e-8)
            work=try PlanarPrescribedRootReactionFixtures.work();loads=try PlanarPrescribedRootReactionFixtures.loads()
            do throws(PlanarPrescribedRootReactionError) {
                _=try PlanarPrescribedRootReactionRecovery().recover(slider.input,outputFrame:slider.model.tree.worldFrame,policy:slider.policy,loadWork:&loads,work:&work)
                Issue.record("Support absorbed unbalanced free coordinate")
            } catch { if case .tree(.originalGeneralizedResidual(index:3,scaledValue:_))=error {} else { Issue.record("Wrong free-coordinate rejection") } }
        }
    }
    @Test func explicitAndOriginalGeneralizedOnlyLoadsRefuseAllocation() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let f=try PlanarPrescribedRootReactionFixtures(),g=try PlanarPrescribedRootReactionFixtures(generalized:true)
            for (source,policy,frame) in [(f.replacing(drive:[1,0,0]),f.policy,f.model.tree.worldFrame),(g.input,g.policy,g.model.tree.worldFrame)] {
                var work=try PlanarPrescribedRootReactionFixtures.work(),loads=try PlanarPrescribedRootReactionFixtures.loads()
                do throws(PlanarPrescribedRootReactionError) {
                    _=try PlanarPrescribedRootReactionRecovery().recover(source,outputFrame:frame,policy:policy,loadWork:&loads,work:&work)
                    Issue.record("Unidentified generalized load allocated")
                } catch { if case .unallocatableGeneralizedLoad=error {} else { Issue.record("Wrong allocation rejection") } }
            }
        }
    }
    @Test func originalRowsNamedSupportsImpulseAndIncompleteTopologyRefuse() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let f=try PlanarPrescribedRootReactionFixtures()
            let impulse=try PlanarPrescribedRootReactionFixtures.solve(f.constraint,drive:[0,0,0],policy:f.policy.mechanism,impulse:true)
            let named=try PrescribedAnchorState(frame:f.constraint.base.frame,time:f.state.time,motion:f.constraint.base.motion)
            let state=try KinematicState(revision:1,time:f.state.time,q:f.state.q,v:f.state.v,acceleration:f.state.acceleration,prescribedAnchors:[named])
            let relation=try GeometricRelation(kind:.coincidence,rowIDs:[401,402,403],
                first:GeometricFrameEndpoint(body:PlanarPrescribedRootReactionFixtures.id(.body,"support-root"),frame:PlanarPrescribedRootReactionFixtures.id(.frame,"support-root-frame"),point:Vector3(2,0,0)),
                second:GeometricFrameEndpoint(body:PlanarPrescribedRootReactionFixtures.id(.body,"support-child"),frame:PlanarPrescribedRootReactionFixtures.id(.frame,"support-child-frame")),target:GeometricAnalyticTarget(),scale:2)
            let loop=try PlanarPrescribedRootReactionFixtures(slider:true,relations:[relation])
            #expect(loop.constraint.geometry.rowIDs == [401,402,403])
            #expect(loop.constraint.geometry.rows.suffix(4).allSatisfy({$0 == 0}))
            let cases=[(f.replacing(state:state),f.policy,f.model.tree.worldFrame,0),(loop.input,loop.policy,loop.model.tree.worldFrame,0),
                       (f.replacing(motion:impulse),f.policy,f.model.tree.worldFrame,1),(f.replacing(topology:.unrepresentedConnections),f.policy,f.model.tree.worldFrame,2)]
            for (source,policy,frame,expected) in cases {
                var work=try PlanarPrescribedRootReactionFixtures.work(),loads=try PlanarPrescribedRootReactionFixtures.loads()
                do throws(PlanarPrescribedRootReactionError) {
                    _=try PlanarPrescribedRootReactionRecovery().recover(source,outputFrame:frame,policy:policy,loadWork:&loads,work:&work)
                    Issue.record("Unsupported physical domain accepted")
                } catch {
                    switch (expected,error) {
                    case (0,.unsupportedSupportDomain),(1,.unsupportedTemporalMeaning),(2,.unrepresentedConnections): break
                    default: Issue.record("Wrong domain rejection")
                    }
                }
            }
        }
    }
    @Test func boundsCancellationFrameAndFiniteStorageFailWithoutReport() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let f=try PlanarPrescribedRootReactionFixtures(),cancelled=try PlanarPrescribedRootReactionFixtures.policies(f.geometry.layout.scales,cancelled:true)
            let tiny=try TreeReactionPolicy(maximumBodies:0,maximumJoints:0,maximumBodyLoads:0,generalizedForceScales:[1,1,1],
                generalizedTolerance:f.policy.tree.generalizedTolerance,forceTolerance:f.policy.tree.forceTolerance,torqueTolerance:f.policy.tree.torqueTolerance)
            let bounded=try PlanarPrescribedRootReactionPolicy(geometry:f.policy.geometry,mechanism:f.policy.mechanism,tree:tiny)
            let unknown=try PlanarPrescribedRootReactionFixtures.id(.frame,"unknown-output")
            let cases=[(cancelled,1_000_000,f.model.tree.worldFrame,0),(bounded,1_000_000,f.model.tree.worldFrame,1),
                       (f.policy,1,f.model.tree.worldFrame,2),(f.policy,1_000_000,unknown,3)]
            for (policy,storage,frame,expected) in cases {
                var work=try PlanarPrescribedRootReactionFixtures.work(storage:storage),loads=try PlanarPrescribedRootReactionFixtures.loads()
                do throws(PlanarPrescribedRootReactionError) {
                    _=try PlanarPrescribedRootReactionRecovery().recover(f.input,outputFrame:frame,policy:policy,loadWork:&loads,work:&work)
                    Issue.record("Resource/cancellation/frame failure published")
                } catch {
                    switch (expected,error) {
                    case (0,.cancelled),(1,.capacityExceeded),(2,.numerical),(3,.tree(.joints)): break
                    default: Issue.record("Wrong resource rejection")
                    }
                }
            }
        }
    }
}
