// This file contains the fastlane.tools configuration
// You can find the documentation at https://docs.fastlane.tools
//
// For a list of all available actions, check out
//
//     https://docs.fastlane.tools/actions
//

// To edit fastlane swift run:
// open ./fastlane/swift/FastlaneSwiftRunner/FastlaneSwiftRunner.xcodeproj

import Foundation

public enum Enviorment {
    case dev, stage, prod
    
    var description: String {
      switch self {
      case .dev: return "DEV"
      case .stage: return "STAGE"
      case .prod: return "PROD"
      }
    }
    
    var appIIDSuffix: String {
      switch self {
      case .dev: return ".dev"
      case .stage: return ".stage"
      case .prod: return ""
      }
    }
    
    var schemeSuffix: String {
      switch self {
      case .dev: return "DEV"
      case .stage: return "STAGE"
      case .prod: return ""
      }
    }
}

class Fastfile: LaneFile {
    
    var enviorment: Enviorment = .dev
    
    var appleID: String?
    var supportedEnviorments: [Enviorment] = [.dev, .stage, .prod]
    var defaultAppleId: String = fallbackAppleId
    var appID: String { return appIdentifier + enviorment.appIIDSuffix }
    var scheme: String { return projectScheme + enviorment.schemeSuffix }
    var filePath: String { return "./\(scheme).ipa" }
    var IPAFilePath: String { return "./\(scheme).ipa" }
    var dsymFilePath: String { return "./\(scheme).app.dSYM.zip" }
    
    let branchTruthSource = "develop"
    
    func beforeAll(with lane: String) {
        if isCi() == true {
            setupCircleCi()
            createKeychain(
                name: "ci-keychain",
                password: "",
                defaultKeychain: true,
                unlock: true,
                timeout: 3600,
                addToSearchList: true
            )
            loadAppstoreApiKey()
        } else {
            let appleIDenv = environmentVariable(get: "APPLEID")
            if appleIDenv != "" {
                appleID = appleIDenv
            } else {
                appleID = prompt(text: "Apple ID: ", ciInput: "developer@rallyreader.com")
            }
        }
    }
    
    func envPrompt() {
        var ciInput = environmentVariable(get: "ENV")
        if ciInput == "" {
            ciInput = "1"
        }
        
        if supportsDevApp == false {
            enviorment = .prod
        } else if supportedEnviorments.count > 1 {
            println(message: "Which env would you like to use? Type in the number.")
            for (index, value) in supportedEnviorments.enumerated() {
                println(message: "\(index+1)) \(value.description)")
            }
            let env = prompt(text: "?", ciInput: ciInput)
            
            switch env {
            case "1":
                enviorment = .dev
            case "2":
                enviorment = .stage
            case "3":
                enviorment = .prod
            default:
                enviorment = .dev
            }
        } else {
            enviorment = supportedEnviorments.first ?? .dev
        }
        
        puts(message: "----------------------")
        puts(message: "BUILD INPUT ARGUMENTS")
        puts(message: "----------------------")
        puts(message: "AppleID: \(String(describing: appleID))")
        puts(message: "Enviorment: \(enviorment.description)")
        puts(message: "----------------------")
    }
    
    func afterAll(currentLane: String) {
        if isCi() == true {
            deleteKeychain()
        }
    }
    
    func onError(currentLane: String, errorInfo: String) {
        slackError(message: errorInfo)
    }
    
    private func loadAppstoreApiKey() {
        let id = environmentVariable(get: "APPSTORE_API_KEY_ID")
        let issuer = environmentVariable(get: "APPSTORE_API_ISSUER_ID")
        let content = environmentVariable(get: "APPSTORE_API_KEY")
        appStoreConnectApiKey(keyId: id, issuerId: issuer, keyContent: content, inHouse: false)
    }
    
