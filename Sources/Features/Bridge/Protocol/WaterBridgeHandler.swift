//
//  File.swift
//  WaterBridgeKit
//
//  Created by hugh paak on 11/10/26.
//
// Bridge 처리를 위한 Handler 기본 골격

import Foundation

@MainActor
protocol WaterBridgeHandler {
    var api: String { get }
    
    func handle(
        _ message: WaterBridgeMessage,
        context: WaterBridgeRouteContext
    ) -> Any
}
