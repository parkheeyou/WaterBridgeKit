#if os(iOS)
import XCTest
@testable import WaterBridgeKit

final class WaterPermissionTests: XCTestCase {
    func testDeniedPermissionsOfferAppSettings() throws {
        for permission in WaterPermission.allCases {
            let notice = try XCTUnwrap(WaterPermissionNotice.required(for: permission, status: .denied))
            XCTAssertTrue(notice.offersSettings)
            XCTAssertTrue(notice.message.contains(permission.title))
        }
    }

    func testRestrictedPermissionsDoNotPromiseSettingsCanGrantAccess() throws {
        let notice = try XCTUnwrap(WaterPermissionNotice.required(for: .camera, status: .restricted))
        XCTAssertFalse(notice.offersSettings)
        XCTAssertTrue(notice.message.contains("기기 관리"))
    }

    func testDisabledLocationServicesDescribeGlobalSetting() throws {
        let notice = try XCTUnwrap(WaterPermissionNotice.required(for: .location, status: .servicesDisabled))
        XCTAssertTrue(notice.offersSettings)
        XCTAssertTrue(notice.message.contains("개인정보 보호 및 보안"))
    }

    func testLimitedPhotoAccessIsUsableWithoutDeniedAlert() {
        XCTAssertTrue(WaterPermissionStatus.limited.isGranted)
        XCTAssertNil(WaterPermissionNotice.required(for: .photos, status: .limited))
    }

    func testUnrequestedAndAuthorizedStatesDoNotShowSettingsAlert() {
        XCTAssertFalse(WaterPermissionStatus.notDetermined.isGranted)
        XCTAssertTrue(WaterPermissionStatus.authorized.isGranted)
        for status in [WaterPermissionStatus.notDetermined, .authorized] {
            XCTAssertNil(WaterPermissionNotice.required(for: .camera, status: status))
        }
        for status in [WaterPermissionStatus.denied, .restricted, .servicesDisabled] {
            XCTAssertFalse(status.isGranted)
        }
    }
}
#endif
