import SwiftMechanics
import Testing

@Suite("Constrained impact source and domain admission")
struct ConstrainedImpactDomainTests {
    @Test func staleCollisionAndChangedInertiaFailBeforeEquations() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable."); return }
        let input = try ConstrainedImpactFixtures.input(), rows = try ConstrainedImpactFixtures.constraints(input.model)
        let token = HybridCancellation(), supplier = ImpactFaultEquationSupplier(.failure)
        var work = try ConstrainedImpactFixtures.numerical(), loads = try ConstrainedImpactFixtures.load(token)
        let stale = HardImpactInput(model:input.model,physical:input.physical,inertias:input.inertias,collision:input.collision,
                                    expectedCollisionRevision:2,contacts:input.contacts)
        do {
            _ = try ReferenceConstrainedImpactPreparer(equations:supplier).prepare(input:stale,constraints:rows,
                policy:ConstrainedImpactFixtures.policy(),admission:ConstrainedImpactFixtures.admission(token),loadWork:&loads,work:&work,cancellation:token)
            Issue.record("Stale geometry was admitted.")
        } catch let error as ConstrainedImpactError { if case .hybrid(.staleGeometry) = error.reason {} else { Issue.record("Wrong stale-source failure.") } }
        #expect(supplier.callCount == 0)
        var inertias = input.inertias
        let original = inertias[1]
        inertias[1] = try RigidBodyInertia(body:original.body,frame:original.frame,properties:ConstrainedImpactFixtures.properties(3))
        let changed = HardImpactInput(model:input.model,physical:input.physical,inertias:inertias,collision:input.collision,
                                     expectedCollisionRevision:1,contacts:input.contacts)
        do {
            _ = try ReferenceConstrainedImpactPreparer(equations:supplier).prepare(input:changed,constraints:rows,
                policy:ConstrainedImpactFixtures.policy(),admission:ConstrainedImpactFixtures.admission(token),loadWork:&loads,work:&work,cancellation:token)
            Issue.record("Changed actual inertia was admitted.")
        } catch let error as ConstrainedImpactError { if case .sourceMismatch = error.reason {} else { Issue.record("Wrong inertia-source failure.") } }
        #expect(supplier.callCount == 0)
    }
    @Test func capsAndCancellationPreventSupplierInvocation() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable."); return }
        let input = try ConstrainedImpactFixtures.input(), rows = try ConstrainedImpactFixtures.constraints(input.model), token = HybridCancellation()
        let supplier = ImpactFaultEquationSupplier(.failure), preparer = ReferenceConstrainedImpactPreparer(equations:supplier)
        var work = try ConstrainedImpactFixtures.numerical(), loads = try ConstrainedImpactFixtures.load(token)
        do {
            _ = try preparer.prepare(input:input,constraints:rows,policy:ConstrainedImpactFixtures.policy(entries:8),
                admission:ConstrainedImpactFixtures.admission(token),loadWork:&loads,work:&work,cancellation:token)
            Issue.record("Factor cap was ignored.")
        } catch let error as ConstrainedImpactError { if case .capacityExceeded = error.reason {} else { Issue.record("Wrong factor cap failure.") } }
        #expect(supplier.callCount == 0)
        work = try ConstrainedImpactFixtures.numerical(storage:1)
        do {
            _ = try preparer.prepare(input:input,constraints:rows,policy:ConstrainedImpactFixtures.policy(),
                admission:ConstrainedImpactFixtures.admission(token),loadWork:&loads,work:&work,cancellation:token)
            Issue.record("Storage cap was ignored.")
        } catch let error as ConstrainedImpactError { if case .numerical(.resourceLimit) = error.reason {} else { Issue.record("Wrong storage cap failure.") } }
        #expect(supplier.callCount == 0)
        token.cancel()
        do {
            _ = try preparer.prepare(input:input,constraints:rows,policy:ConstrainedImpactFixtures.policy(),
                admission:ConstrainedImpactFixtures.admission(token),loadWork:&loads,work:&work,cancellation:token)
            Issue.record("Cancelled preparation was admitted.")
        } catch let error as ConstrainedImpactError { if case .hybrid(.cancelled) = error.reason {} else { Issue.record("Wrong cancellation failure.") } }
        #expect(supplier.callCount == 0)
    }
    @Test func redundantOriginalRowsRefuseUniqueReactionAllocation() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable."); return }
        let input = try ConstrainedImpactFixtures.input(), original = try ConstrainedImpactFixtures.constraints(input.model), r = original.rows[0]
        let repeated = QuadraticConstraint(id:8,constant:r.constant,linear:r.linear,hessian:r.hessian,timeLinear:0,timeQuadratic:0,mixedTime:r.mixedTime)
        let rows = try QuadraticConstraintSystem(layout:original.layout,rows:[r,repeated],minimumPosition:original.minimumPosition,
            maximumPosition:original.maximumPosition,minimumTime:original.minimumTime,maximumTime:original.maximumTime)
        do { _ = try ConstrainedImpactFixtures.prepared(input,constraints:rows); Issue.record("Ambiguous impulses were admitted.") }
        catch let error as ConstrainedImpactError { if case .rankAmbiguity(rank:1,rows:2) = error.reason {} else { Issue.record("Wrong rank refusal.") } }
    }
    @Test(arguments:[false,true]) func nonlinearOrMultipleContactDomainIsExplicitlyUnsupported(_ multiple: Bool) throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable."); return }
        let input = try ConstrainedImpactFixtures.input(), original = try ConstrainedImpactFixtures.constraints(input.model), r = original.rows[0]
        let selected: HardImpactInput, rows: QuadraticConstraintSystem
        if multiple {
            selected = HardImpactInput(model:input.model,physical:input.physical,inertias:input.inertias,collision:input.collision,
                expectedCollisionRevision:1,contacts:input.contacts+input.contacts); rows = original
        } else {
            var hessian = r.hessian; hessian[0] = 1
            rows = try QuadraticConstraintSystem(layout:original.layout,
                rows:[QuadraticConstraint(id:r.id,constant:r.constant,linear:r.linear,hessian:hessian,timeLinear:0,timeQuadratic:0,mixedTime:r.mixedTime)],
                minimumPosition:original.minimumPosition,maximumPosition:original.maximumPosition,minimumTime:0,maximumTime:10); selected = input
        }
        do { _ = try ConstrainedImpactFixtures.prepared(selected,constraints:rows); Issue.record("Unsupported domain was admitted.") }
        catch let error as ConstrainedImpactError { if case .unsupportedDomain = error.reason {} else { Issue.record("Wrong unsupported refusal.") } }
    }
    @Test func separatingContactRefusesImpact() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable."); return }
        let source = try ConstrainedImpactFixtures.prepared(ConstrainedImpactFixtures.input(speed:1))
        var work = try ConstrainedImpactFixtures.numerical(), contact = try ConstrainedImpactFixtures.contact()
        do { _ = try ReferenceConstrainedNormalImpulseSolver().solve(source,work:&work,contactWork:&contact,cancellation:HybridCancellation()); Issue.record("Separating impact was admitted.") }
        catch let error as ConstrainedImpactError { if case .hybrid(.grazing) = error.reason {} else { Issue.record("Wrong separating refusal.") } }
    }
    @Test func trueRetainedLocksBlockNormalMotion() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable."); return }
        let input = try ConstrainedImpactFixtures.input(speed:0), original = try ConstrainedImpactFixtures.constraints(input.model)
        let rotorLock = QuadraticConstraint(id:8,constant:0,linear:[1,0,0],hessian:[Double](repeating:0,count:9),timeLinear:0,timeQuadratic:0,mixedTime:[0,0,0])
        let sliderLock = QuadraticConstraint(id:9,constant:-0.5,linear:[0,0,1],hessian:[Double](repeating:0,count:9),timeLinear:0,timeQuadratic:0,mixedTime:[0,0,0])
        let rows = try QuadraticConstraintSystem(layout:original.layout,rows:original.rows+[rotorLock,sliderLock],minimumPosition:original.minimumPosition,
            maximumPosition:original.maximumPosition,minimumTime:0,maximumTime:10)
        let source = try ConstrainedImpactFixtures.prepared(input,constraints:rows)
        var work = try ConstrainedImpactFixtures.numerical(), contact = try ConstrainedImpactFixtures.contact()
        do { _ = try ReferenceConstrainedNormalImpulseSolver().solve(source,work:&work,contactWork:&contact,cancellation:HybridCancellation()); Issue.record("Blocked normal mode was admitted.") }
        catch let error as ConstrainedImpactError { if case .blockedNormalMode = error.reason {} else { Issue.record("Wrong blocked-mode refusal.") } }
    }
}
