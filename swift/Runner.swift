// Runner.swift
// Copyright (c) 2020 FastlaneTools

//
//  ** NOTE **
//  This file is provided by fastlane and WILL be overwritten in future updates
//  If you want to add extra functionality to this project, create a new file in a
//  new group so that it won't be marked for upgrade
//

import Foundation

let logger: Logger = {
    return Logger()
}()

let runner: Runner = {
    return Runner()
}()

func desc(_ laneDescription: String) {
    // no-op, this is handled in fastlane/lane_list.rb
}

class Runner {
<<<<<<< Updated upstream
    fileprivate var thread: Thread!
    fileprivate var socketClient: SocketClient!
    fileprivate let dispatchGroup: DispatchGroup = DispatchGroup()
    fileprivate var returnValue: String? // lol, so safe
    fileprivate var currentlyExecutingCommand: RubyCommandable? = nil
    fileprivate var shouldLeaveDispatchGroupDuringDisconnect = false
    
=======
    private var thread: Thread!
    private var socketClient: SocketClient!
    private let dispatchGroup = DispatchGroup()
    private var returnValue: String? // lol, so safe
    private var currentlyExecutingCommand: RubyCommandable?
    private var shouldLeaveDispatchGroupDuringDisconnect = false
    private var executeNext: [String: Bool] = [:]

>>>>>>> Stashed changes
    func executeCommand(_ command: RubyCommandable) -> String {
        self.dispatchGroup.enter()
        currentlyExecutingCommand = command
        socketClient.send(rubyCommand: command)
        
        let secondsToWait = DispatchTimeInterval.seconds(SocketClient.defaultCommandTimeoutSeconds)
<<<<<<< Updated upstream
        let connectTimeout = DispatchTime.now() + secondsToWait
        let timeoutResult = self.dispatchGroup.wait(timeout: connectTimeout)
=======
        // swiftlint:disable next
        let timeoutResult = Self.waitWithPolling(self.executeNext[command.id], toEventually: { $0 == true }, timeout: SocketClient.defaultCommandTimeoutSeconds)
        executeNext.removeValue(forKey: command.id)
>>>>>>> Stashed changes
        let failureMessage = "command didn't execute in: \(SocketClient.defaultCommandTimeoutSeconds) seconds"
        let success = testDispatchTimeoutResult(timeoutResult, failureMessage: failureMessage, timeToWait: secondsToWait)
        guard success else {
            log(message: "command timeout")
            fatalError()
        }
        
        if let returnValue = self.returnValue {
            return returnValue
        } else {
            return ""
        }
    }
<<<<<<< Updated upstream
=======

    static func waitWithPolling<T>(_ expression: @autoclosure @escaping () throws -> T, toEventually predicate: @escaping (T) -> Bool, timeout: Int, pollingInterval: DispatchTimeInterval = .milliseconds(4)) -> DispatchTimeoutResult {
        func memoizedClosure<T>(_ closure: @escaping () throws -> T) -> (Bool) throws -> T {
            var cache: T?
            return { withoutCaching in
                if withoutCaching || cache == nil {
                    cache = try closure()
                }
                guard let cache = cache else {
                    preconditionFailure()
                }

                return cache
            }
        }

        let runLoop = RunLoop.current
        let timeoutDate = Date(timeInterval: TimeInterval(timeout), since: Date())
        var fulfilled: Bool = false
        let _expression = memoizedClosure(expression)
        repeat {
            do {
                let exp = try _expression(true)
                fulfilled = predicate(exp)
            } catch {
                fatalError("Error raised \(error.localizedDescription)")
            }
            if !fulfilled {
                runLoop.run(until: Date(timeIntervalSinceNow: pollingInterval.timeInterval))
            } else {
                break
            }
        } while Date().compare(timeoutDate) == .orderedAscending

        if fulfilled {
            return .success
        } else {
            return .timedOut
        }
    }
>>>>>>> Stashed changes
}