    public func distributeLatestBuildLane() {
        slackNotify(message: "Distributing latest \(enviorment.description) build to External testers...")
        let username = String(describing: (appleID ?? defaultAppleId))
        
        var groups: String
        
        switch enviorment {
        case .dev:
            groups = externalTestersGroupDEV
        case .stage:
            groups = externalTestersGroupSTAGE
        case .prod:
            groups = externalTestersGroup
        }
        
        sh(command: "bundle exec fastlane pilot distribute --app_identifier \"\(appID)\" --username \"\(username)\" --distribute_external true --groups \(groups) --notify_external_testers true --beta_app_review_info '{\"contact_email\": \"\(reviewInfoContactEmail!)\",\"contact_first_name\": \"\(reviewInfoContactFirstName!)\", \"contact_last_name\": \"\(reviewInfoContactLastName!)\", \"contact_phone\": \"\(reviewInfoContactPhone!)\"}'")
        
        slackSuccess(message: "Successfully distributed LATEST \(enviorment.description) build to External testers 🚀 Groups: \(groups)")
    }
    
    public func devBuildLane() {
        enviorment = .dev
        buildArchiveLane(bumpLane: true)
    }
    
    public func stageBuildLane() {
        enviorment = .stage
        buildArchiveLane(bumpLane: false)
    }
    
    public func prodBuildLane() {
        enviorment = .prod
        buildArchiveLane(bumpLane: false)
    }
    
    public func uploadDevBuildLane() {
        enviorment = .dev
        buildAndUpload(bumpLane: true)
    }
    
    public func uploadStageBuildLane() {
        enviorment = .stage
        buildAndUpload(bumpLane: false)
    }
    
    public func uploadProdBuildLane() {
        enviorment = .prod
        buildAndUpload(bumpLane: false)
        tagTestflightBuildLane()
    }
    
    public func newBuildLane() {
        envPrompt()
        
        if enviorment == .dev || supportsDevApp == false {
            buildAndUpload(bumpLane: true)
        } else {
            buildAndUpload(bumpLane: false)
        }
    }
    
    public func getLatestBuildNumberLane() {
        let buildNumber = latestBuildNumber()
        puts(message: "Latest build number: \(buildNumber)")
    }
    
    private func latestBuildNumber() -> String {
        let buildGitBranch = gitBranch()
        
        if buildGitBranch != branchTruthSource {
            sh(command: "git checkout \(branchTruthSource)")
        }
        
        let latestBuildNumber = getBuildNumber().trim()
        
        if buildGitBranch != branchTruthSource {
            sh(command: "git checkout \(buildGitBranch)")
        }
        
        return latestBuildNumber
    }
    
    private func buildAndUpload(bumpLane: Bool? = true) {
	desc("Push a new beta build to TestFlight")
        if FileManager.default.fileExists(atPath: filePath) {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: filePath) as [FileAttributeKey: Any],
                let creationDate = attributes[FileAttributeKey.creationDate] as? Date {
                print(creationDate)
                if creationDate.timeIntervalSinceNow <= 3600 {
                    println(message: "Recent IPA file already exists. Not building a new one.")
                    uploadIPA()
                    return
                }
            }
        }
        
        buildArchiveLane(bumpLane: bumpLane)
        
