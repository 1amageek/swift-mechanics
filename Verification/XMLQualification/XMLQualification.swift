import XMLQualificationSupport

@main
struct XMLQualification {
    static func main() throws {
        try XMLQualificationCases.decodeOriginal(); print("XML original UTF8/declaration/mixed-content/parent/normalization witness passed")
        try XMLQualificationCases.manualWriter(); print("XML independent authored document/exact writer bytes witness passed")
        try XMLQualificationCases.originalScalarAndDeclarationCases(); print("XML original scalar/declaration/lexical-name witness passed")
        try XMLQualificationCases.malformedAndUnsupported(); print("XML malformed/unsupported/line-byte diagnostic witness passed")
        try XMLQualificationCases.writerFailures(); print("XML transactional authored table failure witness passed")
        try XMLQualificationCases.budgetsAndLimits(); print("XML budget/depth/count/exact-limit witness passed")
        print("XML selected synchronous public prerequisite qualification completed")
    }
}
