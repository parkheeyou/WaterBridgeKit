import XCTest
@testable import WaterBridgeKit
final class WaterBridgeAsyncRouteTests:XCTestCase {
 @MainActor func testResponseWaitsForAsyncHandlerAndPreservesSyncRoutes() async throws {
   var complete=false
   var pending:CheckedContinuation<Void,Never>?
   let router=WaterBridgeRouter(configuration:.init(additionalRoutes:[WaterBridgeRoute(api:"delayed",version:1,asyncHandler:{_,_ in
     await withCheckedContinuation {pending=$0};complete=true;return WaterBridgeResponse.success(data:["done":true]).value
   })]))
   let task=Task { @MainActor in
     let response=await router.responseAsync(for:WaterBridgeMessage(channel:"Bridge",body:["api":"water://delayed"],sourceURL:nil)) as? [String:Any]
     return (response?["status"] as? [String:Any])?["code"] as? String
   }
   for _ in 0..<100 {if pending != nil {break};await Task.yield()}
   XCTAssertFalse(complete);XCTAssertNotNil(pending);pending?.resume();let code=await task.value;XCTAssertEqual(code,"0000")
   let response=await router.responseAsync(for:WaterBridgeMessage(channel:"Bridge",body:["api":"water://routeApiList"],sourceURL:nil)) as? [String:Any]
   XCTAssertEqual((response?["status"] as? [String:Any])?["code"] as? String,"0000")
 }
}
