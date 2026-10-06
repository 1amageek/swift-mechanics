public struct WheeledAssemblyActuation: Sendable {
    public let steering: ActuatorResponse
    public let driveline: TransmissionResponse
    public let rearBrakeTorque, frontBrakeTorque: Double
    /// Held internal joint efforts; already included as known actuator loads in the original solve.
    public let efforts: [Double]
    internal init(steering: ActuatorResponse, driveline: TransmissionResponse, rearBrakeTorque: Double, frontBrakeTorque: Double, efforts: [Double]) {
        self.steering=steering; self.driveline=driveline; self.rearBrakeTorque=rearBrakeTorque
        self.frontBrakeTorque=frontBrakeTorque; self.efforts=efforts
    }
}
