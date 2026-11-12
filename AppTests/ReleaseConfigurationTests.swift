import Foundation
import Testing
import UIKit
@testable import PropertyRecords

@Suite @MainActor struct ReleaseConfigurationTests {
    #if DEBUG
    @Test func developmentPhotographAndItsLicenseAreAvailableForNativeJourneys() throws {
        #expect(SamplePDF.photoData()?.isEmpty == false)
        _ = try #require(Bundle.main.url(forResource: "PhotoLicense", withExtension: "txt"))
    }
    #endif

    @Test func applicationBundleIncludesThePrimaryAppIcon() throws {
        let icons = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any])
        let primary = try #require(icons["CFBundlePrimaryIcon"] as? [String: Any])
        #expect(primary["CFBundleIconName"] as? String == "AppIcon")
        let files = try #require(primary["CFBundleIconFiles"] as? [String])
        #expect(!files.isEmpty)
        for file in files {
            #expect(UIImage(named: file, in: .main, compatibleWith: nil) != nil)
        }
    }

    @Test func applicationBundleHasTheDeclaredReleaseAndPrivacyValues() throws {
        let bundle = Bundle.main
        #expect(bundle.bundleIdentifier == "com.p4suta.PropertyRecords")
        #expect(bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String == "1.0.0")
        let build = try #require(bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
        #expect(Int(build).map { $0 > 0 } == true)
        #expect(bundle.object(forInfoDictionaryKey: "MinimumOSVersion") as? String == "26.0")
        #expect(bundle.object(forInfoDictionaryKey: "ITSAppUsesNonExemptEncryption") as? Bool == false)
        #expect(bundle.object(forInfoDictionaryKey: "NSUserTrackingUsageDescription") == nil)
        let privacyURL = try #require(bundle.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let privacy = try #require(PropertyListSerialization.propertyList(from: Data(contentsOf: privacyURL), format: nil) as? [String: Any])
        #expect(privacy["NSPrivacyTracking"] as? Bool == false)
        #expect((privacy["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true)
        #expect((privacy["NSPrivacyAccessedAPITypes"] as? [Any])?.isEmpty == true)
    }

    @Test func publicLinksUseTheApprovedHostWithoutPrivateParameters() throws {
        for value in [AppInformation.privacyURL, AppInformation.supportURL] {
            let url = try #require(value)
            #expect(url.scheme == "https")
            #expect(url.host == "assets-management.yasunobu.dev")
            #expect(url.user == nil)
            #expect(url.password == nil)
            #expect(url.query == nil)
            #expect(url.fragment == nil)
        }
        #expect(AppInformation.privacyURL?.path == "/privacy")
        #expect(AppInformation.supportURL?.path == "/support")
    }

    @Test func applicationBundleSupportsResizablePhoneAndTabletScenes() throws {
        let data = try Data(contentsOf: Bundle.main.bundleURL.appendingPathComponent("Info.plist"))
        let manifest = try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        let families = try #require(manifest["UIDeviceFamily"] as? [Int])
        #expect(Set(families) == [1, 2])
        #expect(manifest["UIRequiresFullScreen"] == nil)
        let orientations = try #require(manifest["UISupportedInterfaceOrientations~ipad"] as? [String])
        #expect(Set(orientations) == ["UIInterfaceOrientationPortrait", "UIInterfaceOrientationPortraitUpsideDown",
                                      "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"])
    }
}
