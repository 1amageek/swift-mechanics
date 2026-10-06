public enum XMLFailureReason: Equatable, Sendable {
    case invalidPolicy, arithmeticOverflow, cancelled
    case limit(XMLResource, Int)
    case invalidUTF8, invalidCharacter, unexpectedEnd, malformedSyntax
    case invalidName, duplicateAttribute, mismatchedTag, missingRoot, multipleRoots
    case invalidComment, invalidReference, undeclaredEntity
    case unsupportedEncoding, unsupportedVersion, unsupportedDeclaration
    case unsupportedDTD, unsupportedProcessingInstruction, unsupportedNamespaces
    case invalidDocument
}
