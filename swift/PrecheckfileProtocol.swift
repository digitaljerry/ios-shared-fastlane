<<<<<<< Updated upstream
protocol PrecheckfileProtocol: class {
=======
// PrecheckfileProtocol.swift
// Copyright (c) 2020 FastlaneTools

public protocol PrecheckfileProtocol: class {
    /// Path to your App Store Connect API Key JSON file (https://docs.fastlane.tools/app-store-connect-api/#using-fastlane-api-key-json-file)
    var apiKeyPath: String? { get }

    /// Your App Store Connect API Key information (https://docs.fastlane.tools/app-store-connect-api/#use-return-value-and-pass-in-as-an-option)
    var apiKey: [String: Any]? { get }

    /// The bundle identifier of your app
    var appIdentifier: String { get }
>>>>>>> Stashed changes

  /// The bundle identifier of your app
  var appIdentifier: String { get }

  /// Your Apple ID Username
  var username: String { get }

  /// The ID of your App Store Connect team if you're in multiple teams
  var teamId: String? { get }

<<<<<<< Updated upstream
  /// The name of your App Store Connect team if you're in multiple teams
  var teamName: String? { get }
=======
    /// The platform to use (optional)
    var platform: String { get }

    /// The default rule level unless otherwise configured
    var defaultRuleLevel: String { get }
>>>>>>> Stashed changes

  /// The default rule level unless otherwise configured
  var defaultRuleLevel: String { get }

  /// Should check in-app purchases?
  var includeInAppPurchases: Bool { get }

  /// using text indicating that your IAP is free
  var freeStuffInIap: String? { get }
}

<<<<<<< Updated upstream
extension PrecheckfileProtocol {
  var appIdentifier: String { return "" }
  var username: String { return "" }
  var teamId: String? { return nil }
  var teamName: String? { return nil }
  var defaultRuleLevel: String { return "error" }
  var includeInAppPurchases: Bool { return true }
  var freeStuffInIap: String? { return nil }
=======
public extension PrecheckfileProtocol {
    var apiKeyPath: String? { return nil }
    var apiKey: [String: Any]? { return nil }
    var appIdentifier: String { return "" }
    var username: String { return "" }
    var teamId: String? { return nil }
    var teamName: String? { return nil }
    var platform: String { return "ios" }
    var defaultRuleLevel: String { return "error" }
    var includeInAppPurchases: Bool { return true }
    var freeStuffInIap: String? { return nil }
>>>>>>> Stashed changes
}

// Please don't remove the lines below
// They are used to detect outdated files
<<<<<<< Updated upstream
// FastlaneRunnerAPIVersion [0.9.11]
=======
// FastlaneRunnerAPIVersion [0.9.40]
>>>>>>> Stashed changes
