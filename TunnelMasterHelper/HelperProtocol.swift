//
//  HelperProtocol.swift
//  TunnelMasterHelper
//
//  XPC Protocol definition (duplicated here for helper target).
//

import Foundation

@objc public protocol HelperProtocol {
    func startTunnel(configJSON: String, reply: @escaping (Bool, String?) -> Void)
    func stopTunnel(reply: @escaping (Bool, String?) -> Void)
    func getStatus(reply: @escaping (Bool, Int32) -> Void)
    func reloadConfig(configJSON: String, reply: @escaping (Bool, String?) -> Void)
    func getVersion(reply: @escaping (String) -> Void)
}
