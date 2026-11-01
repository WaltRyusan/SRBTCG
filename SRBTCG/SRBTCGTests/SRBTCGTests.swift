//
//  SRBTCGTests.swift
//  SRBTCGTests
//
//  Created by Ryuzo Hiruma on 2026/05/10.
//

import XCTest
@testable import SRBTCG

final class SRBTCGTests: XCTestCase {
    
    /// テストで表示言語を切り替えるので、元の言語を覚えておいて戻す
    private var originalLanguage: AppLanguage = .ja

    override func setUpWithError() throws {
        originalLanguage = AppStrings.shared.currentLanguage
    }
    
    override func tearDownWithError() throws {
        // saveLanguage は使わず、保存済みの設定には触れない
        AppStrings.shared.currentLanguage = originalLanguage
    }
    
    // MARK: - DateUtil Tests
    
    func testFormattedToday() {
        // 日付の書式は表示言語で変わる。日本語で確かめる
        AppStrings.shared.currentLanguage = .ja
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日"
        let expectedDate = formatter.string(from: Date())

        // 既存タイトルがない場合
        let title1 = DateUtil.formattedToday(existingTitles: [])
        XCTAssertEqual(title1, expectedDate)
        
        // 既存タイトルがある場合は (2) を付ける
        let title2 = DateUtil.formattedToday(existingTitles: [expectedDate])
        XCTAssertEqual(title2, "\(expectedDate) (2)")
        
        // 複数の既存タイトルがある場合は空いている番号を付ける
        let existingTitles2 = [expectedDate, "\(expectedDate) (2)", "\(expectedDate) (3)"]
        let title3 = DateUtil.formattedToday(existingTitles: existingTitles2)
        XCTAssertEqual(title3, "\(expectedDate) (4)")
    }
    
    // MARK: - AppStrings Tests
    
    func testAppStringsLocalization() {
        let appStrings = AppStrings.shared
        
        // 日本語テスト
        appStrings.currentLanguage = .ja
        XCTAssertEqual(appStrings.instructionList, "指示リスト")
        XCTAssertEqual(appStrings.cancel, "キャンセル")
        
        // 英語テスト
        appStrings.currentLanguage = .en
        XCTAssertEqual(appStrings.instructionList, "Instruction List")
        XCTAssertEqual(appStrings.cancel, "Cancel")
        
        // 韓国語テスト
        appStrings.currentLanguage = .ko
        XCTAssertEqual(appStrings.instructionList, "지시 목록")
        XCTAssertEqual(appStrings.cancel, "취소")
        
        // 中国語テスト
        appStrings.currentLanguage = .zhCN
        XCTAssertEqual(appStrings.instructionList, "指示列表")
        XCTAssertEqual(appStrings.cancel, "取消")
    }
    
    func testAppStringsParameterizedText() {
        let appStrings = AppStrings.shared
        appStrings.currentLanguage = .ja
        
        // パラメータ付き文字列のテスト
        XCTAssertEqual(appStrings.waveStart(1), "Wave 1 開始")
        XCTAssertEqual(appStrings.waveEnd(3), "Wave 3 終了")
        XCTAssertEqual(appStrings.secondLabel(30), "30 秒")
        XCTAssertEqual(appStrings.countdownLabel(5), "開始まで 5秒")
        XCTAssertEqual(appStrings.progressLabel(2, 45), "Wave 2 - 45秒")
        XCTAssertEqual(appStrings.intervalLabel(10), "インターバル 10秒")
    }
    
    // MARK: - AppColors Tests
    
    func testAppColors() {
        // カラーが正しく定義されているか確認
        XCTAssertNotNil(AppColors.primary)
        XCTAssertNotNil(AppColors.accent)
        XCTAssertNotNil(AppColors.background)
        XCTAssertNotNil(AppColors.surface)
        XCTAssertNotNil(AppColors.golden)
        XCTAssertNotNil(AppColors.textPrimary)
        XCTAssertNotNil(AppColors.textSecondary)
        XCTAssertNotNil(AppColors.buttonPrimary)
        XCTAssertNotNil(AppColors.buttonText)
        XCTAssertNotNil(AppColors.danger)
    }
    
    // MARK: - TTSManager Tests
    
    func testTTSManagerSingleton() {
        let instance1 = TTSManager.shared
        let instance2 = TTSManager.shared
        XCTAssertTrue(instance1 === instance2, "TTSManager should be singleton")
    }
    
    // MARK: - STTManager Tests
    
    func testSTTManagerSingleton() {
        let instance1 = STTManager.shared
        let instance2 = STTManager.shared
        XCTAssertTrue(instance1 === instance2, "STTManager should be singleton")
    }
    
    // MARK: - PurchaseManager Tests
    
    func testPurchaseManagerSingleton() {
        let instance1 = PurchaseManager.shared
        let instance2 = PurchaseManager.shared
        XCTAssertTrue(instance1 === instance2, "PurchaseManager should be singleton")
    }
    
    func testProductIdentifiers() {
        XCTAssertEqual(PurchaseManager.productSttExport, "stt_export")
        XCTAssertEqual(PurchaseManager.productAdFree, "ad_free")
        XCTAssertEqual(PurchaseManager.productPremiumBundle, "premium_bundle")
    }
    
    // MARK: - AdManager Tests
    
    func testAdManagerSingleton() {
        let instance1 = AdManager.shared
        let instance2 = AdManager.shared
        XCTAssertTrue(instance1 === instance2, "AdManager should be singleton")
    }
    
    func testAdManagerInitialization() {
        let adManager = AdManager.shared
        adManager.initialize()
        // 実際の広告表示はモックが必要なためスキップ
        XCTAssertTrue(true, "AdManager initialization should not crash")
    }
    
    // MARK: - Performance Tests
    
    func testAppStringsPerformance() {
        // AppStrings のパフォーマンステスト
        self.measure {
            let appStrings = AppStrings.shared
            for _ in 0..<100 {
                _ = appStrings.instructionList
                _ = appStrings.waveStart(1)
                _ = appStrings.progressLabel(3, 50)
            }
        }
    }
    
    func testDateUtilPerformance() {
        // DateUtil のパフォーマンステスト
        let existingTitles = (1...100).map { "2024/01/\($0)" }
        self.measure {
            _ = DateUtil.formattedToday(existingTitles: existingTitles)
        }
    }
}
