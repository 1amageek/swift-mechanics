import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct SweepTests {
    @Test func highSpeedSpherePlaneAndMovingPlaneHaveOriginalTOIBrackets() throws {
        let sweeper: any CollisionSweeping = TranslationCollisionSweeper()
        var work = try CollisionFixtures.work()
        let sphere = try CollisionFixtures.proxy("sphere",shape:.sphere(radius:0.1),position:Vector3(0,0,10))
        let plane = try CollisionFixtures.proxy("plane",shape:.halfSpace)
        let motion = try CollisionSweep(start:sphere,end:CollisionFixtures.moved(sphere,Vector3(0,0,-10)))
        let stationary = try CollisionSweep(start:plane,end:plane)
        let result = try sweeper.timeOfImpact(first:motion,second:stationary,durationSeconds:1,
            maximumTimeWidthSeconds:1e-8,policy:CollisionFixtures.policy(),work:&work)
        guard let result else { Issue.record("Thin-wall crossing must produce a TOI"); return }
        let analytic = (10.0-0.1)/20
        #expect(result.lowerTime <= analytic && result.upperTime >= analytic)
        #expect(result.upperTime-result.lowerTime <= 1e-8)
        #expect(result.lowerSeparation > 0 && result.upperSeparation <= 0)
        #expect(CollisionFixtures.close(result.lowerSeparation,10-20*result.lowerTime-0.1))
        #expect(CollisionFixtures.close(result.upperSeparation,10-20*result.upperTime-0.1))
        #expect(result.upperWitness.originalBalanceResidual <= 1.1e-10)
        let movingPlane = try CollisionSweep(start:plane,end:CollisionFixtures.moved(plane,Vector3(0,0,2)))
        let other = try sweeper.timeOfImpact(first:motion,second:movingPlane,durationSeconds:1,
            maximumTimeWidthSeconds:1e-8,policy:CollisionFixtures.policy(),work:&work)
        guard let other else { Issue.record("Relative plane translation must collide"); return }
        let expected = (10.0-0.1)/22
        #expect(other.lowerTime <= expected && other.upperTime >= expected)
        #expect(CollisionFixtures.close(other.upperSeparation,10-22*other.upperTime-0.1))
    }

    @Test func sphereSphereTangentNoHitAndInitialOverlapAreExplicit() throws {
        let sweeper: any CollisionSweeping = TranslationCollisionSweeper()
        var work = try CollisionFixtures.work(iterations:200)
        let fixed = try CollisionFixtures.proxy("a",shape:.sphere(radius:1))
        let moving = try CollisionFixtures.proxy("b",shape:.sphere(radius:1),position:Vector3(-5,0,0))
        let a = try CollisionSweep(start:fixed,end:fixed)
        let b = try CollisionSweep(start:moving,end:CollisionFixtures.moved(moving,Vector3(5,0,0)))
        let result = try sweeper.timeOfImpact(first:a,second:b,durationSeconds:1,maximumTimeWidthSeconds:1e-8,policy:CollisionFixtures.policy(),work:&work)
        guard let result else { Issue.record("Sphere crossing must collide"); return }
        #expect(result.lowerTime <= 0.3 && result.upperTime >= 0.3)
        #expect(result.lowerSeparation > 0 && result.upperSeparation <= 0)
        let tangentStart = CollisionFixtures.moved(moving,try Vector3(-5,2,0))
        let tangentEnd = CollisionFixtures.moved(moving,try Vector3(5,2,0))
        let tangent = try sweeper.timeOfImpact(first:a,second:CollisionSweep(start:tangentStart,end:tangentEnd),
            durationSeconds:1,maximumTimeWidthSeconds:1e-8,policy:CollisionFixtures.policy(),work:&work)
        #expect(tangent != nil)
        #expect(tangent?.upperTime == 0.5)
        #expect(throws:CollisionError.unresolvedMinimum(separation:0)) {
            try sweeper.timeOfImpact(first:a,second:CollisionSweep(start:tangentStart,end:tangentEnd),
                durationSeconds:1,maximumTimeWidthSeconds:1e-12,policy:CollisionFixtures.policy(),work:&work)
        }
        let miss = try sweeper.timeOfImpact(first:a,second:CollisionSweep(start:CollisionFixtures.moved(moving,Vector3(-5,3,0)),
            end:CollisionFixtures.moved(moving,Vector3(5,3,0))),durationSeconds:1,maximumTimeWidthSeconds:1e-8,
            policy:CollisionFixtures.policy(),work:&work)
        #expect(miss == nil)
        let overlapping = CollisionFixtures.moved(moving,try Vector3(1,0,0))
        let initial = try sweeper.timeOfImpact(first:a,second:CollisionSweep(start:overlapping,end:overlapping),
            durationSeconds:1,maximumTimeWidthSeconds:1e-8,policy:CollisionFixtures.policy(),work:&work)
        #expect(initial?.initialOverlap == true && initial?.lowerTime == 0 && initial?.upperTime == 0)
    }

    @Test func rotationSourceDomainAndIterationFailuresDoNotReturnNoHit() throws {
        let sweeper: any CollisionSweeping = TranslationCollisionSweeper()
        let sphere = try CollisionFixtures.proxy("sphere",shape:.sphere(radius:1),position:Vector3(0,0,3))
        let plane = try CollisionFixtures.proxy("plane",shape:.halfSpace)
        let rotated = sphere.moved(to:RigidTransform(rotation:try UnitQuaternion(axis:.unitZ,angle:0.1),translation:sphere.pose.translation))
        #expect(throws:CollisionError.unsupportedSweep) { try CollisionSweep(start:sphere,end:rotated) }
        let changed = try CollisionFixtures.proxy("sphere",shape:.sphere(radius:1),position:Vector3(0,0,-3),geometryRevision:2)
        #expect(throws:CollisionError.staleGeometry) { try CollisionSweep(start:sphere,end:changed) }
        let motion = try CollisionSweep(start:sphere,end:CollisionFixtures.moved(sphere,Vector3(0,0,-3)))
        let staticPlane = try CollisionSweep(start:plane,end:plane)
        var limited = try CollisionFixtures.work(iterations:0)
        #expect(throws:CollisionError.resourceLimit(resource:.iterations,limit:0)) {
            try sweeper.timeOfImpact(first:motion,second:staticPlane,durationSeconds:1,maximumTimeWidthSeconds:1e-8,
                policy:CollisionFixtures.policy(),work:&limited)
        }
        let box = try CollisionFixtures.proxy("box",shape:.box(halfExtents:Vector3(1,1,1)))
        var work = try CollisionFixtures.work()
        #expect(throws:CollisionError.unsupportedSweep) {
            try sweeper.timeOfImpact(first:motion,second:CollisionSweep(start:box,end:box),durationSeconds:1,
                maximumTimeWidthSeconds:1e-8,policy:CollisionFixtures.policy(),work:&work)
        }
    }

    @Test func cancelledGeometryOperationFailsBeforeAcceptance() async throws {
        let proxy = try CollisionFixtures.proxy("sphere",shape:.sphere(radius:1))
        let policy = try CollisionFixtures.policy()
        let budget = try CollisionBudget(scalarStorage:200000,operations:200000,iterations:100,records:64)
        let task = Task {
            while !Task.isCancelled { await Task.yield() }
            var work = CollisionWork(budget:budget)
            let query: any CollisionGeometryQuerying = AnalyticCollisionQueries()
            return try query.point(proxy:proxy,query:.zero,policy:policy,work:&work)
        }
        task.cancel()
        do { _ = try await task.value; Issue.record("Cancelled query must fail") }
        catch { #expect(error as? CollisionError == .cancelled) }
    }
}
