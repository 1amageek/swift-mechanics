internal enum DampedSpectrumArithmetic {
    static func check(_ p:StructuralPolicy) throws(GeneralDampedSpectrumCause) {
        guard !p.isCancelled(),!Task.isCancelled else { throw .structural(.cancelled) }
    }
    static func check(_ p:ComplexSpectrumPolicy) throws(GeneralDampedSpectrumCause) {
        guard !p.isCancelled(),!Task.isCancelled else { throw .spectral(.cancelled) }
    }
    static func product(_ a:Int,_ b:Int) throws(GeneralDampedSpectrumCause) -> Int {
        do { return try NumericalWork.product(a,b) } catch { throw .numerical(error) }
    }
    static func sum(_ a:Int,_ b:Int) throws(GeneralDampedSpectrumCause) -> Int {
        do { return try NumericalWork.sum(a,b) } catch { throw .numerical(error) }
    }
    static func charge(_ n:Int,_ w:inout NumericalWork) throws(GeneralDampedSpectrumCause) {
        do { try w.chargeOperations(n) } catch { throw .numerical(error) }
    }
    static func reserve(_ n:Int,_ w:inout NumericalWork) throws(GeneralDampedSpectrumCause) {
        do { try w.requireStorage(n) } catch { throw .numerical(error) }
    }
    static func finite(_ x:Double) throws(GeneralDampedSpectrumCause) -> Double {
        guard x.isFinite else { throw .structural(.nonFiniteResult) };return x
    }
    static func finite(_ x:SpectrumComplex) throws(GeneralDampedSpectrumCause) -> SpectrumComplex {
        guard x.real.isFinite,x.imaginary.isFinite,x.amplitude.isFinite else { throw .structural(.nonFiniteResult) };return x
    }
    // Physical complex quadratures use only the supplier's public raw value fields.
    static func multiply(_ x:SpectrumComplex,_ y:SpectrumComplex) throws(GeneralDampedSpectrumCause) -> SpectrumComplex {
        try finite(SpectrumComplex(real:x.real*y.real-x.imaginary*y.imaginary,imaginary:x.real*y.imaginary+x.imaginary*y.real))
    }
    static func scale(_ x:SpectrumComplex,_ y:Double) throws(GeneralDampedSpectrumCause) -> SpectrumComplex {
        try finite(SpectrumComplex(real:x.real*y,imaginary:x.imaginary*y))
    }
    static func add(_ x:SpectrumComplex,_ y:SpectrumComplex) throws(GeneralDampedSpectrumCause) -> SpectrumComplex {
        try finite(SpectrumComplex(real:x.real+y.real,imaginary:x.imaginary+y.imaginary))
    }
    static let zero = SpectrumComplex(real:0,imaginary:0)
}
