public struct StationaryLoadWorkReport: Sendable {
    public enum Scope:Equatable,Sendable { case equationExecution, checkpointAdmission }
    public enum Admission:Equatable,Sendable { case notAdmitted, admitted }
    public let scope:Scope
    public let admission:Admission
    public let maximumWork:Int
    public let maximumScalars:Int
    public let maximumInvocations:Int
    public let consumed:Int
    public let peakScalars:Int
    public let invocationsStarted:Int
    public let invocationsCompleted:Int
    public let failedSupplierWorkUnavailable:Bool
    public static func notAdmitted(scope:Scope,budget:LoadBudget,maximumInvocations:Int) -> Self {
        Self(scope:scope,admission:.notAdmitted,maximumWork:budget.maximumWork,maximumScalars:budget.maximumScalars,maximumInvocations:maximumInvocations,consumed:0,peakScalars:0,invocationsStarted:0,invocationsCompleted:0,failedSupplierWorkUnavailable:false)
    }
}