// Handle threading stuff
extension Runner {
    func startSocketThread(port: UInt32) {
        let secondsToWait = DispatchTimeInterval.seconds(SocketClient.connectTimeoutSeconds)
        
        self.dispatchGroup.enter()
        
        self.socketClient = SocketClient(port: port, commandTimeoutSeconds:timeout, socketDelegate: self)
        self.thread = Thread(target: self, selector: #selector(startSocketComs), object: nil)
        self.thread!.name = "socket thread"
        self.thread!.start()
        
        let connectTimeout = DispatchTime.now() + secondsToWait
        let timeoutResult = self.dispatchGroup.wait(timeout: connectTimeout)
        
        let failureMessage = "couldn't start socket thread in: \(SocketClient.connectTimeoutSeconds) seconds"
        let success = testDispatchTimeoutResult(timeoutResult, failureMessage: failureMessage, timeToWait: secondsToWait)
        guard success else {
            log(message: "socket thread timeout")
            fatalError()
        }
    }
    
    func disconnectFromFastlaneProcess() {
        self.shouldLeaveDispatchGroupDuringDisconnect = true
        self.dispatchGroup.enter()
        socketClient.sendComplete()
        
        let connectTimeout = DispatchTime.now() + 2
        _ = self.dispatchGroup.wait(timeout: connectTimeout)
    }
    
    @objc func startSocketComs() {
        guard let socketClient = self.socketClient else {
            return
        }
        
        socketClient.connectAndOpenStreams()
        self.dispatchGroup.leave()
    }
    
    fileprivate func testDispatchTimeoutResult(_ timeoutResult: DispatchTimeoutResult, failureMessage: String, timeToWait: DispatchTimeInterval) -> Bool {
        switch timeoutResult {
        case .success:
            return true
        case .timedOut:
            log(message: "timeout: \(failureMessage)")
            return false
        }
    }
}

extension Runner : SocketClientDelegateProtocol {
    func commandExecuted(serverResponse: SocketClientResponse) {
        switch serverResponse {
        case .success(let returnedObject, let closureArgumentValue):
            verbose(message: "command executed")
            self.returnValue = returnedObject
            if let command = self.currentlyExecutingCommand as? RubyCommand {
                if let closureArgumentValue = closureArgumentValue {
                    command.performCallback(callbackArg: closureArgumentValue)
                }
            }
            self.dispatchGroup.leave()
        case .clientInitiatedCancelAcknowledged:
            verbose(message: "server acknowledged a cancel request")
            self.dispatchGroup.leave()
            
        case .alreadyClosedSockets, .connectionFailure, .malformedRequest, .malformedResponse, .serverError:
            log(message: "error encountered while executing command:\n\(serverResponse)")
            self.dispatchGroup.leave()
            
        case .commandTimeout(let timeout):
            log(message: "Runner timed out after \(timeout) second(s)")
        }
    }
    
    func connectionsOpened() {
        DispatchQueue.main.async {
            verbose(message: "connected!")
        }
    }
    
    func connectionsClosed() {
        DispatchQueue.main.async {
            self.thread?.cancel()
            self.thread = nil
            self.socketClient = nil
            verbose(message: "connection closed!")
            if self.shouldLeaveDispatchGroupDuringDisconnect {
                self.dispatchGroup.leave()
            }
            exit(0)
        }
    }
}

class Logger {
    enum LogMode {
        init(logMode: String) {
            switch logMode {
            case "normal", "default":
                self = .normal
            case "verbose":
                self = .verbose
            default:
                logger.log(message: "unrecognized log mode: \(logMode), defaulting to 'normal'")
                self = .normal
            }
        }
        case normal
        case verbose
    }
    
    public static var logMode: LogMode = .normal
    
    func log(message: String) {
        let timestamp = NSDate().timeIntervalSince1970
        print("[\(timestamp)]: \(message)")
    }
    
    func verbose(message: String) {
        if Logger.logMode == .verbose {
            let timestamp = NSDate().timeIntervalSince1970
            print("[\(timestamp)]: \(message)")
        }
    }
}

func log(message: String) {
    logger.log(message: message)
}

func verbose(message: String) {
    logger.verbose(message: message)
}

// Please don't remove the lines below
// They are used to detect outdated files
// FastlaneRunnerAPIVersion [0.9.2]

