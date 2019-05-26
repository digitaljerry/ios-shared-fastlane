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
    var devApp: Bool = false
    var appID: String { return appIdentifier + (devApp ? ".dev" : "") }
    var scheme: String { return projectScheme + (devApp ? "DEV" : "") }
    var filePath: String { return "./\(scheme).ipa" }
    
    func beforeAll() {
        appleID = prompt(text: "Apple ID: ")
        if supportsDevApp {
            devApp = prompt(text: "DEV App? (y/n)") == "y"
        }
    }
    
    func afterAll(currentLane: String) {}
    
    func onError(currentLane: String, errorInfo: String) {
        slackError(message: errorInfo)
    }
    
	func betaLane() {
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
        buildBumpLane()
        cocoapods()
        buildApp(
            workspace: projectWorkspace,
            scheme: scheme
        )
        uploadIPA()
	}
    
    private func uploadIPA() {
        uploadToTestflight(
            username: appleID ?? defaultAppleId,
            skipSubmission: true,
            skipWaitingForBuildProcessing: true,
            teamId: itcTeam
        )
        
        let slackMessage = "\(appID) testflight uploaded successfully :ok_hand:."
        slackNotify(message: slackMessage)
        
        cleanBuildArtifacts()
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
        slackNotify(message: slackMessage)
    }

    public func bumpLane() {
        buildBumpLane()
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
        slackNotify(message: slackMessage)
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
    
    func changelogSinceLastBuildBump() -> String {
        let lastCommit = sh(command: "git log --pretty=format:'%H' -n 1")
        let lastBuildBumpCommit = sh(command: "git log --pretty=format:'%H' --grep='Build bump' --skip 1 -n 1 ")
        
        let changelog = changelogFromGitCommits(
            between: "\(lastCommit),\(lastBuildBumpCommit)",
            pretty: "%s <%an>",
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
