@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
public protocol ControlSessionCreating: Sendable {
    func make(plant:PrismaticControlPlant,controller:SampledController,clock:ControlClock,initialActuator:ActuatorState,
              seed:UInt64,policy:ControlPolicy,work:inout NumericalWork) throws(ControlFailure) -> any ControlSessionOperating
}
