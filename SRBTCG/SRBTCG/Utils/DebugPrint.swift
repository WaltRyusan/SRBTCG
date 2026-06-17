//
//  DebugPrint.swift
//  SRBTCG
//
//  デバッグ用プリント関数
//

import Foundation

/// デバッグモードでのみ動作するprint関数
/// リリースビルドでは何も出力しない
func kDebugModePrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    let output = items.map { "\($0)" }.joined(separator: separator)
    Swift.print("🐛 [DEBUG] \(output)", terminator: terminator)
    #endif
}

/// デバッグモードでのみ動作する詳細print関数（ファイル名、関数名、行番号付き）
func kDebugModePrintDetailed(
    _ items: Any...,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    #if DEBUG
    let fileName = (file as NSString).lastPathComponent
    let output = items.map { "\($0)" }.joined(separator: " ")
    Swift.print("🐛 [\(fileName):\(line)] \(function) - \(output)")
    #endif
}

/// エラー専用デバッグプリント
func kDebugErrorPrint(
    _ error: Error,
    message: String? = nil,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    #if DEBUG
    let fileName = (file as NSString).lastPathComponent
    if let message = message {
        Swift.print("❌ ERROR [\(fileName):\(line)] \(function) - \(message): \(error)")
    } else {
        Swift.print("❌ ERROR [\(fileName):\(line)] \(function) - \(error)")
    }
    #endif
}

/// 警告専用デバッグプリント
func kDebugWarningPrint(
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    #if DEBUG
    let fileName = (file as NSString).lastPathComponent
    Swift.print("⚠️ WARNING [\(fileName):\(line)] \(function) - \(message)")
    #endif
}

/// 成功メッセージ専用デバッグプリント
func kDebugSuccessPrint(
    _ message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    #if DEBUG
    let fileName = (file as NSString).lastPathComponent
    Swift.print("✅ SUCCESS [\(fileName):\(line)] \(function) - \(message)")
    #endif
}

/// パフォーマンス測定用デバッグプリント
class DebugTimer {
    private let label: String
    private let startTime: CFAbsoluteTime
    
    init(label: String) {
        self.label = label
        self.startTime = CFAbsoluteTimeGetCurrent()
        #if DEBUG
        Swift.print("⏱ [TIMER START] \(label)")
        #endif
    }
    
    func stop() {
        #if DEBUG
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        Swift.print("⏱ [TIMER END] \(label): \(String(format: "%.3f", timeElapsed))秒")
        #endif
    }
    
    deinit {
        stop()
    }
}