import Testing
import MechanicsCore
import MechanicsNumerics
import MechanicsFlexible
@testable import MechanicsStructuralAnalysis
struct HarmonicPhysicsTests {
    static func tolerance() throws -> LinearTolerance<Double> { try LinearTolerance(absoluteResidual:1e-11,relativeResidual:1e-10,pivotThreshold:1e-14) }
    static func excitation(_ n:Int,omega:Double,force:Double=1,maximum:Double=100) -> HarmonicExcitation {
        HarmonicExcitation(identity:"harmonic-force",angularFrequency:omega,maximumAngularFrequency:10000,maximumNormalizedAmplitude:maximum,
            realEffort:[Double](repeating:force,count:n),imaginaryEffort:[Double](repeating:0,count:n),outputMap:[Double](repeating:2,count:n),outputDimensions:[.length])
    }
    @Test func actualBeamSingleCoordinateMatchesComplexOscillatorAmplitudeAndPhase() throws {
        let beam=try StructuralFixtures.beam(elements:1,massDamping:4),pencil=try StructuralFixtures.pencil(beam,fixed:[0,1,3])
        let l=beam.beam.length,k=12*beam.youngModulus*beam.beam.secondMoment/(l*l*l),m=156*beam.beam.density*beam.beam.area*l/420,c=4*m,omega=3.0
        let real=k-m*omega*omega,imaginary=omega*c,denominator=real*real+imaginary*imaginary
        var w=try StructuralFixtures.work();let service:any HarmonicAnalyzing=ReferenceHarmonicAnalyzer()
        let result=try service.response(pencil,expectedBinding:pencil.binding,excitation:Self.excitation(1,omega:omega),linearTolerance:Self.tolerance(),policy:StructuralFixtures.policy(),work:&w)
        #expect(StructuralFixtures.close(result.coordinates[0].real,real/denominator,1e-10));#expect(StructuralFixtures.close(result.coordinates[0].imaginary,-imaginary/denominator,1e-10))
        #expect(StructuralFixtures.close(result.outputs[0].real,2*real/denominator,1e-10));#expect(result.outputs[0].phaseRadians!<0)
        #expect(result.maximumOriginalResidual<1e-8)
        var resonant=try StructuralFixtures.work();let frequency=(k/m).squareRoot()
        let atResonance=try service.response(pencil,expectedBinding:pencil.binding,excitation:Self.excitation(1,omega:frequency),linearTolerance:Self.tolerance(),policy:StructuralFixtures.policy(),work:&resonant)
        #expect(StructuralFixtures.close(atResonance.outputs[0].phaseRadians!,-3.141592653589793/2,1e-10));#expect(StructuralFixtures.close(atResonance.coordinates[0].amplitude,1/(frequency*c),1e-10))
    }
    @Test func underCriticalAndOverDampedPolesSatisfyActualQuadratic() throws {
        let undamped=try StructuralFixtures.beam(elements:1),base=try StructuralFixtures.pencil(undamped,fixed:[0,1,3])
        let natural=(base.stiffness[0]/base.mass[0]).squareRoot(),service:any ModalAnalyzing=ReferenceModalAnalyzer()
        for alpha in [natural,2*natural,3*natural] {
            let pencil=try StructuralFixtures.pencil(StructuralFixtures.beam(elements:1,massDamping:alpha),fixed:[0,1,3]);var w=try StructuralFixtures.work()
            let result=try service.dampedModes(pencil,expectedBinding:pencil.binding,massDamping:alpha,stiffnessDamping:0,policy:StructuralFixtures.policy(),work:&w)
            let z=result.firstPoles[0]
            #expect(StructuralFixtures.close(z.real*z.real-z.imaginary*z.imaginary+alpha*z.real+natural*natural,0,1e-7))
            #expect(StructuralFixtures.close(2*z.real*z.imaginary+alpha*z.imaginary,0,1e-7))
            #expect(result.maximumOriginalQuadraticResidual<1e-6)
            if alpha==natural { #expect(z.imaginary>0) };if alpha==3*natural { #expect(z.imaginary==0);#expect(result.secondPoles[0].real<0) }
        }
    }
    @Test func responseValidityZeroPhaseAndSingularityAreExplicit() throws {
        let beam=try StructuralFixtures.beam(elements:1,massDamping:4),pencil=try StructuralFixtures.pencil(beam,fixed:[0,1,3]),service:any HarmonicAnalyzing=ReferenceHarmonicAnalyzer()
        var w=try StructuralFixtures.work();let zero=try service.response(pencil,expectedBinding:pencil.binding,excitation:Self.excitation(1,omega:0,force:0),linearTolerance:Self.tolerance(),policy:StructuralFixtures.policy(),work:&w)
        #expect(zero.outputs[0].phaseRadians==nil);#expect(zero.outputs[0].amplitude==0)
        #expect(throws:StructuralError.self) { try service.response(pencil,expectedBinding:pencil.binding,excitation:Self.excitation(1,omega:-1),linearTolerance:Self.tolerance(),policy:StructuralFixtures.policy(),work:&w) }
        #expect(throws:StructuralError.self) { try service.response(pencil,expectedBinding:pencil.binding,excitation:Self.excitation(1,omega:1,maximum:1e-20),linearTolerance:Self.tolerance(),policy:StructuralFixtures.policy(),work:&w) }
        #expect(throws:StructuralError.self) { try service.response(pencil,expectedBinding:pencil.binding,excitation:Self.excitation(1,omega:1,force:1000,maximum:100),linearTolerance:Self.tolerance(),policy:StructuralFixtures.policy(),work:&w) }
        let free=try StructuralFixtures.pencil(StructuralFixtures.beam(elements:1),fixed:[])
        let tolerance=try Self.tolerance(),policy=try StructuralFixtures.policy()
        do throws(StructuralError) { _=try service.response(free,expectedBinding:free.binding,excitation:Self.excitation(free.count,omega:0),linearTolerance:tolerance,policy:policy,work:&w);Issue.record("Singular free beam accepted") }
        catch { if case .numerical(.singular,failedSupplierWorkUnavailable:true) = error {} else { Issue.record("Wrong failure") } }
    }
    @Test func nonproportionalDampedEigenanalysisIsTypedUnsupported() throws {
        let pencil=try StructuralFixtures.pencil(StructuralFixtures.beam()),service:any ModalAnalyzing=ReferenceModalAnalyzer();var w=try StructuralFixtures.work();let policy=try StructuralFixtures.policy()
        do throws(StructuralError) { _=try service.nonproportionalDampedModes(pencil,expectedBinding:pencil.binding,policy:policy,work:&w);Issue.record("Deferred domain accepted") }
        catch { if case .unsupportedDomain = error {} else { Issue.record("Wrong failure") } }
    }
}
