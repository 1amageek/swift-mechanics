
public struct ODEDescriptor: Equatable, Sendable {
    public let identity: String
    public let chart: String
    public let model: ModelStamp
    public let dimensions: [PhysicalDimension]
    public init(identity: String, chart: String, model: ModelStamp, dimensions: [PhysicalDimension], maximumIdentityBytes: Int, maximumCoordinates: Int) throws(RuntimeFailure) {
        guard maximumIdentityBytes >= 0, maximumCoordinates >= 0, !identity.isEmpty, !chart.isEmpty,
              identity.utf8.count <= maximumIdentityBytes, chart.utf8.count <= maximumIdentityBytes,
              model.identity.utf8.count <= maximumIdentityBytes, !dimensions.isEmpty, dimensions.count <= maximumCoordinates else {
            throw RuntimeFailure(.capacityExceeded, message: "Equation descriptor exceeds declared identity/coordinate bounds.")
        }
        self.identity = identity; self.chart = chart; self.model = model; self.dimensions = dimensions
    }
}
