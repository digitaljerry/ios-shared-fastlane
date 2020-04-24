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

class Fastfile: LaneFile {
    
    var appleID: String?
    var devApp: Bool = true
    var defaultAppleId: String = fallbackAppleId
    var appID: String { return appIdentifier + (devApp ? ".dev" : "") }
    var scheme: String { return projectScheme + (devApp ? "DEV" : "") }
    var filePath: String { return "./\(scheme).ipa" }
    var IPAFilePath: String { return "./\(scheme).ipa" }
    var dsymFilePath: String { return "./\(scheme).app.dSYM.zip" }
    
    func beforeAll() {
        appleID = prompt(text: "Apple ID: ", ciInput: "developer@rallyreader.com")
    }
    
    func devOrProdPrompt() {
        var ciInput = environmentVariable(get: "DEV_APP")
        if ciInput == "" {
            ciInput = "y"
        }
        
        if supportsDevApp {
            devApp = prompt(text: "DEV App? (y/n)", ciInput: ciInput) == "y"
        } else {
            devApp = false
        }
        
        puts(message: "----------------------")
        puts(message: "BUILD INPUT ARGUMENTS")
        puts(message: "----------------------")
        puts(message: "AppleID: \(String(describing: appleID))")
        puts(message: "DEV App? \(devApp ? "Y" : "N")")
        puts(message: "----------------------")
    }
    
    func afterAll(currentLane: String) {}
    
    func onError(currentLane: String, errorInfo: String) {
        slackError(message: errorInfo)
    }
    
    public func distributeLatestBuildLane() {
        let whichApp = devApp ? "DEV" : "PROD"
        slackNotify(message: "Distributing latest \(whichApp) build to External testers...")
        let username = String(describing: (appleID ?? defaultAppleId))
        let groups = (devApp == true ? externalTestersGroupDEV : externalTestersGroup) ?? ""
        sh(command: "bundle exec fastlane pilot distribute --app_identifier \"\(appID)\" --username \"\(username)\" --distribute_external --groups \(groups) --notify_external_testers --beta_app_review_info '{\"contact_email\": \"\(reviewInfoContactEmail!)\",\"contact_first_name\": \"\(reviewInfoContactFirstName!)\", \"contact_last_name\": \"\(reviewInfoContactLastName!)\", \"contact_phone\": \"\(reviewInfoContactPhone!)\"}'")
        slackSuccess(message: "Successfully distributed \(whichApp) build to External testers 🚀")
    }
    
    public func devBuildLane() {
        devApp = true
        betaLane(bumpLane: true)
    }
    
    public func prodBuildLane() {
        devApp = false
        betaLane(bumpLane: false)
        tagTestflightBuildLane()
    }
    
    public func newBuildLane() {
        devOrProdPrompt()
        betaLane()
    }
    
    private func betaLane(bumpLane: Bool? = true) {
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
        
        checkTargetsLane()
        
        if automaticCodeSigning == false {
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
        }
        
        if bumpLane == true {
            buildBumpLane()
        }
        
        cocoapods()
        buildApp(
            workspace: projectWorkspace,
            scheme: scheme
        )
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
        
        let slackMessage = "\(appID) testflight uploaded successfully :ok_hand:."
        slackSuccess(message: slackMessage)
    }
    
    public func uploadDSYM() {
        let gspPath = devApp ? "./\(projectScheme)/DEV/GoogleService-Info.plist" : "./\(projectScheme)/GoogleService-Info.plist"
        uploadSymbolsToCrashlytics(
            dsymPath: dsymFilePath,
            gspPath: gspPath,
            dsymWorkerThreads: 3
        )
        let slackMessage = "\(appID) dSYM files uploaded."
        slackSuccess(message: slackMessage)
    }
    
    // MARK: Codes signing
    
    public func certificatesForReleaseLane() {
        match(
            type: "appstore",
            readonly: false,
            appIdentifier: [appID],
            teamId: teamID,
            teamName: teamID,
            gitUrl: matchGitUrl,
            gitBranch: matchGitBranch
        )
    }
    
    public func refreshProfilesLane() {
        refreshAppstoreProfiles()
    }
    
    // MARK: Private lanes
    
    private func refreshAppstoreProfiles() {
        match(
            type: "appstore",
            readonly: false,
            appIdentifier: [appID],
            teamId: teamID,
            gitUrl: matchGitUrl,
            gitBranch: matchGitBranch
        )
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
    
    private func versionBumpLane(versionNumber: String? = nil) {
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
    
    private func buildBumpLane(buildNumber: String? = nil, commitPrefix: String = "Build bump", force: Bool = false) {
        let lastCommit = lastGitCommit()
        
        if force == false {
            guard lastCommit["message"]?.hasPrefix("Build bump") == false && buildNumber == nil else {
                println(message: "No need for a build bump")
                return
            }
        }
        
        let newBuildNumber = incrementBuildNumber(buildNumber: buildNumber).trim()
        let message = "\(commitPrefix) \(newBuildNumber) by fastlane"
        
        commitVersionBump(
            message: message,
            xcodeproj: projectPath,
            force: true
        )
        
        pushToGitRemote(force: false)
        
        let versionNumber = getVersionNumber(target: scheme).trim()
        let slackMessage = "\(commitPrefix) version \(newBuildNumber) build \(versionNumber) for \(appID)"
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
        let versionNumber = getVersionNumber().trim()
        let buildNumber = getBuildNumber().trim()
        addGitTag(tag: "appstore/\(versionNumber)", buildNumber: buildNumber, commit: lastCommit["commit_hash"])
        pushGitTags()
    }
}

extension Fastfile {
    private func slackNotify(message: String, pretext: String = "") {
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
