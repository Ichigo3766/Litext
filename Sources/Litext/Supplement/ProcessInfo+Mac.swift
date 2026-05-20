//
//  ProcessInfo+Mac.swift
//  Litext
//
//  Provides a backwards-compatible helper for detecting "iPad app running on
//  Apple Silicon Mac" (isiOSAppOnMac). The underlying API requires iOS 14+, so
//  we gate it and return false on older targets.
//

import Foundation

extension ProcessInfo {
    /// True when this iPad app is running natively on an Apple Silicon Mac
    /// ("Designed for iPad" / iOS App on Mac). Always false on real iOS devices
    /// and on iOS < 14. Use this instead of `isiOSAppOnMac` directly so the
    /// project can keep a deployment target below iOS 14.
    static var isRunningOnMac: Bool {
        if #available(iOS 14.0, *) {
            return ProcessInfo.processInfo.isiOSAppOnMac
        }
        return false
    }
}
