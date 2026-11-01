//
//  InterstitialAdTests.swift
//  SRBTCGTests
//
//  全画面（インタースティシャル）広告を出すかどうかの判定を確かめる。
//
//  判定は UserDefaults.standard を直接読むので、テストの前後で
//  対象キーを退避・復元し、シミュレータ上のアプリの状態を汚さない。
//

import XCTest
@testable import SRBTCG

@MainActor
final class InterstitialAdTests: XCTestCase {

    // AppLaunchManager.Keys と同じキー
    private let launchCountKey = "app_launch_count"
    private let lastDateKey = "last_interstitial_date"

    private var savedValues: [String: Any] = [:]

    override func setUp() async throws {
        try await super.setUp()
        // テスト実行前に対象キーを退避して空にする
        let defaults = UserDefaults.standard
        savedValues = [:]
        for key in [launchCountKey, lastDateKey] {
            if let value = defaults.object(forKey: key) {
                savedValues[key] = value
            }
            defaults.removeObject(forKey: key)
        }
    }

    override func tearDown() async throws {
        // 退避しておいた値に戻す
        let defaults = UserDefaults.standard
        for key in [launchCountKey, lastDateKey] {
            if let value = savedValues[key] {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        savedValues = [:]
        try await super.tearDown()
    }

    private func setLaunchCount(_ count: Int) {
        UserDefaults.standard.set(count, forKey: launchCountKey)
    }

    private var recordedDate: Date? {
        UserDefaults.standard.object(forKey: lastDateKey) as? Date
    }

    private var yesterday: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    }

    // MARK: - 新規ユーザー保護期間

    func testTrialLaunchesIsThree() {
        XCTAssertEqual(AppLaunchManager.trialLaunches, 3)
    }

    func testShouldShowInterstitialIsFalseDuringTrial() {
        for count in 0...AppLaunchManager.trialLaunches {
            setLaunchCount(count)
            XCTAssertFalse(AppLaunchManager.shared.shouldShowInterstitial, "起動\(count)回目で判定を通ってしまう")
        }
    }

    func testShouldShowInterstitialIsTrueAfterTrial() {
        setLaunchCount(AppLaunchManager.trialLaunches + 1)
        XCTAssertTrue(AppLaunchManager.shared.shouldShowInterstitial)
    }

    func testOnAppLaunchDuringTrialDoesNotRecord() async {
        setLaunchCount(AppLaunchManager.trialLaunches)
        await AdManager.shared.onAppLaunch()
        XCTAssertNil(recordedDate)
    }

    // MARK: - 1日1回

    func testShouldShowInterstitialIsFalseWhenShownToday() {
        setLaunchCount(AppLaunchManager.trialLaunches + 1)
        AppLaunchManager.shared.recordInterstitialShown()
        XCTAssertFalse(AppLaunchManager.shared.shouldShowInterstitial)
    }

    func testShouldShowInterstitialIsTrueWhenShownYesterday() {
        setLaunchCount(AppLaunchManager.trialLaunches + 1)
        UserDefaults.standard.set(yesterday, forKey: lastDateKey)
        XCTAssertTrue(AppLaunchManager.shared.shouldShowInterstitial)
    }

    // MARK: - 表示できなかった回は記録しない
    //
    // 判定を通した状態で呼んでも、テスト環境では広告が出ないので日付は書かれないはず。
    // 起動時・復帰時とも中で2秒待つため、それぞれ2秒ほどかかる。

    func testOnAppLaunchDoesNotRecordWhenAdIsNotShown() async {
        setLaunchCount(AppLaunchManager.trialLaunches + 1)
        XCTAssertTrue(AppLaunchManager.shared.shouldShowInterstitial)

        await AdManager.shared.onAppLaunch()

        XCTAssertNil(recordedDate, "表示していないのに表示済みとして記録された")
    }

    func testOnAppResumeDoesNotRecordWhenAdIsNotShown() async {
        setLaunchCount(AppLaunchManager.trialLaunches + 1)
        let lastShown = yesterday
        UserDefaults.standard.set(lastShown, forKey: lastDateKey)
        XCTAssertTrue(AppLaunchManager.shared.shouldShowInterstitial)

        await AdManager.shared.onAppResume()

        // 今日の日付で上書きされていない
        XCTAssertEqual(recordedDate, lastShown)
    }
}