        uploadIPA()
        uploadDSYM()
        deleteArchiveFilesLane()
        cleanBuildArtifacts()
	}
    
    public func deleteArchiveFilesLane() {
        if FileManager.default.fileExists(atPath: IPAFilePath) == true {
            try! FileManager.default.removeItem(atPath: IPAFilePath)
        }
        if FileManager.default.fileExists(atPath: dsymFilePath) == true {
            try! FileManager.default.removeItem(atPath: dsymFilePath)
        }
    }
    
    public func buildArchiveLane(bumpLane: Bool? = true) {
        checkTargetsLane()
        
        if automaticCodeSigning == false {
            if isCi() == true {
                
                syncCodeSigning(
                    type: "appstore",
                    readonly: true,
                    appIdentifier: [appID],
                    username: appleID ?? defaultAppleId,
                    teamId: teamID,
                    gitUrl: matchGitUrl,
                    gitBranch: matchGitBranch,
                    shallowClone: true,
                    cloneBranchDirectly: true,
                    keychainName: "ci-keychain",
                    keychainPassword: ""
                )
                for extensionSuffix in extensionIdentifiersSuffixes {
                    syncCodeSigning(
                        type: "appstore",
                        readonly: true,
                        appIdentifier: [appID+"."+extensionSuffix],
                        username: appleID ?? defaultAppleId,
                        teamId: teamID,
                        gitUrl: matchGitUrl,
                        gitBranch: matchGitBranch,
                        shallowClone: true,
                        cloneBranchDirectly: true,
                        keychainName: "ci-keychain",
                        keychainPassword: ""
                    )
                }
                
            } else {
                
                syncCodeSigning(
                    type: "appstore",
                    readonly: true,
                    appIdentifier: [appID],
                    username: appleID ?? defaultAppleId,
                    teamId: teamID,
                    gitUrl: matchGitUrl,
                    gitBranch: matchGitBranch,
                    shallowClone: true,
                    cloneBranchDirectly: true
                )
                for extensionSuffix in extensionIdentifiersSuffixes {
                    syncCodeSigning(
                        type: "appstore",
                        readonly: true,
                        appIdentifier: [appID+"."+extensionSuffix],
                        username: appleID ?? defaultAppleId,
                        teamId: teamID,
                        gitUrl: matchGitUrl,
                        gitBranch: matchGitBranch,
                        shallowClone: true,
                        cloneBranchDirectly: true
                    )
                }
            }
        }
        
        if bumpLane == true {
            buildBumpLane()
        }
        
        cocoapods()
        buildInfoFile()
        buildApp(
            workspace: projectWorkspace,
            scheme: scheme,
            xcargs: "-allowProvisioningUpdates"
        )
    }
    
    private func buildInfoFile() {
        sh(command: "./Scripts/build_info.sh")
    }
    
    private func uploadIPA() {
        uploadToTestflight(
            username: appleID ?? defaultAppleId,
            betaAppReviewInfo: [
                "contact_email": reviewInfoContactEmail as Any,
                "contact_first_name": reviewInfoContactFirstName as Any,
                "contact_last_name": reviewInfoContactLastName as Any,
                "contact_phone": reviewInfoContactPhone as Any,
                "notes": "This is review note for the reviewer <3 thank you for reviewing"
            ],
            betaAppDescription: betaAppDescription,
            betaAppFeedbackEmail: betaAppFeedbackEmail,
            changelog: changelogSinceLastBuildBump(),
            skipSubmission: true,
            skipWaitingForBuildProcessing: true,
            teamId: itcTeam
        )
        
        let buildNumber = getBuildNumber().trim()
        let versionNumber = getVersionNumber(target: scheme).trim()
        let slackMessage = "\(appID) testflight uploaded successfully :ok_hand: v\(versionNumber) #\(buildNumber)"
        slackSuccess(message: slackMessage)
    }
    
    public func uploadDSYM() {
        let gspPath = enviorment == .prod ? "./\(projectScheme)/GoogleService-Info.plist" : "./\(projectScheme)/\(enviorment.schemeSuffix)/GoogleService-Info.plist"
        uploadSymbolsToCrashlytics(
            dsymPath: dsymFilePath,
            gspPath: gspPath,
            dsymWorkerThreads: 3
        )
        let buildNumber = getBuildNumber().trim()
        let versionNumber = getVersionNumber(target: scheme).trim()
        let slackMessage = "\(appID) dSYM files uploaded :ok_hand: v\(versionNumber) #\(buildNumber)"
        slackSuccess(message: slackMessage)
    }
    
    // MARK: Codes signing
    
    public func certificatesForReleaseLane() {
        match(
            type: "appstore",
            readonly: false,
            appIdentifier: [appID],
            username: appleID,
            teamId: teamID,
            teamName: teamID,
            gitUrl: matchGitUrl,
            gitBranch: matchGitBranch
        )
        for extensionSuffix in extensionIdentifiersSuffixes {
            match(
                type: "appstore",
                readonly: false,
                appIdentifier: [appID+"."+extensionSuffix],
                username: appleID,
                teamId: teamID,
                teamName: teamID,
                gitUrl: matchGitUrl,
                gitBranch: matchGitBranch
            )
        }
    }
    
    public func renewProfilesLane() {
        renewAppstoreProfiles()
    }
    
    // MARK: Private lanes
    
    private func renewAppstoreProfiles() {
        match(
            type: "appstore",
            readonly: false,
            appIdentifier: [appID],
            teamId: teamID,
            gitUrl: matchGitUrl,
            gitBranch: matchGitBranch,
            force: true
        )
        for extensionSuffix in extensionIdentifiersSuffixes {
            match(
                type: "appstore",
                readonly: false,
                appIdentifier: [appID+"."+extensionSuffix],
                username: appleID,
                teamId: teamID,
                teamName: teamID,
                gitUrl: matchGitUrl,
                gitBranch: matchGitBranch,
                force: true
            )
        }
    }
    
    // MARK: Helpers
    
    public func testLocalLane() {
        slackSuccess(message: "woho")
    }
    
    public func testSlackLane() {
        slackNotify(message: "Lorem ipsum NOTIFY :arenaprod:")
        slackSuccess(message: "Lorem ipsum SUCCESS :arenastage:")
        slackError(message: "Lorem ipsum ERROR :arenadev:")
    }
    
    public func versionBumpLane() {
        let versionNumber = prompt(text: "New version: ")
        appVersionBumpLane(versionNumber: versionNumber)
    }
    
    private func appVersionBumpLane(versionNumber: String? = nil) {
        let newVersionNumber = incrementVersionNumber(versionNumber: versionNumber).trim()
        let message = "Version bump \(newVersionNumber) by fastlane"
        
        commitVersionBump(
            message: message,
            xcodeproj: projectPath,
            force: true
        )
        
        pushToGitRemote(force: false)
        
        let slackMessage = "Version bump \(newVersionNumber) for \(appID)"
        slackSuccess(message: slackMessage)
    }

    public func bumpLane(withOptions options:[String: String]?) {
        if options?["force"] == "true" {
            buildBumpLane(force: true)
        } else {
            buildBumpLane(force: false)
        }
    }
    
    public func buildBumpLane() {
        buildBumpLane(force: true)
    }
    
    public func specificBuildBumpLane() {
        let build = prompt(text: "New build number: ")
        buildBumpLane(buildNumber: build, force: true)
    }
    
    private func buildBumpLane(buildNumber: String? = nil, commitPrefix: String = "Build bump", force: Bool = false) {
        let lastCommit = lastGitCommit()
        
        if force == false {
            guard lastCommit["message"]?.hasPrefix("Build bump") == false && buildNumber == nil else {
                println(message: "No need for a build bump")
                return
            }
        }
        
        let oldBuildNumber: String = buildNumber ?? "\( (Int(latestBuildNumber()) ?? 0)+1 )"
        let newBuildNumber = incrementBuildNumber(buildNumber: oldBuildNumber).trim()
        let message = "\(commitPrefix) \(newBuildNumber) by fastlane [skip ci]"
        
        commitVersionBump(
            message: message,
            xcodeproj: projectPath,
            force: true
        )
        
        pushToGitRemote(force: false)
        
        let bumpGitTag = lastGitCommit()["commit_hash"] ?? ""
        
        let currentBranch = gitBranch()
        
        // push build bump to the branch holding the truth
        if currentBranch != branchTruthSource {
            sh(command: "git checkout \(branchTruthSource)")
            sh(command: "git cherry-pick --strategy=recursive -X theirs \(bumpGitTag)")
            pushToGitRemote(force: false)
            sh(command: "git checkout \(currentBranch)")
        }
        
        let versionNumber = getVersionNumber(target: scheme).trim()
        let slackMessage = "\(commitPrefix) version \(newBuildNumber) build \(versionNumber) for \(appID) on branch \(currentBranch)"
        slackSuccess(message: slackMessage)
    }
    
    public func checkTargetsLane() {
        let checkTargetsOutput = sh(command: "./fastlane/check_targets.sh")
        if checkTargetsOutput.contains("has a different number of files!") {
            slackError(message: checkTargetsOutput)
            exit(1)
        }
    }
    
    func downloadAssetsLane() {
//        let someFile = ""
//        if FileManager.default.fileExists(atPath: libavcodecFile) {
//            println(message: "{somefile} already exists. No need to download.")
//        } else {
//            sh(command: "wget -q \"https://www.dropbox.com/s/XXX?dl=1\" -O \(libavcodecFile)")
//        }
    }
    public func changelogLane() {
        let changelog = changelogSinceLastBuildBump()
        print(changelog)
    }
    
    func changelogSinceLastBuildBump() -> String {
        let lastCommit = sh(command: "git log --pretty=format:'%H' -n 1")
        let lastBuildBumpCommit = sh(command: "git log --pretty=format:'%H' --grep='Build bump' --skip 2 -n 1 ")
        
        let changelog = changelogFromGitCommits(
            between: "\(lastCommit),\(lastBuildBumpCommit)",
            pretty: "%s",
            dateFormat: "short",
            mergeCommitFiltering: "exclude_merges"
        )
        
        return changelog
    }
    
    func changelogSinceLastTestflight() -> String {
        let changelog = changelogFromGitCommits(
            pretty: "%s <%an>",
            dateFormat: "short",
            tagMatchPattern: "testflight/*",
            mergeCommitFiltering: "exclude_merges"
        )
        
        return changelog
    }
    
    func tagTestflightBuildLane() {
        let lastCommit = lastGitCommit()
        let buildNumber = getBuildNumber().trim()
        addGitTag(tag: "testflight/\(buildNumber)", buildNumber: buildNumber, commit: lastCommit["commit_hash"])
        pushGitTags()
    }
    
    func tagStageBuildLane() {
        let lastCommit = lastGitCommit()
        let buildNumber = getBuildNumber().trim()
        addGitTag(tag: "stage/\(buildNumber)", buildNumber: buildNumber, commit: lastCommit["commit_hash"])
        pushGitTags()
    }
    
    func tagAppstoreVersionLane() {
        let lastCommit = lastGitCommit()
        let versionNumber = getVersionNumber(target: scheme).trim()
        let buildNumber = getBuildNumber().trim()
        addGitTag(tag: "appstore/\(versionNumber)", buildNumber: buildNumber, commit: lastCommit["commit_hash"])
        pushGitTags()
    }
}

extension Fastfile {
    private func slackNotify(message: String, pretext: String = "") {
        puts(message: "posting to \(slackChannel) with \(slackUrl)")
        slack(message: message,
              channel: slackChannel,
              slackUrl: slackUrl,
              defaultPayloads: [],
              attachmentProperties: [
                "color": "warn",
                "pretext": pretext,
                "text": message
            ]
        )
    }
    private func slackSuccess(message: String) {
        slack(message: message, channel: slackChannel, slackUrl: slackUrl, defaultPayloads: [], success: true)
    }
    private func slackError(message: String) {
        slack(message: message, channel: slackChannel, slackUrl: slackUrl, defaultPayloads: [], success: false)
    }
}

extension String {
    func trim() -> String {
        var string = self.replacingOccurrences(of: "\\n", with: "", options: .regularExpression)
        string = string.replacingOccurrences(of: "\"", with: "", options: .regularExpression)
        return string
    }
    var removingWhitespacesAndNewlines: String {
        return replacingOccurrences(of: "\"", with: "", options: .regularExpression)
    }
}
