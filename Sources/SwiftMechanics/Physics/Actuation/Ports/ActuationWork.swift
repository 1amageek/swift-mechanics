public struct ActuationWork: Sendable {
    public let budget:ActuationBudget
    public private(set) var used=0,peakScalars=0,peakBytes=0
    public init(budget:ActuationBudget) { self.budget=budget }
    public mutating func charge(_ amount:Int) throws(ActuationError) {
        guard !budget.isCancelled(),!Task.isCancelled else { throw .cancelled }
        let (next,overflow)=used.addingReportingOverflow(amount)
        guard amount >= 0,!overflow,next <= budget.maximumWork else { throw .workExhausted };used=next
    }
    public mutating func reserve(scalars:Int=0,bytes:Int=0) throws(ActuationError) {
        try charge(0);guard scalars >= 0,bytes >= 0,scalars <= budget.maximumScalars,bytes <= budget.maximumBytes else { throw .capacityExceeded }
        peakScalars=max(peakScalars,scalars);peakBytes=max(peakBytes,bytes)
    }
    public mutating func metadata(_ text:String) throws(ActuationError) {
        var count=0
        for _ in text.utf8 { try charge(1);guard count < budget.maximumMetadataBytes else { throw .capacityExceeded };count += 1 }
    }
}
