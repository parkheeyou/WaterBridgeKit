//
//  File.swift
//  WaterBridgeKit
//
//  Created by hugh paak on 11/10/26.
//
// Bridge 처리를 위한 Handler 기본 골격

import Foundation

@MainActor
public protocol WaterBridgeHandler {
    var api: String { get }
    
    // 동기 응답
    func handle(
        _ message: WaterBridgeMessage,
        context: WaterBridgeRouteContext
    ) -> Any
    
    // 비동기 응답
    func asyncHandle(
        _ message: WaterBridgeMessage,
        context: WaterBridgeRouteContext
    ) async -> Any
}
