internal enum WheeledAssemblySupplier {
    static func core<T>(_ operation: () throws(CoreError) -> T) throws(WheeledAssemblyFailure) -> T {
        do { return try operation() } catch { throw .core(error) }
    }
    static func compilation<T>(_ operation: () throws(CompilationFailure) -> T) throws(WheeledAssemblyFailure) -> T {
        do { return try operation() } catch { throw .compilation(error) }
    }
    static func joints<T>(_ operation: () throws(JointError) -> T) throws(WheeledAssemblyFailure) -> T {
        do { return try operation() } catch { throw .joints(error) }
    }
    static func loads<T>(_ operation: () throws(LoadError) -> T) throws(WheeledAssemblyFailure) -> T {
        do { return try operation() } catch { throw .loads(error) }
    }
    static func actuation<T>(_ operation: () throws(ActuationError) -> T) throws(WheeledAssemblyFailure) -> T {
        do { return try operation() } catch { throw .actuation(error) }
    }
    static func dynamics<T>(_ work: inout WheeledAssemblyWork, _ operation: (inout LoadWork, inout NumericalWork) throws(DynamicsError) -> T) throws(WheeledAssemblyFailure) -> T {
        do { return try operation(&work.loads, &work.numerical) }
        catch {
            if error.failedSupplierWorkUnavailable { work.terminal = true }
            throw .dynamics(error)
        }
    }
    static func numerical<T>(_ operation: () throws(NumericalError) -> T) throws(WheeledAssemblyFailure) -> T {
        do { return try operation() } catch { throw .numerical(error) }
    }
}
