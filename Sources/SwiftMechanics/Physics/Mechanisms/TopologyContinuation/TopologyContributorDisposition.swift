@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
public enum TopologyContributorDisposition: Sendable {
    case appendHistory
    case preserve(id:String,validator:any RuntimeContributorHandling)
    case migrateScalarActuator(binding:ActuatorBinding,controlBudget:ActuationBudget)
    case initializeIntegration(retiredID:String,provider:IntegrationContinuationProvider,equations:any SmoothODEEquations)
    public var sourceID:String {
        switch self {
        case .appendHistory: "mechanics.mechanisms.topology.v1"
        case .preserve(let id,_): id
        case .migrateScalarActuator(let binding,_): binding.actuator.key
        case .initializeIntegration(let id,_,_): id
        }
    }
}
