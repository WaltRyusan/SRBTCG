//
//  HazardLevel.swift
//  SRBTCG
//
//  キケン度と、それによって変わる湧き方向の切り替わりタイミング。
//

import Foundation

/// キケン度の区分
///
/// 湧き方向（オオモノシャケが来る方角）が変わる間隔は **72 ÷ n 秒**で、
/// n はキケン度によって決まる。以前は全キケン度で15秒固定としていたが、
/// どの区分でも15秒にはならないため作り直した。
///
/// 出典: スプラトゥーン3 攻略＆検証Wiki「ラッシュ」
/// https://wikiwiki.jp/splatoon3mix/サーモンラン/特殊な状況/ラッシュ
/// （ヒカリバエのターゲット切り替わりと湧き方角の変化は同期しているため、
///   同じ周期が使える）
enum HazardLevel: Int, CaseIterable, Identifiable {
    /// 100〜149.8%
    case low
    /// 150〜199.8%
    case midLow
    /// 200〜266.4%
    case mid
    /// 266.6〜329.8%
    case high
    /// 333%
    case max

    var id: Int { rawValue }

    /// セグメントに出す表記
    ///
    /// 5区分あるため幅が狭い。範囲を書くと省略されてしまうので上限だけ示す。
    /// 「キケン度」の見出しが上にあるので % は省いている。
    var label: String {
        switch self {
        case .low:    return "~149"
        case .midLow: return "~199"
        case .mid:    return "~266"
        case .high:   return "~332"
        case .max:    return "MAX"
        }
    }

    /// 範囲を省略せずに書いたもの。説明文で使う。
    var rangeText: String {
        switch self {
        case .low:    return "100〜149%"
        case .midLow: return "150〜199%"
        case .mid:    return "200〜266%"
        case .high:   return "267〜332%"
        case .max:    return "MAX (333%)"
        }
    }

    /// 72 を割る数。大きいほど湧き方向が頻繁に変わる。
    private var divisor: Int {
        switch self {
        case .low:    return 5
        case .midLow: return 6
        case .mid:    return 7
        case .high:   return 8
        case .max:    return 9
        }
    }

    /// 湧き方向が変わる間隔（秒）
    var spawnDirectionInterval: Double {
        72.0 / Double(divisor)
    }

    /// 画面に出す間隔の表記（例: "14.4秒"）
    var spawnDirectionIntervalText: String {
        String(format: "%.1f秒", spawnDirectionInterval)
    }

    /// 湧き方向が変わる残り秒数
    ///
    /// Wave開始（残り100秒）から間隔ぶんずつ引いていく。
    /// 実際の間隔は小数になるが、アナウンスは秒単位で鳴らすため四捨五入する。
    /// 例（72÷5=14.4秒）: 100 → 85.6 → 71.2 → 56.8 → 42.4 → 28 → 13.6
    var spawnDirectionSeconds: [Int] {
        var result: [Int] = []
        var remaining = Double(WaveTiming.waveDuration) - spawnDirectionInterval

        while remaining > 0 {
            result.append(Int(remaining.rounded()))
            remaining -= spawnDirectionInterval
        }
        return result
    }

    /// 最終湧きの残り秒数
    ///
    /// キケン度が高いほど早く始まる。
    /// ⚠️ この値は以前の実装から引き継いだもので、裏付けを取れていない。
    ///    湧き方向のような検証データが見つかったら直すこと。
    var finalSpawnSecond: Int {
        switch self {
        case .low, .midLow: return 10
        case .mid:          return 15
        case .high:         return 20
        case .max:          return 25
        }
    }

    /// 「納品数を意識」を出す残り秒数
    static let deliveryReminderSecond = 30

    /// アナウンスの一覧（残り秒数の降順）
    ///
    /// 同じ秒に複数が重なった場合は、湧き方向より優先度の高いものを残す。
    var timings: [(second: Int, key: String)] {
        var table: [Int: String] = [:]

        for (index, second) in spawnDirectionSeconds.enumerated() {
            table[second] = "spawnDirectionChange\(index + 1)"
        }
        // 重なったら上書きする。湧き方向は次の周期でまた鳴るが、
        // 最終湧きと納品の合図は一度きりなので、そちらを優先する。
        table[Self.deliveryReminderSecond] = "thirtySecondsLeft"
        table[finalSpawnSecond] = "finalSpawn"
        table[0] = "waveClear"

        return table
            .map { (second: $0.key, key: $0.value) }
            .sorted { $0.second > $1.second }
    }
}
