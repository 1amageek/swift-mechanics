import SwiftMechanics
import Testing

@Suite struct ClosedLoopPhysicalTests {
    private func close(_ a:Vector3,_ b:Vector3) throws -> Bool { try a.subtracting(b).magnitude()<1e-8 }
    private func recover(_ input:ClosedLoopReactionInput,frame:EntityID?=nil) throws -> ClosedLoopReactionReport {
        var work=try LoopFixtures.work(),loads=try LoopFixtures.loads()
        let recovery:any ClosedLoopReactionRecovering=ClosedLoopReactionRecovery()
        return try recovery.recover(input,outputFrame:frame ?? input.geometry.model.tree.worldFrame,policy:LoopFixtures.policy(),loadWork:&loads,work:&work)
    }
    @Test func identifiedTwoSliderPhysicalForceAndOriginalBalance() throws {
        let input=try LoopFixtures.input(),report=try recover(input),row=try #require(report.loops.first)
        #expect(abs(input.motion.values[0]-2)<1e-10 && abs(input.motion.values[1]-2)<1e-10)
        #expect(abs(row.multiplierJoules-48)<1e-9)
        #expect(try close(row.secondOnFirst.force,Vector3(-6,0,0)))
        #expect(try close(row.firstOnSecond.force,Vector3(6,0,0)))
        #expect(try close(row.secondOnFirst.torque,.zero) && close(row.firstOnSecond.torque,.zero))
        #expect(row.firstBody == input.geometry.relations[0].first.body && row.secondBody == input.geometry.relations[0].second.body)
        #expect(try row.firstEndpointWorld == .zero && row.secondEndpointWorld == Vector3(2,0,0))
        #expect(row.referencePointWorld == row.firstEndpointWorld && row.temporalMeaning == .instantaneousContinuousForce)
        #expect(row.timeSeconds == input.state.time && row.revision == input.state.revision)
        #expect(report.originalRank.reactionsUnique && report.originalRows.rows.count == 1)
        #expect(report.topologyAssumption == .completeTreeAndDeclaredRows)
        // Original independent Newton balances: 2*2 = 10-6, 3*2 = 6.
        #expect(abs(2*input.motion.values[0]-(10+row.secondOnFirst.force.x))<1e-9)
        #expect(abs(3*input.motion.values[1]-row.firstOnSecond.force.x)<1e-9)
        for joint in report.tree.joints {
            #expect(try close(joint.parentOnChild.force,.zero) && close(joint.parentOnChild.torque,.zero))
        }
        #expect(try close(try #require(report.tree.support).supportOnRoot.force,.zero))
        #expect(report.tree.maximumScaledOriginalGeneralizedResidual<1e-9)
        #expect(report.maximumOriginalPositionResidual<1e-9 && report.maximumOriginalVelocityResidual<1e-9 && report.maximumOriginalAccelerationResidual<1e-9)
    }
    @Test func normalizationLeavesPhysicalForceAndMomentUnchanged() throws {
        let one=try recover(LoopFixtures.input(scale:1)),four=try recover(LoopFixtures.input(scale:4))
        let a=try #require(one.loops.first),b=try #require(four.loops.first)
        #expect(abs(a.multiplierJoules-3)<1e-9 && abs(b.multiplierJoules-48)<1e-9)
        #expect(try close(a.secondOnFirst.force,b.secondOnFirst.force))
        #expect(try close(a.firstOnSecond.torque,b.firstOnSecond.torque))
        #expect(one.originalRows.metadata != four.originalRows.metadata)
        #expect(one.originalRows.rows[0].normalizationScale == 1 && four.originalRows.rows[0].normalizationScale == 4)
    }
    @Test func spatialOffsetLoadsTreeSupportsAndRotatedCommonReference() throws {
        let input=try LoopFixtures.input(offset:true),world=try recover(input),loop=try #require(world.loops.first)
        #expect(try close(loop.firstEndpointWorld,Vector3(0,1,0)))
        #expect(try close(loop.secondEndpointWorld,Vector3(2,1,0)))
        #expect(try close(loop.secondOnFirst.force,Vector3(-6,0,0)))
        #expect(try close(loop.secondOnFirst.force.adding(loop.firstOnSecond.force),.zero))
        #expect(try close(loop.secondOnFirst.torque.adding(loop.firstOnSecond.torque),.zero))
        let first=try #require(world.tree.joints.first(where:{$0.childBody == loop.firstBody}))
        let second=try #require(world.tree.joints.first(where:{$0.childBody == loop.secondBody}))
        // First's applied F=(10,0,5) at Y has torque (5,0,-10); its loop -6 X at Y adds +6 Z.
        #expect(try close(first.parentOnChild.force,Vector3(0,0,-5)))
        #expect(try close(first.parentOnChild.torque,Vector3(-5,0,4)))
        #expect(try close(second.parentOnChild.force,.zero))
        #expect(try close(second.parentOnChild.torque,Vector3(0,0,6)))
        let support=try #require(world.tree.support)
        #expect(try close(support.supportOnRoot.force,Vector3(0,0,-5)))
        #expect(try close(support.supportOnRoot.torque,Vector3(-5,0,10)))
        for joint in world.tree.joints {
            #expect(try close(joint.parentOnChild.force.adding(joint.childOnParent.force),.zero))
            #expect(try close(joint.parentOnChild.torque.adding(joint.childOnParent.torque),.zero))
        }
        let rotated=try recover(input,frame:LoopFixtures.id(.frame,"first")),converted=try #require(rotated.loops.first)
        #expect(try close(converted.secondOnFirst.force,Vector3(0,6,0)))
        #expect(try close(converted.referencePoint,Vector3(1,0,0)))
        #expect(try close(converted.referencePointWorld,loop.referencePointWorld))
        let convertedSupport=try #require(rotated.tree.support)
        #expect(try close(convertedSupport.supportOnRoot.torque,Vector3(0,5,10)))
    }
    @Test func originalDuplicateDistanceRemainsAmbiguous() throws {
        let input=try LoopFixtures.input(duplicate:true)
        #expect(input.motion.rowIDs == [91,92] && input.motion.rank.reactionNullity == 1)
        #expect(input.motion.rowMultipliers[1] == 0)
        do { _=try recover(input);Issue.record("Dependent original rows manufactured unique individual forces.") }
        catch let error as ClosedLoopReactionError { if case .ambiguousAllocation(let nullity)=error { #expect(nullity == 1) } else { Issue.record("Expected original allocation ambiguity.") } }
        catch { Issue.record("Unexpected non-recovery failure.") }
    }
    @Test func rootGravityAndChildSubtreeGravityHaveDistinctOwners() throws {
        let report=try recover(LoopFixtures.input(gravity:true)),support=try #require(report.tree.support)
        // Guide reactions own child masses 2 and 3. The root support also owns the static root's mass 1.
        #expect(try close(report.tree.joints[0].parentOnChild.force,Vector3(0,20,0)))
        #expect(try close(report.tree.joints[1].parentOnChild.force,Vector3(0,30,0)))
        #expect(try close(support.supportOnRoot.force,Vector3(0,60,0)))
        #expect(try close(support.supportOnRoot.torque,Vector3(0,0,60)))
        #expect(report.loadWork.consumed == 10)
    }
}
