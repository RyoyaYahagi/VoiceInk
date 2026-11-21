import Foundation

@main
struct AutoLearnAppHealthTests {
    static func require(_ condition: Bool, _ message: String) {
        guard condition else { print("FAIL \(message)"); exit(1) }
    }

    static func main() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var muse = AutoLearnAppHealthRecord(appID: "com.meta.endo", appName: "Muse")
        muse.recordSuccess(version: "11.1", at: start)
        for offset in 1...2 {
            muse.recordFailure(reason: "focused-text-reading-unavailable", version: "13.1", at: start + Double(offset))
        }
        require(muse.status == .healthy, "two failures should not alert yet")
        muse.recordFailure(reason: "pasted-range-invalid", version: "13.1", at: start + 3)
        require(muse.status == .stoppedWorking(failures: 3, previousVersion: "11.1", currentVersion: "13.1"),
                "failures after an update should point to the version change")
        print("PASS repeated failures after an app update report the version change")

        require(!muse.recordFailure(reason: "accessibility-not-trusted", version: "13.1", at: start + 4),
                "permission problems are not app failures")
        require(muse.consecutiveFailures == 3, "ignored reasons must not change the streak")
        muse.recordSuccess(version: "13.1", at: start + 5)
        require(muse.status == .healthy && muse.consecutiveFailures == 0, "one success clears the alert")
        print("PASS unrelated reasons are ignored and a success clears the alert")

        var sameVersion = AutoLearnAppHealthRecord(appID: "app", appName: "App")
        sameVersion.recordSuccess(version: "2.0", at: start)
        for offset in 1...3 { sameVersion.recordFailure(reason: "pasted-range-invalid", version: "2.0", at: start + Double(offset)) }
        require(sameVersion.status == .stoppedWorking(failures: 3, previousVersion: nil, currentVersion: nil),
                "unchanged version should not claim an update")

        var never = AutoLearnAppHealthRecord(appID: "new", appName: "New")
        for offset in 1...3 { never.recordFailure(reason: "focused-text-reading-unavailable", version: nil, at: start + Double(offset)) }
        require(never.status == .neverWorked(failures: 3), "apps that never worked are reported separately")
        print("PASS same-version and never-working apps are distinguished")

        let decoded = try JSONDecoder().decode(AutoLearnAppHealthRecord.self, from: JSONEncoder().encode(muse))
        require(decoded == muse, "record must round-trip through storage")
        print("PASS health records round-trip through storage")
    }
}
