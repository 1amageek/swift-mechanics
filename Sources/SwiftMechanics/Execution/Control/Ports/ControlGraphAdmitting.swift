public protocol ControlGraphAdmitting: Sendable {
    func admit(dimensions:[PhysicalDimension],directFeedthrough:[Bool],connections:[ControlConnection],policy:ControlPolicy,work:inout NumericalWork) throws(ControlFailure)
}
