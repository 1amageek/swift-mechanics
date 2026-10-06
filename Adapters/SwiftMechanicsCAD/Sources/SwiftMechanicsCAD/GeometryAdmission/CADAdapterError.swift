import CADCore
import CADIR
import SwiftMechanics

public enum CADAdapterError: Error, Sendable {
    case invalidInput
    case unsupportedSource
    case staleSource
    case duplicateOccurrence
    case missingOccurrence
    case missingBody
    case ambiguousBody
    case missingDensity
    case contradictoryMaterial
    case wrongAnchor
    case capacityExceeded
    case cancelled
    case exactMomentsUnavailable
    case kernel(KernelError)
    case feature(FeatureEvaluationError)
    case topology(TopologyError)
    case material(CADCore.MaterialError)
    case geometry(GeometryError)
    case unit(UnitError)
    case schema(SchemaError)
    case parameter(ParameterError)
    case core(CoreError)
    case providerFailure
}

func cadCall<Value>(_ body: () throws -> Value) throws(CADAdapterError) -> Value {
    do { return try body() }
    catch let e as CADAdapterError { throw e }
    catch let e as KernelError { throw .kernel(e) }
    catch let e as FeatureEvaluationError { throw .feature(e) }
    catch let e as TopologyError { throw .topology(e) }
    catch let e as CADCore.MaterialError { throw .material(e) }
    catch let e as GeometryError { throw .geometry(e) }
    catch let e as UnitError { throw .unit(e) }
    catch let e as SchemaError { throw .schema(e) }
    catch let e as ParameterError { throw .parameter(e) }
    catch let e as CoreError { throw .core(e) }
    catch { throw .providerFailure }
}
