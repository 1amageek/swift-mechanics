import SwiftMechanics
import Testing

@Suite struct PlanarClosedLoopPhysicalTests {
    private func recover(_ input:PlanarClosedLoopReactionInput,frame:EntityID?=nil) throws->PlanarClosedLoopReactionReport {
        let recovery:any PlanarClosedLoopReactionRecovering=PlanarClosedLoopReactionRecovery()
        var work=try LoopFixtures.work(),loads=try LoopFixtures.loads()
        return try recovery.recover(input,outputFrame:frame ?? input.geometry.model.tree.worldFrame,
            policy:PlanarLoopFixtures.policy(input.dynamics.velocityCount),loadWork:&loads,work:&work)
    }
    private func wrench(_ value:PlanarLoopWrench,x:Double,y:Double=0,z:Double=0) {
        #expect(abs(value.forceX-x)<1e-8 && abs(value.forceY-y)<1e-8 && abs(value.momentZ-z)<1e-8)
    }
    private func treeWrench(_ value:PlanarReactionWrench,x:Double,y:Double=0,z:Double=0) {
        #expect(abs(value.forceX-x)<1e-8 && abs(value.forceY-y)<1e-8 && abs(value.momentZ-z)<1e-8)
    }
    @Test(.timeLimit(.minutes(1))) func originalCoincidenceFourbarPhysicalUniqueMultiplierNonunique() throws {
        let input=try PlanarLoopFixtures.input(),report=try recover(input)
        for entry in input.geometry.model.tree.layout.joints {
            let expected=entry.joint.key == "b" ? -1.0/3 : 1.0/3
            #expect(abs(input.motion.motion.values[entry.velocities.start]-expected)<1e-8)
        }
        #expect(report.originalRank.rank == 2 && report.originalRank.reactionNullity == 1)
        #expect(report.physicalWrenchesUnique && !report.multipliersUnique && !report.originalRank.reactionsUnique)
        #expect(report.originalRows.rows.map({$0.rowID}) == [11,12,13])
        #expect(report.loops.map({$0.rowID}) == [11,12,13])
        let x=try #require(report.loops.first { $0.rowID == 11 }),y=try #require(report.loops.first { $0.rowID == 12 }),zero=try #require(report.loops.first { $0.rowID == 13 })
        #expect(abs(x.multiplierJoules-2.0/3)<1e-8 && abs(y.multiplierJoules)<1e-8)
        #expect(zero.isStructuralZero && zero.multiplierJoules == input.motion.motion.rowMultipliers[2])
        wrench(x.secondOnFirst,x:1.0/3)
        wrench(x.firstOnSecond,x:-1.0/3)
        wrench(zero.secondOnFirst,x:0)
        wrench(zero.firstOnSecond,x:0)
        #expect(try x.firstEndpointWorld.subtracting(Vector3(2,1,0)).magnitude()<1e-8)
        #expect(try x.secondEndpointWorld.subtracting(x.firstEndpointWorld).magnitude()<1e-8)
        #expect(x.referencePointWorld == x.firstEndpointWorld && x.temporalMeaning == .instantaneousContinuousForce)
        #expect(x.timeSeconds == input.state.time && x.revision == input.state.revision)
        for cut in report.tree.joints {
            let expected=cut.childBody.key == "rocker" ? 1.0/3 : -2.0/3
            treeWrench(cut.parentOnChild,x:expected)
            treeWrench(cut.childOnParent,x:-expected)
        }
        treeWrench(try #require(report.tree.support).supportOnRoot,x:-1.0/3)
        #expect(report.maximumOriginalPositionResidual<1e-8 && report.maximumOriginalVelocityResidual<1e-8 && report.maximumOriginalAccelerationResidual<1e-8)
        #expect(report.tree.maximumScaledOriginalGeneralizedResidual<1e-8)
        #expect(report.source.motion === input.motion)
    }
    @Test(.timeLimit(.minutes(1))) func coincidenceNormalizationAndRotatedCommonReferencePreservePhysics() throws {
        let one=try recover(PlanarLoopFixtures.input(scale:1)),two=try recover(PlanarLoopFixtures.input(scale:2))
        #expect(abs(one.loops[0].multiplierJoules-1.0/3)<1e-8)
        #expect(abs(two.loops[0].multiplierJoules-2.0/3)<1e-8)
        #expect(abs(one.loops[0].secondOnFirst.forceX-two.loops[0].secondOnFirst.forceX)<1e-8)
        let input=try PlanarLoopFixtures.input(),rotated=try recover(input,frame:LoopFixtures.id(.frame,"crank"))
        wrench(rotated.loops[0].secondOnFirst,x:0,y:-1.0/3)
        wrench(rotated.loops[0].firstOnSecond,x:0,y:1.0/3)
        #expect(try rotated.loops[0].referencePoint.subtracting(Vector3(1,-2,0)).magnitude()<1e-8)
        #expect(rotated.loops[0].referencePointWorld == two.loops[0].referencePointWorld)
        treeWrench(try #require(rotated.tree.support).supportOnRoot,x:0,y:1.0/3)
    }
    @Test(.timeLimit(.minutes(1))) func planarOffsetSlidersSupportMomentsFramesAndDistinctGravity() throws {
        let input=try PlanarLoopFixtures.input(fourbar:false,offset:true,gravity:true),world=try recover(input),row=try #require(world.loops.first)
        #expect(abs(row.multiplierJoules-48)<1e-8)
        wrench(row.secondOnFirst,x:-6)
        wrench(row.firstOnSecond,x:6)
        let first=try #require(world.tree.joints.first { $0.childBody == row.firstBody }),second=try #require(world.tree.joints.first { $0.childBody == row.secondBody })
        treeWrench(first.parentOnChild,x:0,y:15,z:4)
        treeWrench(second.parentOnChild,x:0,y:30,z:6)
        treeWrench(try #require(world.tree.support).supportOnRoot,x:0,y:55,z:70)
        let rotated=try recover(input,frame:LoopFixtures.id(.frame,"first"))
        wrench(rotated.loops[0].secondOnFirst,x:0,y:6)
        treeWrench(try #require(rotated.tree.support).supportOnRoot,x:55,y:0,z:70)
        #expect(try rotated.loops[0].referencePoint.subtracting(Vector3(1,0,0)).magnitude()<1e-8)
        #expect(world.loadWork.consumed == 13)
        let plain=try recover(PlanarLoopFixtures.input(fourbar:false,scale:1)),scaled=try recover(PlanarLoopFixtures.input(fourbar:false,scale:4))
        #expect(abs(plain.loops[0].multiplierJoules-3)<1e-8)
        #expect(abs(plain.loops[0].secondOnFirst.forceX-scaled.loops[0].secondOnFirst.forceX)<1e-8)
    }
    @Test(.timeLimit(.minutes(1))) func activeDuplicateAndToggleRefuseDespiteAcceptedMultiplierRepresentative() throws {
        let original=try PlanarLoopFixtures.input(),model=original.geometry.model
        let duplicate=try PlanarLoopFixtures.fourbarGeometry(model,duplicate:true)
        let duplicateRows=try LoopFixtures.rows(duplicate,state:original.state)
        let duplicateMotion=try PlanarLoopFixtures.motion(original.dynamics,duplicateRows)
        let doubled=PlanarLoopFixtures.replacing(original,motion:duplicateMotion,geometry:duplicate)
        do { _=try recover(doubled);Issue.record("Active duplicate was reported unique") }
        catch let error as ClosedLoopReactionError {
            guard case .ambiguousAllocation(let nullity)=error else { Issue.record("Unexpected duplicate refusal");return }
            #expect(nullity == 4)
        }
        let toggleModel=try PlanarLoopFixtures.fourbarModel(angle:0),toggle=try PlanarLoopFixtures.fourbarGeometry(toggleModel)
        let toggleRows=try LoopFixtures.rows(toggle,state:toggleModel.descriptor.initialState),toggleSystem=try PlanarLoopFixtures.system(toggleModel)
        let toggleMotion=try PlanarLoopFixtures.motion(toggleSystem,toggleRows)
        let atToggle=PlanarLoopFixtures.replacing(original,motion:toggleMotion,geometry:toggle,state:toggleModel.descriptor.initialState)
        do { _=try recover(atToggle);Issue.record("Active zero projection manufactured physical uniqueness") }
        catch let error as ClosedLoopReactionError { guard case .ambiguousAllocation=error else { Issue.record("Unexpected toggle refusal");return } }
    }
}
