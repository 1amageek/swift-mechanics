import Testing
@testable import MechanicsExchange
import MechanicsCore
import MechanicsModel
import MechanicsCompiler

@Suite struct CodecTests {
    @Test func completeWireAndUnicodeRoundTrip() throws {
        let source=try ExchangeFixtures.replace(ExchangeFixtures.document(q:[-0.0],v:[-0.0]),identity:"モデルe\u{301}")
        let bytes=try ExchangeFixtures.encode(source),decoded=try ExchangeFixtures.decode(bytes)
        #expect(Array(bytes.prefix(13)) == [83,77,78,88,1,0,0,0,0,0,0,0,1])
        #expect(decoded.document == source)
        #expect(Array(decoded.document.descriptor.identity.utf8) == Array(source.descriptor.identity.utf8))
        #expect(decoded.document.descriptor.initialState.q[0].bitPattern == (-0.0 as Double).bitPattern)
        #expect(decoded.document.descriptor.initialState.v[0].bitPattern == (-0.0 as Double).bitPattern)
        #expect(decoded.maximumComponentCorrection == 0 && decoded.correctedUnitRecords == 0)
        #expect(try ExchangeFixtures.encode(decoded.document) == bytes)
        for (mode,tag) in [(BodyMotionMode.static,UInt8(0)),(.prescribedKinematic,UInt8(1)),(.dynamic,UInt8(2))] {
            #expect(NativeWireTags.bodyMode(mode) == tag)
            #expect(try NativeWireTags.bodyMode(tag,at:0) == mode)
            let bodies=try [ExchangeFixtures.body("root",mode:.static),ExchangeFixtures.body("child",mode:mode)]
            let input=try ExchangeFixtures.replace(ExchangeFixtures.document(geometry:false),bodies:bodies)
            #expect(try ExchangeFixtures.decode(ExchangeFixtures.encode(input)).document == input)
        }
    }
    @Test func malformedHeaderTagsUTF8AndTruncation() throws {
        let bytes=try ExchangeFixtures.encode(ExchangeFixtures.document())
        var bad=bytes;bad[0]=0
        #expect(throws:ExchangeError.malformedHeader) { try ExchangeFixtures.decode(bad) }
        bad=bytes;ExchangeFixtures.setInteger(2,in:&bad,at:4)
        #expect(throws:ExchangeError.unsupportedVersion(2)) { try ExchangeFixtures.decode(bad) }
        bad=bytes;bad[12]=2
        #expect(throws:ExchangeError.unsupportedUnits(2)) { try ExchangeFixtures.decode(bad) }
        bad=bytes;bad[21]=0xc0
        #expect(throws:ExchangeError.invalidUTF8(offset:21)) { try ExchangeFixtures.decode(bad) }
        bad=bytes;bad.append(0)
        #expect(throws:ExchangeError.trailingBytes(offset:bytes.count)) { try ExchangeFixtures.decode(bad) }
        for end in [0,4,12,21,42,100,bytes.count-1] {
            #expect(throws:ExchangeError.self) { try ExchangeFixtures.decode(Array(bytes.prefix(end))) }
        }
        bad=bytes;bad[42]=255
        #expect(throws:ExchangeError.unknownTag(offset:42)) { try ExchangeFixtures.decode(bad) }
    }
    @Test func boundedCountsRejectBeforeRecordAllocation() throws {
        var bytes=try ExchangeFixtures.encode(ExchangeFixtures.document())
        ExchangeFixtures.setInteger(UInt64.max,in:&bytes,at:34)
        #expect(throws:ExchangeError.arithmeticOverflow) { try ExchangeFixtures.decode(bytes) }
        ExchangeFixtures.setInteger(1000,in:&bytes,at:34)
        var work=ExchangeWork(policy:try ExchangeFixtures.policy())
        #expect(throws:ExchangeError.truncated(offset:42)) { try SMNXNativeModelCodec().decode(bytes:bytes,work:&work) }
        #expect(work.allocationBytes == 5)
    }
    @Test func normalizationAuthorityAndNonfiniteScalar() throws {
        var bytes=try ExchangeFixtures.encode(ExchangeFixtures.document())
        #expect(Array(bytes[76..<84]) == [0,0,0,0,0,0,240,63])
        let raw=1.0000000000005
        ExchangeFixtures.setInteger(raw.bitPattern,in:&bytes,at:76)
        let decoded=try ExchangeFixtures.decode(bytes)
        #expect(decoded.correctedUnitRecords == 1)
        #expect(decoded.maximumComponentCorrection == abs(raw-1))
        #expect(throws:ExchangeError.normalizationExceeded(value:abs(raw-1),limit:0)) { try ExchangeFixtures.decode(bytes,policy:ExchangeFixtures.policy(correction:0)) }
        ExchangeFixtures.setInteger(Double.nan.bitPattern,in:&bytes,at:76)
        #expect(throws:ExchangeError.nonfiniteScalar(offset:76)) { try ExchangeFixtures.decode(bytes) }
    }
    @Test func strictUTF8RejectsNonScalarAndOverlongSequences() throws {
        for bytes:[UInt8] in [[0xc0,0x80],[0xed,0xa0,0x80],[0xf4,0x90,0x80,0x80],[0xe2,0x82],[0x80]] {
            #expect(throws:ExchangeError.self) { try NativeUTF8Validation.validate(bytes:bytes,range:0..<bytes.count) }
        }
        let bytes=Array("é日本😀".utf8)
        try NativeUTF8Validation.validate(bytes:bytes,range:0..<bytes.count)
    }
    @Test func allBudgetsAndCancellationAreFailures() async throws {
        let document=try ExchangeFixtures.document(),bytes=try ExchangeFixtures.encode(document)
        let policies=try [ExchangeFixtures.policy(bytes:1),ExchangeFixtures.policy(records:3),ExchangeFixtures.policy(elements:0),
                          ExchangeFixtures.policy(string:1),ExchangeFixtures.policy(metadata:1),ExchangeFixtures.policy(allocation:0),ExchangeFixtures.policy(operations:0)]
        for policy in policies {
            #expect(throws:ExchangeError.self) { try ExchangeFixtures.encode(document,policy:policy) }
            #expect(throws:ExchangeError.self) { try ExchangeFixtures.decode(bytes,policy:policy) }
        }
        let task=Task { () throws -> Void in
            withUnsafeCurrentTask { $0?.cancel() }
            #expect(throws:ExchangeError.cancelled) { try ExchangeFixtures.decode(bytes) }
            #expect(throws:ExchangeError.cancelled) { try ExchangeFixtures.encode(document) }
        }
        try await task.value
    }
}
