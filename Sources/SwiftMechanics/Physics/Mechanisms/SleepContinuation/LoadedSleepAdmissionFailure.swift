public struct LoadedSleepAdmissionFailure:Error,Sendable {
    public let cause:RuntimeFailure
    public let loads:StationaryLoadWorkReport
}
