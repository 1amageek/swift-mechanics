/// Cooperative bounded, pure provider. Shared provider references must use the same isolation on every target.
public protocol CustomLoadProvider: Sendable {
    var identity: Int { get }
    var coordinateKind: ScalarCoordinateKind { get }
    func response(coordinate: Double, rate: Double, state: CustomLoadState,
                  work: inout LoadWork) throws(LoadError) -> ScalarLoadResponse
}
