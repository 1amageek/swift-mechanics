import SwiftMechanics
import Testing

@Suite struct IntegrationEndpointProposalTests {
    @Test func proposedEndpointRequiresActualPhysicalAssociation() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else {
            Issue.record("Runtime OS baseline unavailable."); return
        }
        let model = try IntegrationFixtures.model()
        let equation = try ManufacturedHingeEquation(model: model)
        let provider = try IntegrationContinuationProvider(descriptor: equation.descriptor,
                                                         policy: IntegrationFixtures.policy())
        let record = try provider.record(acceptedTime: 0.2, point: [0.4, 3], nextStep: 0.1,
                                         acceptedSteps: 2, normalizedError: nil)
        let physical = try KinematicState(revision: model.stamp.revision, time: 0.2,
                                         q: [0.4], v: [3], acceleration: [2])
        let history = try provider.associatedHistory(record, physical: physical, equations: equation)
        #expect(history.acceptedTime == 0.2 && history.acceptedPoint == [0.4, 3])
        #expect(history.nextStep == 0.1 && history.acceptedSteps == 2 && history.normalizedError == nil)
        #expect(try provider.record(history) == record)
        do throws(RuntimeFailure) {
            _ = try provider.associatedHistory(record, physical: model.descriptor.initialState, equations: equation)
            Issue.record("A proposed record certified a different physical state.")
        } catch { #expect(error.code == .invalidContributor) }
    }

    @Test func invalidEndpointFieldsFailBeforeSerialization() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else {
            Issue.record("Runtime OS baseline unavailable."); return
        }
        let model = try IntegrationFixtures.model()
        let equation = try ManufacturedHingeEquation(model: model)
        let provider = try IntegrationContinuationProvider(descriptor: equation.descriptor,
                                                         policy: IntegrationFixtures.policy())
        let cases: [(Double, [Double], Double, Double?)] = [
            (.infinity, [0, 2], 0.1, nil),
            (0, [0], 0.1, nil),
            (0, [.nan, 2], 0.1, nil),
            (0, [0, 2], 0, nil),
            (0, [0, 2], 0.1, 0.5),
        ]
        for (time, point, step, error) in cases {
            do throws(RuntimeFailure) {
                _ = try provider.record(acceptedTime: time, point: point, nextStep: step,
                                        acceptedSteps: 1, normalizedError: error)
                Issue.record("An invalid endpoint proposal serialized successfully.")
            } catch { #expect(error.code == .invalidContributor) }
        }
    }
}
