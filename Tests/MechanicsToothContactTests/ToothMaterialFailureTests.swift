import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ToothMaterialFailureTests {
    @Test(arguments:[0,1,2,3]) func legacyOperationsRefuseMaterialModelsBeforeSuppliers(normal: Int) throws {
        let model=try ToothMaterialFixtures.model(normal:normal), normalModel=try ToothFixtures.model(), accepted=try ToothFixtures.initial(normalModel)
        let policy=try ToothFixtures.policy(defect:100)
        for service in [ReferenceToothContactEvolution(model:model),ToothMaterialFixtures.service(model)] {
            var work=try ToothFixtures.work()
            do throws(ToothContactError) { _=try service.initial(time:0,q:[0,0],v:[0,0],evaluationTimeStep:0.001,policy:policy,work:&work); Issue.record("Legacy path admitted material law.") }
            catch { if case .unsupportedDomain=error {} else { Issue.record("Unexpected failure: \(error)") } }
            #expect(work.supplierCalls == 0)
            work=try ToothFixtures.work()
            do throws(ToothContactError) { _=try service.step(accepted:accepted,timeStep:0.001,policy:policy,work:&work); Issue.record("Legacy step admitted material law.") }
            catch { if case .unsupportedDomain=error {} else { Issue.record("Unexpected failure: \(error)") } }
            #expect(work.supplierCalls == 0)
            work=try ToothFixtures.work()
            do throws(ToothContactFailure) { _=try service.advance(accepted:accepted,to:0,timeStep:0.001,policy:policy,work:&work); Issue.record("Zero-step bypass admitted material law.") }
            catch {
                if case .unsupportedDomain=error.cause {} else { Issue.record("Unexpected failure: \(error.cause)") }
                #expect(error.accepted.physical == accepted.physical && error.completedSteps == 0)
            }
            #expect(work.supplierCalls == 0)
        }
        var work=try ToothFixtures.work()
        do throws(ToothContactError) { _=try ReferenceToothContactEvolution(model:model).initialMaterial(time:0,q:[0,0],v:[1,1],policy:policy,work:&work); Issue.record("Missing current supplier silently defaulted.") }
        catch { if case .unsupportedDomain=error {} else { Issue.record("Unexpected failure: \(error)") } }
        #expect(work.supplierCalls == 0)
    }
    @Test func oldNormalPublicResultsRemainExactWithExplicitCurrentComposition() throws {
        let model=try ToothFixtures.model(), policy=try ToothFixtures.policy(), old=ReferenceToothContactEvolution(model:model), fresh=ToothMaterialFixtures.service(model)
        var x=try ToothFixtures.work(), y=try ToothFixtures.work()
        let a=try old.initial(time:0,q:[0,0],v:[0.1,-0.2],evaluationTimeStep:0.001,policy:policy,work:&x)
        let b=try fresh.initial(time:0,q:[0,0],v:[0.1,-0.2],evaluationTimeStep:0.001,policy:policy,work:&y)
        #expect(a.physical == b.physical && a.histories == b.histories && a.contactStoredEnergy == b.contactStoredEnergy)
        #expect(x.operations == y.operations && x.supplierCalls == y.supplierCalls)
        let c=try old.step(accepted:a,timeStep:0.001,policy:policy,work:&x)
        let d=try fresh.step(accepted:b,timeStep:0.001,policy:policy,work:&y)
        #expect(c.physical == d.physical && c.histories == d.histories && c.originalEnergyDefect == d.originalEnergyDefect)
    }
    @Test func changedLawInertiaAndMaterialDirectionSameRevisionCannotReplay() throws {
        let model=try ToothMaterialFixtures.model(), initial=try ToothMaterialFixtures.initial(model), policy=try ToothFixtures.policy(defect:100)
        let changed=try [ToothMaterialFixtures.model(stiffness:11),ToothMaterialFixtures.model(inertia:2),ToothMaterialFixtures.model(direction:.unitX)]
        for other in changed {
            var work=try ToothFixtures.work()
            do throws(ToothContactError) { _=try ToothMaterialFixtures.service(other).stepMaterial(accepted:initial,timeStep:0.001,policy:policy,work:&work); Issue.record("Changed physical authority accepted.") }
            catch { if case .staleSource=error {} else { Issue.record("Unexpected failure: \(error)") } }
            #expect(work.supplierCalls == 0 && initial.histories[0].sequence == 0)
        }
        let singular=try ToothMaterialFixtures.model(direction:.unitY)
        var work=try ToothFixtures.work()
        do throws(ToothContactError) { _=try ToothMaterialFixtures.service(singular).initialMaterial(time:0,q:[0,0],v:[0,0],policy:policy,work:&work); Issue.record("Singular material frame accepted.") }
        catch { if case .materialChartSingularity=error {} else { Issue.record("Unexpected failure: \(error)") } }
    }
    @Test(arguments:[0,1,2,3,4,5]) func realCurrentFaultsPreserveSeedPrefixAndAcceptedValue(mode: Int) throws {
        if #available(macOS 15, iOS 18, tvOS 18, watchOS 11, *) {
            let model=try ToothMaterialFixtures.model(), initial=try ToothMaterialFixtures.initial(model)
            let modes:[ToothCurrentFault.Mode]=[.wrongForce,.wrongCouple,.reset,.fail,.cancelSuccess,.cancelThrow], supplier=ToothCurrentFault(modes[mode])
            let policy=try ToothFixtures.policy(defect:100,cancelled:{supplier.cancelled})
            var work=try ToothFixtures.work()
            let service=ReferenceToothContactEvolution(model:model,current:supplier)
            do throws(MaterialToothContactFailure) { _=try service.advanceMaterial(accepted:initial,to:0.001,timeStep:0.001,policy:policy,work:&work); Issue.record("Invalid current callback accepted.") }
            catch {
                switch mode {
                case 0,1: if case .invalidSupplierOutput=error.cause {} else { Issue.record("Unexpected failure: \(error.cause)") }
                case 2: if case .invalidSupplierLedger(let unavailable)=error.cause { #expect(unavailable) } else { Issue.record("Unexpected failure: \(error.cause)") }
                case 3: if case .current(.law(.invalidInput))=error.cause {} else { Issue.record("Unexpected failure: \(error.cause)") }
                default: if case .cancelled=error.cause {} else { Issue.record("Unexpected failure: \(error.cause)") }
                }
                #expect(error.accepted.physical == initial.physical && error.accepted.histories == initial.histories && error.completedSteps == 0)
                if mode != 2 { #expect(work.operations >= supplier.prefix) }
                #expect(error.work.operations == work.operations && supplier.calls == 1)
            }
        }
    }
    @Test func trialFailureActualPrefixAndEnergyCapacityRefusal() throws {
        let model=try ToothMaterialFixtures.model(), initial=try ToothMaterialFixtures.initial(model)
        var work=try ToothFixtures.work()
        let policy=try ToothFixtures.policy(maximumSteps:1,defect:100)
        do throws(MaterialToothContactFailure) { _=try ToothMaterialFixtures.service(model).advanceMaterial(accepted:initial,to:0.002,timeStep:0.001,policy:policy,work:&work); Issue.record("Step capacity ignored.") }
        catch { #expect(error.completedSteps == 1 && error.accepted.histories[0].sequence == 1 && error.accepted.physical.time == 0.001) }
        for ceiling in [true,false] {
            let localPolicy=try ToothFixtures.policy(defect:ceiling ? 0 : 100)
            work=try ToothFixtures.work(operations:ceiling ? 1_000_000_000 : 1)
            do throws(ToothContactError) { _=try ToothMaterialFixtures.service(model).stepMaterial(accepted:initial,timeStep:0.001,policy:localPolicy,work:&work); Issue.record("Energy/resource ceiling ignored.") }
            catch {
                if ceiling { if case .energyDefect=error {} else { Issue.record("Unexpected failure: \(error)") } }
                else { if case .capacityExceeded=error {} else { Issue.record("Unexpected failure: \(error)") } }
            }
            #expect(initial.physical.time == 0 && initial.histories[0].sequence == 0)
        }
        if #available(macOS 15, iOS 18, tvOS 18, watchOS 11, *) {
            let faulty=ToothLawFault(.fail)
            work=try ToothFixtures.work()
            do throws(ToothContactError) { _=try ReferenceToothContactEvolution(model:model,laws:faulty,current:CompliantContactCurrentEvaluator()).stepMaterial(accepted:initial,timeStep:0.001,policy:policy,work:&work); Issue.record("Trial failure ignored.") }
            catch { if case .contact(.invalidInput)=error {} else { Issue.record("Unexpected failure: \(error)") } }
            #expect(work.operations >= faulty.prefix && faulty.calls == 1 && initial.histories[0].sequence == 0)
        }
    }
    @Test func currentTaskCancellationStillMergesExecutedPrefix() async throws {
        if #available(macOS 15, iOS 18, tvOS 18, watchOS 11, *) {
            let model=try ToothMaterialFixtures.model(), initial=try ToothMaterialFixtures.initial(model), fault=ToothCurrentFault(.taskCancel), policy=try ToothFixtures.policy(defect:100)
            let task=Task { () throws -> (MaterialToothContactFailure?,ToothContactWork) in
                var work=try ToothFixtures.work()
                do throws(MaterialToothContactFailure) {
                    _=try ReferenceToothContactEvolution(model:model,current:fault).advanceMaterial(accepted:initial,to:0.001,timeStep:0.001,policy:policy,work:&work)
                    return (nil,work)
                } catch { return (error,work) }
            }
            let (failure,work)=try await task.value
            guard let failure else { Issue.record("Task cancellation not reported."); return }
            if case .cancelled=failure.cause {} else { Issue.record("Unexpected failure: \(failure.cause)") }
            #expect(work.operations >= fault.prefix && failure.accepted.histories == initial.histories)
        }
    }
}
