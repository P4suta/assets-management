import Foundation
import QuickLook
import SwiftUI
import Testing
@testable import PropertyRecords

@Suite @MainActor struct ExternalNavigationTests {
    @Test(arguments: ["https://assets-management.yasunobu.dev/privacy/", "mailto:example@example.com", "app-settings:"])
    func externalDestinationsWaitForConfirmation(address: String) throws {
        let url = try #require(URL(string: address))
        let navigation = ExternalNavigation()
        #expect(navigation.confirm() == nil)
        #expect(navigation.request(url) == .confirmation)
        #expect(navigation.destination == url)
        #expect(navigation.isPresented)
        navigation.isPresented = false
        #expect(navigation.confirm() == url)
        #expect(navigation.confirm() == nil)
        #expect(navigation.destination == nil)
    }

    @Test func cancellationAndConcurrentRequestsCannotOpenAnotherDestination() throws {
        let first = try #require(URL(string: "https://assets-management.yasunobu.dev/privacy/"))
        let second = try #require(URL(string: "https://assets-management.yasunobu.dev/support/"))
        let navigation = ExternalNavigation()
        #expect(navigation.request(first) == .confirmation)
        #expect(navigation.request(second) == .ignored)
        #expect(navigation.destination == first)
        navigation.cancel()
        #expect(!navigation.isPresented)
        #expect(navigation.confirm() == nil)
        #expect(navigation.request(second) == .confirmation)
        #expect(navigation.confirm() == second)
    }

    @Test func telephoneLinksUseTheSystemConfirmation() throws {
        let url = try #require(URL(string: "tel:+12025550142"))
        let navigation = ExternalNavigation()
        #expect(navigation.request(url) == .system)
        #expect(navigation.destination == nil)
        #expect(!navigation.isPresented)
        #expect(navigation.confirm() == nil)
    }

    @Test func settingsHaveAReadableDestinationAndRetryClearsFailure() throws {
        let url = try #require(URL(string: "app-settings:notifications"))
        let navigation = ExternalNavigation()
        navigation.failure = url
        #expect(ExternalNavigation.description(for: url) == "設定App")
        #expect(navigation.request(url) == .confirmation)
        #expect(navigation.failure == nil)
    }

    @Test func rejectedHandoffsReportFailureAndConfirmedRetriesOpenOnce() throws {
        let url = try #require(URL(string: "https://assets-management.yasunobu.dev/support/"))
        let navigation = ExternalNavigation()
        var opened: [URL] = []
        let unavailable = OpenURLAction {
            opened.append($0)
            return .discarded
        }
        #expect(navigation.request(url) == .confirmation)
        navigation.openConfirmed(using: unavailable)
        #expect(opened == [url])
        #expect(navigation.failure == url)
        #expect(navigation.destination == nil)
        #expect(!navigation.isPresented)
        navigation.openConfirmed(using: unavailable)
        #expect(opened == [url])
        #expect(navigation.request(url) == .confirmation)
        let available = OpenURLAction {
            opened.append($0)
            return .handled
        }
        navigation.openConfirmed(using: available)
        #expect(opened == [url, url])
        #expect(navigation.failure == nil)
    }

    @Test func documentLinksRequestConfirmationInsteadOfOpeningDirectly() async throws {
        let url = try #require(URL(string: "https://assets-management.yasunobu.dev/support/"))
        let navigation = ExternalNavigation()
        let item = DocumentPreviewItem(url: URL(fileURLWithPath: "/fixture.pdf"), title: "Fixture")
        let (destinations, continuation) = AsyncStream<URL>.makeStream()
        let preview = NativeDocumentPreview(item: item) {
            _ = navigation.request($0)
            continuation.yield($0)
        }
        let coordinator = preview.makeCoordinator()
        #expect(!coordinator.previewController(QLPreviewController(), shouldOpen: url, for: coordinator.item))
        var iterator = destinations.makeAsyncIterator()
        #expect(await iterator.next() == url)
        continuation.finish()
        #expect(navigation.destination == url)
        #expect(navigation.isPresented)
        navigation.cancel()
        #expect(navigation.confirm() == nil)
    }
}
