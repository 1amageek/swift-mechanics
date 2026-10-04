internal enum ComplexSpectrumArithmetic {
    static func check(_ policy: ComplexSpectrumPolicy) throws(ComplexSpectrumError) {
        guard !policy.isCancelled(),!Task.isCancelled else { throw .cancelled }
    }
    static func size(_ a:Int,_ b:Int) throws(ComplexSpectrumError) -> Int {
        do { return try NumericalWork.product(a,b) } catch { throw .numerical(error) }
    }
    static func sum(_ a:Int,_ b:Int) throws(ComplexSpectrumError) -> Int {
        do { return try NumericalWork.sum(a,b) } catch { throw .numerical(error) }
    }
    static func charge(_ count:Int,_ work:inout NumericalWork) throws(ComplexSpectrumError) {
        do { try work.chargeOperations(count) } catch { throw .numerical(error) }
    }
    static func reserve(_ count:Int,_ work:inout NumericalWork) throws(ComplexSpectrumError) {
        do { try work.requireStorage(count) } catch { throw .numerical(error) }
    }
    static func finite(_ value:SpectrumComplex) throws(ComplexSpectrumError) -> SpectrumComplex {
        guard value.finite else { throw .nonFiniteResult };return value
    }
    static func finite(_ value:Double) throws(ComplexSpectrumError) -> Double {
        guard value.isFinite else { throw .nonFiniteResult };return value
    }
}
