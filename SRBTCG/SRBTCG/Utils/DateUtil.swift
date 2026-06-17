//
//  DateUtil.swift
//  SRBTCG
//
//  日付処理ユーティリティ
//

import Foundation

struct DateUtil {
    /// 今日の日付をフォーマットして返す
    /// 既存のタイトルと重複しないようにサフィックスを付ける
    static func formattedToday(existingTitles: [String]) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        
        // 言語に応じて日付フォーマットを変更
        switch AppStrings.shared.currentLanguage {
        case .ja:
            formatter.dateFormat = "MM月dd日"
        case .en:
            formatter.dateFormat = "MMM d"
        case .ko:
            formatter.dateFormat = "MM월 dd일"
        case .zhCN:
            formatter.dateFormat = "MM月dd日"
        }
        
        let baseTitle = formatter.string(from: Date())
        
        // 重複チェック
        if !existingTitles.contains(baseTitle) {
            return baseTitle
        }
        
        // 重複がある場合はサフィックスを追加
        var counter = 2
        while true {
            let titleWithSuffix = "\(baseTitle) (\(counter))"
            if !existingTitles.contains(titleWithSuffix) {
                return titleWithSuffix
            }
            counter += 1
        }
    }
}