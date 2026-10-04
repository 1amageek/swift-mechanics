public enum TopologyReleaseFailure: Error, Sendable {
    case invalidInput, staleSource, unsupportedDomain, capacityExceeded, cancelled, originalAcceptance
    case supplierWorkUnavailable
    case compilation(CompilationFailure)
    case dynamics(DynamicsError)
    case numerical(NumericalError)
    case actuation(ActuationError)
    case runtime(RuntimeFailure)
    public var failedSupplierWorkUnavailable: Bool {
        switch self {
        case .supplierWorkUnavailable: true
        case .dynamics(.numerical(_, let unknown)): unknown
        case .runtime(let failure): failure.failedSupplierWorkUnavailable
        default: false
        }
    }
}

internal enum TopologyArithmetic {
    static func numerical<T>(_ body: () throws(NumericalError) -> T) throws(TopologyReleaseFailure) -> T {
        do throws(NumericalError) { return try body() } catch { throw .numerical(error) }
    }
    static func charge(_ count: Int, _ work: inout NumericalWork) throws(TopologyReleaseFailure) {
        try numerical { () throws(NumericalError) in try work.chargeOperations(count) }
    }
    static func preserved(_ before: NumericalWork, _ after: NumericalWork) -> Bool {
        before.budget == after.budget && after.operations >= before.operations && after.iterations >= before.iterations && after.peakScalarStorage >= before.peakScalarStorage
    }
    static func dynamics<T>(_ work: inout NumericalWork, _ body: (inout NumericalWork) throws(DynamicsError) -> T) throws(TopologyReleaseFailure) -> T {
        try charge(1, &work)
        let before = work
        let value: T
        do throws(DynamicsError) { value = try body(&work) }
        catch {
            guard preserved(before, work) else { work = before; throw .supplierWorkUnavailable }
            throw .dynamics(error)
        }
        guard preserved(before, work) else { work = before; throw .supplierWorkUnavailable }
        return value
    }
}
