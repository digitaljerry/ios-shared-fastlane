// LaneFileProtocol.swift
// Copyright (c) 2020 FastlaneTools

//
//  ** NOTE **
//  This file is provided by fastlane and WILL be overwritten in future updates
//  If you want to add extra functionality to this project, create a new file in a
//  new group so that it won't be marked for upgrade
//

import Foundation

public protocol LaneFileProtocol: class {
    var fastlaneVersion: String { get }
<<<<<<< Updated upstream
    static func runLane(named: String, parameters: [String : String]) -> Bool
=======
    static func runLane(from fastfile: LaneFile?, named: String, parameters: [String: String]) -> Bool
>>>>>>> Stashed changes

    func recordLaneDescriptions()
    func beforeAll(currentLane: String, parameters: [String : String])
    func beforeAll()
    func afterAll(currentLane: String)
    func onError(currentLane: String, errorInfo: String)
}

public extension LaneFileProtocol {
<<<<<<< Updated upstream
    var fastlaneVersion: String { return "" } // default "" because that means any is fine
    func beforeAll(currentLane: String, parameters: [String : String]) { } // no op by default
    func beforeAll() { } // no op by default
    func afterAll(currentLane: String) { } // no op by default
    func onError(currentLane: String, errorInfo: String) {} // no op by default
    func recordLaneDescriptions() { } // no op by default
=======
    var fastlaneVersion: String { return "" } // Defaults to "" because that means any is fine
    func beforeAll() {} // No-op by default
    func afterAll(currentLane _: String) {} // No-op by default
    func onError(currentLane _: String, errorInfo _: String) {} // No-op by default
    func recordLaneDescriptions() {} // No-op by default
>>>>>>> Stashed changes
}

@objcMembers
open class LaneFile: NSObject, LaneFileProtocol {
    private(set) static var fastfileInstance: LaneFile?

