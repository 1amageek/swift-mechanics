import Testing
import SwiftMechanics

@Suite struct GeneralComplexSpectrumTests {
    @Test func genuinelyNonsymmetricCyclicMatrixHasFourierModes() throws {
        let matrix=ComplexSpectrumFixtures.matrix([0,1,0,0,0,1,1,0,0],n:3)
        var work=try ComplexSpectrumFixtures.work();let solver:any ComplexSpectralSolving=ReferenceComplexSpectralSolver()
        let result=try solver.solve(matrix,policy:ComplexSpectrumFixtures.policy(),work:&work)
        let expected=[SpectrumComplex(real:-0.5,imaginary:-3.0.squareRoot()/2),SpectrumComplex(real:-0.5,imaginary:3.0.squareRoot()/2),SpectrumComplex(real:1,imaginary:0)]
        #expect(result.dimension==3);#expect(result.eigenvectors.count==9)
        for root in expected { #expect(result.eigenvalues.contains{ComplexSpectrumFixtures.distance($0,root)<1e-10}) }
        for mode in 0..<3 {
            let z=result.eigenvalues[mode],v=result.eigenvectors[mode*3],first=ComplexSpectrumFixtures.times(z,v),second=ComplexSpectrumFixtures.times(z,first)
            #expect(ComplexSpectrumFixtures.distance(result.eigenvectors[mode*3+1],first)<1e-10)
            #expect(ComplexSpectrumFixtures.distance(result.eigenvectors[mode*3+2],second)<1e-10)
        }
        #expect(ComplexSpectrumFixtures.originalResidual(matrix,result)<1e-10)
        #expect(work.operations>0);#expect(work.iterations>0);#expect(work.peakScalarStorage>=330);#expect(result.work==work)
    }
    @Test func complexInputHasTwoPureImaginaryEigenvalues() throws {
        let i=SpectrumComplex(real:0,imaginary:1),one=SpectrumComplex(real:1,imaginary:0)
        let matrix=ComplexSpectralMatrix(dimension:2,entries:[i,one,SpectrumComplex(real:-1,imaginary:0),i])
        var work=try ComplexSpectrumFixtures.work()
        let result=try ReferenceComplexSpectralSolver().solve(matrix,policy:ComplexSpectrumFixtures.policy(),work:&work)
        #expect(result.eigenvalues.contains{ComplexSpectrumFixtures.distance($0,SpectrumComplex(real:0,imaginary:0))<1e-10})
        #expect(result.eigenvalues.contains{ComplexSpectrumFixtures.distance($0,SpectrumComplex(real:0,imaginary:2))<1e-10})
        #expect(ComplexSpectrumFixtures.originalResidual(matrix,result)<1e-10)
    }
    @Test func realNonnormalAndRepeatedSemisimpleMatricesRetainFullAccounting() throws {
        let matrix=ComplexSpectrumFixtures.matrix([1,10,0,0,2,3,0,0,4],n:3)
        var work=try ComplexSpectrumFixtures.work()
        let result=try ReferenceComplexSpectralSolver().solve(matrix,policy:ComplexSpectrumFixtures.policy(),work:&work)
        #expect(result.eigenvalues.map{$0.real}==[1,2,4]);#expect(ComplexSpectrumFixtures.originalResidual(matrix,result)<1e-10)
        let identity=ComplexSpectrumFixtures.matrix([2,0,0,0,2,0,0,0,2],n:3)
        var other=try ComplexSpectrumFixtures.work()
        let repeated=try ReferenceComplexSpectralSolver().solve(identity,policy:ComplexSpectrumFixtures.policy(),work:&other)
        #expect(repeated.eigenvalues.count==3);#expect(repeated.eigenvectors.filter{$0.real==1}.count==3)
    }
    @Test(arguments:[1e-100,1e100]) func uniformScalingPreservesSmallAndLargeRotation(scale:Double) throws {
        let matrix=ComplexSpectrumFixtures.matrix([0,-scale,scale,0],n:2)
        var work=try ComplexSpectrumFixtures.work()
        let result=try ReferenceComplexSpectralSolver().solve(matrix,policy:ComplexSpectrumFixtures.policy(),work:&work)
        #expect(result.eigenvalues.count==2)
        for pole in result.eigenvalues { #expect(abs(pole.real/scale)<1e-10);#expect(abs(abs(pole.imaginary/scale)-1)<1e-10) }
    }
    @Test func defectiveJordanBlockRefusesUnresolvedEigenvector() throws {
        var work=try ComplexSpectrumFixtures.work();let policy=try ComplexSpectrumFixtures.policy()
        do throws(ComplexSpectrumError) {
            _=try ReferenceComplexSpectralSolver().solve(ComplexSpectrumFixtures.matrix([1,1,0,1],n:2),policy:policy,work:&work)
            Issue.record("Defective Jordan block published a complete eigenbasis")
        } catch { if case .illConditionedEigenvector = error {} else { Issue.record("Wrong defective failure") } }
        #expect(work.operations>0)
    }
    @Test func looseDeflationCannotBypassOriginalResidual() throws {
        var work=try ComplexSpectrumFixtures.work();let policy=try ComplexSpectrumFixtures.policy(deflation:2,residual:1e-12)
        do throws(ComplexSpectrumError) {
            _=try ReferenceComplexSpectralSolver().solve(ComplexSpectrumFixtures.matrix([0,-1,1,0],n:2),policy:policy,work:&work)
            Issue.record("Loose deflation published an invalid eigenpair")
        } catch {
            if case .residualRejected = error {} else if case .illConditionedEigenvector = error {} else { Issue.record("Wrong original acceptance failure") }
        }
    }
    @Test func cancellationAndIterationCapNeverPublishSpectrum() throws {
        let a=ComplexSpectrumFixtures.matrix([0,-1,1,0],n:2),solver=ReferenceComplexSpectralSolver()
        var cancelled=try ComplexSpectrumFixtures.work();let cp=try ComplexSpectrumFixtures.policy(cancelled:true)
        do throws(ComplexSpectrumError) { _=try solver.solve(a,policy:cp,work:&cancelled);Issue.record("Cancelled spectrum published") }
        catch { if case .cancelled = error {} else { Issue.record("Wrong cancellation") } }
        var exhausted=try ComplexSpectrumFixtures.work();let limit=try ComplexSpectrumFixtures.policy(iterations:0)
        do throws(ComplexSpectrumError) { _=try solver.solve(a,policy:limit,work:&exhausted);Issue.record("Iteration cap ignored") }
        catch { if case .nonConvergence(iterations:0,residual:_) = error {} else { Issue.record("Wrong iteration cap") } }
        #expect(exhausted.operations>0);#expect(exhausted.iterations==0)
    }
    @Test(arguments:[0,1,2]) func numericalBudgetsPreserveFailedPrefix(kind:Int) throws {
        let a=ComplexSpectrumFixtures.matrix([0,-1,1,0],n:2),policy=try ComplexSpectrumFixtures.policy()
        var work=try ComplexSpectrumFixtures.work(storage:kind==0 ? 1:100000,operations:kind==1 ? 20:10000000,iterations:kind==2 ? 0:10000)
        do throws(ComplexSpectrumError) { _=try ReferenceComplexSpectralSolver().solve(a,policy:policy,work:&work);Issue.record("Budget ignored") }
        catch { if case .numerical(.resourceLimit) = error {} else { Issue.record("Wrong resource failure") } }
        if kind != 0 { #expect(work.operations>0);#expect(work.peakScalarStorage>0) }
    }
    @Test func malformedAndNonfiniteInputsAreTypedFailures() throws {
        let p=try ComplexSpectrumFixtures.policy(dimension:2);var w=try ComplexSpectrumFixtures.work()
        #expect(throws:ComplexSpectrumError.self) { try ReferenceComplexSpectralSolver().solve(ComplexSpectrumFixtures.matrix([1,2,3],n:2),policy:p,work:&w) }
        #expect(throws:ComplexSpectrumError.self) { try ReferenceComplexSpectralSolver().solve(ComplexSpectrumFixtures.matrix([Double.nan],n:1),policy:p,work:&w) }
        #expect(throws:ComplexSpectrumError.self) { try ReferenceComplexSpectralSolver().solve(ComplexSpectrumFixtures.matrix([],n:Int.max),policy:p,work:&w) }
    }
}
