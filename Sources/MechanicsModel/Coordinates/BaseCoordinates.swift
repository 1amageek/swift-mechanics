public struct BaseCoordinates: Equatable, Sendable {
    public let q: [Double]
    public let v: [Double]

    public init(q: [Double], v: [Double]) throws(ModelError) {
        guard q.allSatisfy({ $0.isFinite }), v.allSatisfy({ $0.isFinite }) else { throw .nonFiniteCoordinates }
        self.q = q
        self.v = v
    }
}
