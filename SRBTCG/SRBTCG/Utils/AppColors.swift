//
//  AppColors.swift
//  SRBTCG
//
//  サーモンラン風カラーテーマ
//

import SwiftUI

/// サーモンラン風カラーテーマ
/// Inkipedia / Leanny's datamine ベースの近似色
struct AppColors {
    // メインカラー
    static let primary = Color(red: 1.0, green: 0.588, blue: 0) // #FF9600 サーモンランオレンジ
    static let accent = Color(red: 0.231, green: 0.765, blue: 0.208) // #3BC335 クマサン商会グリーン
    static let background = Color(red: 0.102, green: 0.102, blue: 0.180) // #1A1A2E イカスミブラック
    static let surface = Color(red: 0.176, green: 0.278, blue: 0.224) // #2D4739 インクグリーン（濃）
    static let golden = Color(red: 1.0, green: 0.722, blue: 0) // #FFB800 金イクラゴールド
    
    // テキスト
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 0.690, green: 0.690, blue: 0.690) // #B0B0B0
    
    // ボタン
    static let buttonPrimary = Color(red: 1.0, green: 0.588, blue: 0) // #FF9600
    static let buttonText = Color.white
    
    // Wave ヘッダー
    static let waveHeader = Color(red: 0.973, green: 0.298, blue: 0) // #F84C00 レッドオレンジ
    
    // 危険度・警告
    static let danger = Color.red
    
    // 互換性エイリアス
    static let secondary = Color.white
}