import MechanicsModel
// Borrowed UTF8 views allocate no intermediate key array. Caller work bounds each scan.
internal func contactAccountKey(_ key: String, work: inout ContactWork) throws(ContactLawError) {
    for _ in key.utf8 { try work.consume(operations:2,scalarStorage:0,records:0) }
}
internal func contactAccountIdentity(_ identity: ContactIdentity, work: inout ContactWork) throws(ContactLawError) {
    try contactAccountKey(identity.key,work:&work)
    try contactAccountKey(identity.firstBody.id.key,work:&work)
    try contactAccountKey(identity.secondBody.id.key,work:&work)
    try contactAccountKey(identity.frame.id.key,work:&work)
}
internal func contactAccountPair(_ pair: ContactLawPair, work: inout ContactWork) throws(ContactLawError) {
    try contactAccountKey(pair.firstMaterial.id.key,work:&work)
    try contactAccountKey(pair.secondMaterial.id.key,work:&work)
}
