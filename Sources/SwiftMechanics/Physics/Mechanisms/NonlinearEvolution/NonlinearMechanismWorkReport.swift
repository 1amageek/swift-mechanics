public struct NonlinearMechanismWorkReport: Equatable, Sendable {
    public let failedSupplierWorkUnavailable: Bool
    public let outerArithmeticBoundCharged: Int
    public let supplierArithmeticCharged: Int
    public let supplierIterationsCharged: Int
    public let peakSupplierScalars: Int
    public let derivativeCalls: Int
    public let reservedCoordinateScalars: Int
    internal init(outer:Int = 0,supplier:Int = 0,calls:Int = 0,scalars:Int = 0,iterations:Int = 0,supplierScalars:Int = 0,unavailable:Bool = false) {
        failedSupplierWorkUnavailable=unavailable;outerArithmeticBoundCharged=outer;supplierArithmeticCharged=supplier
        supplierIterationsCharged=iterations;peakSupplierScalars=supplierScalars;derivativeCalls=calls;reservedCoordinateScalars=scalars
    }
}
