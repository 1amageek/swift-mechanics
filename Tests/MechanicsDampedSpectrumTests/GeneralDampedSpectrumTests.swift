import Testing
@testable import SwiftMechanics

@Suite struct GeneralDampedSpectrumTests {
    @Test func genuinelyCoupledNonproportionalPencilHasExactQuarticRootsAndComplexModes() throws {
        let p=try DampedSpectrumFixtures.pencil(),service:any GeneralDampedModalAnalyzing=ReferenceGeneralDampedModalAnalyzer()
        var work=try DampedSpectrumFixtures.work()
        let result=try service.modes(p,expectedBinding:p.binding,policy:DampedSpectrumFixtures.policy(),spectrumPolicy:DampedSpectrumFixtures.spectrum(),work:&work)
        #expect(p.damping[1]*p.stiffness[3] != p.stiffness[0]*p.damping[1])
        #expect(result.poles.count==4);#expect(result.modes.count==8);#expect(result.binding==p.binding)
        for expected in DampedSpectrumFixtures.expected { #expect(ComplexFixtureMath.distance(DampedSpectrumFixtures.nearest(result.poles,expected),expected)<1e-9) }
        for mode in result.poles.indices {
            let z=result.poles[mode],ratio=ComplexFixtureMath.scale(ComplexFixtureMath.divide(ComplexFixtureMath.add(ComplexFixtureMath.add(ComplexFixtureMath.multiply(z,z),z),SpectrumComplex(real:2,imaginary:0)),ComplexFixtureMath.scale(z,2.0.squareRoot())),-1)
            #expect(ComplexFixtureMath.distance(result.modes[2*mode+1],ComplexFixtureMath.multiply(ratio,result.modes[2*mode]))<1e-8)
        }
        let original=DampedSpectrumFixtures.original(p,result)
        #expect(original.0<1e-8);#expect(original.1<1e-10)
        #expect(result.maximumOriginalQuadraticResidual<1e-9);#expect(result.maximumMassNormalizationError<1e-10)
        #expect(work.operations>0);#expect(work.iterations>0);#expect(result.work==work)
    }
    @Test func physicalCongruenceAndTimeEnergyScalesPreservePolesAndOriginalMassNorm() throws {
        let p=try DampedSpectrumFixtures.pencil(congruence:[2,3],scales:[0.3,2]),service=ReferenceGeneralDampedModalAnalyzer()
        var work=try DampedSpectrumFixtures.work()
        let result=try service.modes(p,expectedBinding:p.binding,policy:DampedSpectrumFixtures.policy(time:0.7,energy:3),spectrumPolicy:DampedSpectrumFixtures.spectrum(),work:&work)
        for expected in DampedSpectrumFixtures.expected { #expect(ComplexFixtureMath.distance(DampedSpectrumFixtures.nearest(result.poles,expected),expected)<1e-8) }
        let original=DampedSpectrumFixtures.original(p,result);#expect(original.0<1e-8);#expect(original.1<1e-10)
    }
    @Test func couplingPerturbationMatchesIndependentDeterminantAndSecondOrderRefinement() throws {
        let start=SpectrumComplex(real:-0.5,imaginary:15.0.squareRoot()/2),c0=2.0.squareRoot()
        let derivative=ComplexFixtureMath.divide(ComplexFixtureMath.scale(ComplexFixtureMath.multiply(start,start),4),ComplexFixtureMath.derivative(start,c0))
        var errors:[Double]=[]
        for h in [1e-3,5e-4] {
            let c=c0*(1+h),p=try DampedSpectrumFixtures.pencil(coupling:c);var work=try DampedSpectrumFixtures.work()
            let result=try ReferenceGeneralDampedModalAnalyzer().modes(p,expectedBinding:p.binding,policy:DampedSpectrumFixtures.policy(),spectrumPolicy:DampedSpectrumFixtures.spectrum(),work:&work)
            let actual=DampedSpectrumFixtures.nearest(result.poles,start),oracle=ComplexFixtureMath.root(start,coupling:c)
            #expect(ComplexFixtureMath.distance(actual,oracle)<1e-9)
            #expect(ComplexFixtureMath.polynomial(actual,c).amplitude<1e-8)
            errors.append(ComplexFixtureMath.distance(actual,ComplexFixtureMath.add(start,ComplexFixtureMath.scale(derivative,h))))
        }
        #expect(errors[1]<0.3*errors[0]);#expect(errors[0]>1e-8)
    }
    @Test(arguments:[false,true]) func realOverdampedAndUnstableRootsRemainPhysical(unstable:Bool) throws {
        let p=try StructuralPencil(binding:DampedSpectrumFixtures.binding(n:1,scales:[1]),mass:[1],stiffness:[unstable ? -2:4],damping:[unstable ? 1:5])
        var w=try DampedSpectrumFixtures.work()
        let result=try ReferenceGeneralDampedModalAnalyzer().modes(p,expectedBinding:p.binding,policy:DampedSpectrumFixtures.policy(),spectrumPolicy:DampedSpectrumFixtures.spectrum(),work:&w)
        let expected=unstable ? [-2.0,1.0]:[-4.0,-1.0]
        for x in expected { #expect(result.poles.contains{abs($0.real-x)<1e-10 && abs($0.imaginary)<1e-10}) }
        #expect(DampedSpectrumFixtures.original(p,result).0<1e-10)
    }
    @Test func nonpositiveMassNonsymmetryAndStaleBindingRefuseBeforePublication() throws {
        let p=try DampedSpectrumFixtures.pencil(),sp=try DampedSpectrumFixtures.spectrum(),policy=try DampedSpectrumFixtures.policy()
        let bad=StructuralPencil(binding:p.binding,mass:[0,0,0,1],stiffness:p.stiffness,damping:p.damping)
        var w=try DampedSpectrumFixtures.work()
        do throws(GeneralDampedSpectrumFailure) { _=try ReferenceGeneralDampedModalAnalyzer().modes(bad,expectedBinding:bad.binding,policy:policy,spectrumPolicy:sp,work:&w);Issue.record("Zero mass accepted") }
        catch { if case .structural(.nonPositiveMass) = error.cause {} else { Issue.record("Wrong mass refusal") };#expect(error.work==w) }
        let nonsymmetric=StructuralPencil(binding:p.binding,mass:p.mass,stiffness:p.stiffness,damping:[1,1,0,2])
        #expect(throws:GeneralDampedSpectrumFailure.self) { try ReferenceGeneralDampedModalAnalyzer().modes(nonsymmetric,expectedBinding:p.binding,policy:policy,spectrumPolicy:sp,work:&w) }
        let stale=try DampedSpectrumFixtures.binding(revision:2)
        do throws(GeneralDampedSpectrumFailure) { _=try ReferenceGeneralDampedModalAnalyzer().modes(p,expectedBinding:stale,policy:policy,spectrumPolicy:sp,work:&w);Issue.record("Stale binding accepted") }
        catch { if case .structural(.staleBinding) = error.cause {} else { Issue.record("Wrong binding refusal") } }
    }
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @Test func upperAndLowerCancellationPreserveActualFailedWork() throws {
        let p=try DampedSpectrumFixtures.pencil(),counter=SpectrumCancellationCounter(limit:12)
        let policy=try DampedSpectrumFixtures.policy(cancelled:{counter.cancelled()}),sp=try DampedSpectrumFixtures.spectrum()
        var work=try DampedSpectrumFixtures.work()
        do throws(GeneralDampedSpectrumFailure) { _=try ReferenceGeneralDampedModalAnalyzer().modes(p,expectedBinding:p.binding,policy:policy,spectrumPolicy:sp,work:&work);Issue.record("Mid-operation cancellation published") }
        catch { if case .structural(.cancelled) = error.cause {} else { Issue.record("Wrong upper cancellation") };#expect(error.work==work);#expect(!error.failedSupplierWorkUnavailable) }
        #expect(work.operations>0);#expect(work.iterations>0)
        var lower=try DampedSpectrumFixtures.work();let ls=try DampedSpectrumFixtures.spectrum(cancelled:{true}),normal=try DampedSpectrumFixtures.policy()
        do throws(GeneralDampedSpectrumFailure) { _=try ReferenceGeneralDampedModalAnalyzer().modes(p,expectedBinding:p.binding,policy:normal,spectrumPolicy:ls,work:&lower);Issue.record("Lower cancellation published") }
        catch { if case .spectral(.cancelled) = error.cause {} else { Issue.record("Wrong lower cancellation") };#expect(error.work==lower);#expect(lower.operations>0) }
    }
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    @Test func lateSpectralCancellationCannotBeBypassedByValidInjectedSupplier() throws {
        let flag=SpectrumCancellationFlag(),p=try DampedSpectrumFixtures.pencil()
        let policy=try DampedSpectrumFixtures.policy(),sp=try DampedSpectrumFixtures.spectrum(cancelled:{flag.isCancelled()})
        var work=try DampedSpectrumFixtures.work()
        let service=ReferenceGeneralDampedModalAnalyzer(spectrum:LateSpectralCancellingSupplier(flag:flag))
        do throws(GeneralDampedSpectrumFailure) {
            _=try service.modes(p,expectedBinding:p.binding,policy:policy,spectrumPolicy:sp,work:&work)
            Issue.record("Late spectral cancellation was bypassed by valid solver data")
        } catch {
            if case .spectral(.cancelled) = error.cause {} else { Issue.record("Wrong late cancellation cause") }
            #expect(error.work==work);#expect(!error.failedSupplierWorkUnavailable)
        }
        #expect(flag.isCancelled());#expect(work.operations>0);#expect(work.iterations>0)
    }
    @Test(arguments:[0,1,2]) func numericalLimitsDoNotEraseUpperOrLowerPrefix(kind:Int) throws {
        let p=try DampedSpectrumFixtures.pencil(),policy=try DampedSpectrumFixtures.policy(),sp=try DampedSpectrumFixtures.spectrum()
        var work=try DampedSpectrumFixtures.work(storage:kind==0 ? 500:100000,operations:kind==1 ? 500:10000000,iterations:kind==2 ? 0:10000)
        do throws(GeneralDampedSpectrumFailure) { _=try ReferenceGeneralDampedModalAnalyzer().modes(p,expectedBinding:p.binding,policy:policy,spectrumPolicy:sp,work:&work);Issue.record("Budget ignored") }
        catch { #expect(error.work==work);#expect(!error.failedSupplierWorkUnavailable)
            if case .numerical(.resourceLimit) = error.cause {} else if case .spectral(.numerical(.resourceLimit)) = error.cause {} else { Issue.record("Wrong resource cause") }
        }
        #expect(work.operations>0)
    }
    @Test(arguments:[FaultyComplexSpectralSolver.Fault.resetLedger,.changedBudget,.wrongPole,.wrongCount,.throwAfterWork]) func maliciousSupplierCannotPublishOrLoseKnownPrefix(fault:FaultyComplexSpectralSolver.Fault) throws {
        let p=try DampedSpectrumFixtures.pencil(),policy=try DampedSpectrumFixtures.policy(),sp=try DampedSpectrumFixtures.spectrum()
        var work=try DampedSpectrumFixtures.work()
        let solver=ReferenceGeneralDampedModalAnalyzer(spectrum:FaultyComplexSpectralSolver(fault:fault))
        do throws(GeneralDampedSpectrumFailure) { _=try solver.modes(p,expectedBinding:p.binding,policy:policy,spectrumPolicy:sp,work:&work);Issue.record("Faulty supplier published modes") }
        catch {
            #expect(error.work==work);#expect(work.operations>0)
            if fault == .resetLedger || fault == .changedBudget {
                if case .invalidSupplierLedger = error.cause {} else { Issue.record("Wrong ledger refusal") }
                #expect(error.failedSupplierWorkUnavailable)
            } else if fault == .throwAfterWork {
                if case .spectral(.nonConvergence) = error.cause {} else { Issue.record("Wrong failed supplier refusal") };#expect(!error.failedSupplierWorkUnavailable)
            } else { if case .invalidSupplierOutput = error.cause {} else { Issue.record("Wrong supplier output refusal") };#expect(!error.failedSupplierWorkUnavailable) }
        }
    }
    @Test func physicalOriginalCheckRejectsLooseButFalseSupplierPole() throws {
        let p=try DampedSpectrumFixtures.pencil(),policy=try DampedSpectrumFixtures.policy(residual:1e-12),sp=try DampedSpectrumFixtures.spectrum(residual:1)
        var work=try DampedSpectrumFixtures.work()
        do throws(GeneralDampedSpectrumFailure) { _=try ReferenceGeneralDampedModalAnalyzer(spectrum:FaultyComplexSpectralSolver(fault:.wrongPole)).modes(p,expectedBinding:p.binding,policy:policy,spectrumPolicy:sp,work:&work);Issue.record("False physical pole published") }
        catch { if case .residualRejected = error.cause {} else { Issue.record("Wrong physical residual refusal") };#expect(error.work==work) }
    }
    @Test func repeatedCriticalCompanionFailsWithoutPlaceholderModes() throws {
        let p=try StructuralPencil(binding:DampedSpectrumFixtures.binding(n:1,scales:[1]),mass:[1],stiffness:[1],damping:[2]),policy=try DampedSpectrumFixtures.policy(),sp=try DampedSpectrumFixtures.spectrum()
        var work=try DampedSpectrumFixtures.work()
        do throws(GeneralDampedSpectrumFailure) { _=try ReferenceGeneralDampedModalAnalyzer().modes(p,expectedBinding:p.binding,policy:policy,spectrumPolicy:sp,work:&work);Issue.record("Defective critical companion published") }
        catch { if case .spectral(.illConditionedEigenvector) = error.cause {} else { Issue.record("Wrong critical failure") } }
    }
}
