internal enum InertialParameterArithmetic {
    static func core<T>(_ body: () throws(CoreError) -> T) throws(InertialParameterError) -> T {
        do { return try body() } catch { throw .core(error) }
    }
    static func checkpoint(_ policy: DerivativePolicy) throws(InertialParameterError) {
        guard !policy.isCancelled(), !Task.isCancelled else { throw .cancelled }
    }
    static func charge(_ amount: Int, _ work: inout NumericalWork) throws(InertialParameterError) {
        guard !Task.isCancelled else { throw .cancelled }
        do { try work.chargeOperations(amount) } catch { throw .numerical(error) }
    }
    static func finite(_ value: Double) throws(InertialParameterError) -> Double {
        guard value.isFinite else { throw .nonFiniteResult }; return value
    }
    static func sum(_ a: Int, _ b: Int) throws(InertialParameterError) -> Int {
        do { return try NumericalWork.sum(a,b) } catch { throw .numerical(error) }
    }
    static func product(_ a: Int, _ b: Int) throws(InertialParameterError) -> Int {
        do { return try NumericalWork.product(a,b) } catch { throw .numerical(error) }
    }
    static func storage(_ count: Int, _ work: inout NumericalWork) throws(InertialParameterError) {
        do { try work.requireStorage(count) } catch { throw .numerical(error) }
    }
    static func nested(_ work: NumericalWork, reserved: Int) throws(InertialParameterError) -> NumericalWork {
        do { return NumericalWork(budget: try work.remainingBudget(reservedStorage: reserved)) }
        catch { throw .numerical(error) }
    }
    static func absorb(_ nested: NumericalWork, reserved: Int, into work: inout NumericalWork) throws(InertialParameterError) {
        do { try work.absorb(nested,reservedStorage: reserved) } catch { throw .numerical(error) }
    }
    static func call(_ supplier: inout DerivativeSupplierWork) throws(InertialParameterError) {
        do { try supplier.chargeCall() } catch { throw .derivative(error) }
    }
    static func bytes(_ value: String, _ policy: DerivativePolicy, _ work: inout NumericalWork) throws(InertialParameterError) {
        // Covers the byte scan and subsequent bounded identity/source equality comparisons.
        for _ in value.utf8 { try checkpoint(policy); try charge(3,&work) }
    }
    static func parallelAxis(_ c: Vector3) throws(CoreError) -> Matrix3 {
        try Matrix3(c.y*c.y+c.z*c.z,-c.x*c.y,-c.x*c.z,
                    -c.x*c.y,c.x*c.x+c.z*c.z,-c.y*c.z,
                    -c.x*c.z,-c.y*c.z,c.x*c.x+c.y*c.y)
    }
    static func parallelAxisDirection(_ c: Vector3, _ d: Vector3) throws(CoreError) -> Matrix3 {
        let xy = -d.x*c.y-c.x*d.y, xz = -d.x*c.z-c.x*d.z, yz = -d.y*c.z-c.y*d.z
        return try Matrix3(2*(c.y*d.y+c.z*d.z),xy,xz,
                           xy,2*(c.x*d.x+c.z*d.z),yz,
                           xz,yz,2*(c.x*d.x+c.y*d.y))
    }
    static func physical(mass: Double, firstMoment: Vector3, inertiaAtOrigin: Matrix3,
                         policy: InertiaValidationPolicy) throws(InertialParameterError) -> MassProperties3D {
        guard mass.isFinite, mass > 0 else { throw .model(.invalidMass) }
        let center = try core { () throws(CoreError) in try firstMoment.scaled(by: 1/mass) }
        let tensor = try core { () throws(CoreError) in
            try inertiaAtOrigin.subtracting(parallelAxis(center).scaled(by: mass))
        }
        do { return try MassProperties3D(mass: mass,centerOfMass: center,inertiaAtCenter: tensor,policy: policy) }
        catch let error as ModelError { throw .model(error) }
        catch let error as CoreError { throw .core(error) }
        catch { throw .unexpectedSupplierFailure }
    }
}
