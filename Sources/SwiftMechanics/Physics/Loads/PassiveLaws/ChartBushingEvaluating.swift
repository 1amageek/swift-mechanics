public protocol ChartBushingEvaluating: Sendable {
    func evaluate(_ bushing: PassiveChartBushing, strain: [Double], rate: [Double], work: inout LoadWork) throws(LoadError) -> ChartBushingResponse
    func tangent(_ bushing: PassiveChartBushing, damping: Bool, work: inout LoadWork) throws(LoadError) -> [Double]
}
