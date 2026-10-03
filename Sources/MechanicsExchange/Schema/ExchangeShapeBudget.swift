internal struct ExchangeShapeBudget {
    var records=0,elements=0,metadataBytes=0
    mutating func count(_ count:Int,record:Bool,policy:ExchangePolicy) throws(ExchangeError) {
        guard count <= policy.maximumArrayElements else { throw .resourceLimit(resource:.elements,limit:policy.maximumArrayElements) }
        elements=try ExchangeWork.sum(elements,count)
        guard elements <= policy.maximumArrayElements else { throw .resourceLimit(resource:.elements,limit:policy.maximumArrayElements) }
        if record {
            records=try ExchangeWork.sum(records,count)
            guard records <= policy.maximumRecords else { throw .resourceLimit(resource:.records,limit:policy.maximumRecords) }
        }
    }
    mutating func text(_ count:Int,policy:ExchangePolicy) throws(ExchangeError) {
        guard count <= policy.maximumStringBytes else { throw .resourceLimit(resource:.stringBytes,limit:policy.maximumStringBytes) }
        metadataBytes=try ExchangeWork.sum(metadataBytes,count)
        guard metadataBytes <= policy.maximumMetadataBytes else { throw .resourceLimit(resource:.metadataBytes,limit:policy.maximumMetadataBytes) }
    }
}
