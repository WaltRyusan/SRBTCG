//
//  WaveTiming.swift
//  SRBTCG
//
//  Wave進行のタイミング定義
//

import Foundation

/// Wave進行に関わる秒数の定義
///
/// 録音と再生で同じ値を使う必要がある。
/// 録音時に記録したタイミングを再生でなぞる設計のため、
/// 片方だけ違う値だとそのままズレになる。
/// 以前は WaveListView と PlaybackView に別々の数値が書かれており、
/// インターバルが 19秒 と 19.5秒 で食い違っていた。
enum WaveTiming {

    /// Waveの数
    static let waveCount = 5

    /// 1Waveの長さ（秒）
    static let waveDuration: TimeInterval = 100

    /// Wave1が始まるまでの待機（秒）
    static let initialCountdown: TimeInterval = 11.5

    /// Wave間のインターバル（秒）
    static let interval: TimeInterval = 19.5

    /// テキストを記録・読み上げする間隔（秒）
    static let textInterval: TimeInterval = 2

    /// 1Waveあたりのテキスト枠数
    static var slotsPerWave: Int { Int(waveDuration / textInterval) }

    /// カウントダウンの読み上げを始める残り秒数
    static let countdownSpeakFrom: Int = 3

    /// 進行タイマーの発火間隔（秒）
    ///
    /// 経過時間は実時刻から計算するため、この値は表示の滑らかさを決めるだけで
    /// 進行の正確さには影響しない。
    static let tick: TimeInterval = 0.1
}

/// 実時刻を基準に経過時間を測るカウンタ
///
/// Timerの発火回数を数える方式だと、発火遅延がそのまま誤差として積み上がる。
/// TTSの読み上げでメインスレッドが詰まると発火が後ろへずれるため、
/// 100秒のWaveを5本回すうちに無視できない量になっていた。
/// 開始時刻からの差分で現在位置を求めれば、発火が遅れても累積しない。
struct ElapsedClock {
    private var startedAt: Date
    private var pausedAt: Date?
    private var pausedDuration: TimeInterval = 0

    init(startedAt: Date = Date()) {
        self.startedAt = startedAt
    }

    /// 開始からの経過秒数
    var elapsed: TimeInterval {
        let now = pausedAt ?? Date()
        return now.timeIntervalSince(startedAt) - pausedDuration
    }

    mutating func reset(to date: Date = Date()) {
        startedAt = date
        pausedAt = nil
        pausedDuration = 0
    }

    mutating func pause() {
        guard pausedAt == nil else { return }
        pausedAt = Date()
    }

    mutating func resume() {
        guard let pausedAt else { return }
        pausedDuration += Date().timeIntervalSince(pausedAt)
        self.pausedAt = nil
    }
}