    // Called before any lane is executed.
<<<<<<< Updated upstream
    private func setupAllTheThings(lane: String, parameters: [String : String]) {
        LaneFile.fastfileInstance!.beforeAll(currentLane: lane, parameters: parameters)
=======
    private func setUpAllTheThings() {
>>>>>>> Stashed changes
        LaneFile.fastfileInstance!.beforeAll()
    }

    private static func trimLaneFromName(laneName: String) -> String {
        return String(laneName.prefix(laneName.count - 4))
    }

    private static func trimLaneWithOptionsFromName(laneName: String) -> String {
        return String(laneName.prefix(laneName.count - 12))
    }

    private static var laneFunctionNames: [String] {
        var lanes: [String] = []
        var methodCount: UInt32 = 0
<<<<<<< Updated upstream
        let methodList = class_copyMethodList(self, &methodCount)
        for i in 0..<Int(methodCount) {
=======
        #if !SWIFT_PACKAGE
            let methodList = class_copyMethodList(self, &methodCount)
        #else
            // In SPM we're calling this functions out of the scope of the normal binary that it's
            // being built, so *self* in this scope would be the SPM executable instead of the Fastfile
            // that we'd normally expect.
            let methodList = class_copyMethodList(type(of: fastfileInstance!), &methodCount)
        #endif
        for i in 0 ..< Int(methodCount) {
>>>>>>> Stashed changes
            let selName = sel_getName(method_getName(methodList![i]))
            let name = String(cString: selName)
            let lowercasedName = name.lowercased()
            if lowercasedName.hasSuffix("lane") || lowercasedName.hasSuffix("lanewithoptions:") {
                lanes.append(name)
            }
        }
        return lanes
    }

    public static var lanes: [String : String] {
        var laneToMethodName: [String : String] = [:]
        self.laneFunctionNames.forEach { name in
            let lowercasedName = name.lowercased()
            if lowercasedName.hasSuffix("lane") {
                laneToMethodName[lowercasedName] = name
                let lowercasedNameNoLane = trimLaneFromName(laneName: lowercasedName)
                laneToMethodName[lowercasedNameNoLane] = name
            } else if lowercasedName.hasSuffix("lanewithoptions:") {
                let lowercasedNameNoOptions = trimLaneWithOptionsFromName(laneName: lowercasedName)
                laneToMethodName[lowercasedNameNoOptions] = name
                let lowercasedNameNoLane = trimLaneFromName(laneName: lowercasedNameNoOptions)
                laneToMethodName[lowercasedNameNoLane] = name
            }
        }

        return laneToMethodName
    }

    public static func loadFastfile() {
        if self.fastfileInstance == nil {
            let fastfileType: AnyObject.Type = NSClassFromString(self.className())!
            let fastfileAsNSObjectType: NSObject.Type = fastfileType as! NSObject.Type
            let currentFastfileInstance: Fastfile? = fastfileAsNSObjectType.init() as? Fastfile
            self.fastfileInstance = currentFastfileInstance
        }
    }

<<<<<<< Updated upstream
    public static func runLane(named: String, parameters: [String : String]) -> Bool {
        log(message: "Running lane: \(named)")
        self.loadFastfile()

        guard let fastfileInstance: Fastfile = self.fastfileInstance else {
            let message = "Unable to instantiate class named: \(self.className())"
            log(message: message)
            fatalError(message)
        }

        let currentLanes = self.lanes
=======
    public static func runLane(from fastfile: LaneFile?, named: String, parameters: [String: String]) -> Bool {
        log(message: "Running lane: \(named)")
        #if !SWIFT_PACKAGE
            // When not in SPM environment, we load the Fastfile from its `className()`.
            loadFastfile()
            guard let fastfileInstance: LaneFile = self.fastfileInstance else {
                let message = "Unable to instantiate class named: \(className())"
                log(message: message)
                fatalError(message)
            }
        #else
            // When in SPM environment, we can't load the Fastfile from its `className()` because the executable is in
            // another scope, so `className()` won't be the expected Fastfile. Instead, we load the Fastfile as a Lanefile
            // in a static way, by parameter.
            guard let fastfileInstance: LaneFile = fastfile else {
                log(message: "Found nil instance of fastfile")
                preconditionFailure()
            }
            self.fastfileInstance = fastfileInstance
        #endif
        let currentLanes = lanes
>>>>>>> Stashed changes
        let lowerCasedLaneRequested = named.lowercased()

        guard let laneMethod = currentLanes[lowerCasedLaneRequested] else {
            let laneNames = self.laneFunctionNames.map { laneFuctionName in
                if laneFuctionName.hasSuffix("lanewithoptions:") {
                    return trimLaneWithOptionsFromName(laneName: laneFuctionName)
                } else {
                    return trimLaneFromName(laneName: laneFuctionName)
                }
            }.joined(separator: ", ")

            let message = "[!] Could not find lane '\(named)'. Available lanes: \(laneNames)"
            log(message: message)

            let shutdownCommand = ControlCommand(commandType: .cancel(cancelReason: .clientError), message: message)
            _ = runner.executeCommand(shutdownCommand)
            return false
        }

<<<<<<< Updated upstream
        // call all methods that need to be called before we start calling lanes
        fastfileInstance.setupAllTheThings(lane: named, parameters: parameters)
=======
        // Call all methods that need to be called before we start calling lanes.
        fastfileInstance.setUpAllTheThings()
>>>>>>> Stashed changes

        // We need to catch all possible errors here and display a nice message.
        _ = fastfileInstance.perform(NSSelectorFromString(laneMethod), with: parameters)

        // Call only on success.
        fastfileInstance.afterAll(currentLane: named)
        log(message: "Done running lane: \(named) 🚀")
        return true
    }
}

// Please don't remove the lines below
// They are used to detect outdated files
// FastlaneRunnerAPIVersion [0.9.2]
