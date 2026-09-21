//
//  Tip.swift
//  SRBTCG
//
//  サーモンランのTIPS。実体は Resources/tips.json。
//

import Foundation

/// TIPS 1件
struct Tip: Identifiable, Decodable {
    let id: String
    let category: TipCategory
    let title: String
    let body: String
    /// 根拠にしたページ。経験則だけのものは nil。
    let source: String?

    var sourceURL: URL? {
        guard let source else { return nil }
        return URL(string: source)
    }
}

/// TIPS の分類
enum TipCategory: String, Decodable, CaseIterable, Identifiable {
    case basic
    case wave
    case boss
    case weapon

    var id: String { rawValue }

    /// 一覧に出す順。基本から入って、状況ごとの話へ進む並びにする。
    static let displayOrder: [TipCategory] = [.basic, .wave, .boss, .weapon]

    var label: String {
        switch self {
        case .basic:  return "基本の立ち回り"
        case .wave:   return "特殊なWAVE"
        case .boss:   return "オオモノの倒し方"
        case .weapon: return "ブキ別の狙いどころ"
        }
    }

    var icon: String {
        switch self {
        case .basic:  return "figure.run"
        case .wave:   return "cloud.fog.fill"
        case .boss:   return "fish.fill"
        case .weapon: return "paintbrush.pointed.fill"
        }
    }
}

/// tips.json を読み込んで保持する
///
/// 内容はアプリに同梱しているので、読み込みは起動時の一度だけ。
/// 通信もファイルの書き込みも発生しない。
@Observable
final class TipsStore {

    static let shared = TipsStore()

    private(set) var tips: [Tip] = []

    private struct File: Decodable {
        let tips: [Tip]
    }

    private init() {
        tips = Self.load()
    }

    private static func load(from bundle: Bundle = .main) -> [Tip] {
        guard let url = bundle.url(forResource: "tips", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data)
        else {
            assertionFailure("tips.json を読み込めません")
            return []
        }
        return file.tips
    }

    /// あるカテゴリのTIPS
    func tips(in category: TipCategory) -> [Tip] {
        tips.filter { $0.category == category }
    }

    /// 中身が1件でもあるカテゴリだけ返す。
    /// 空のカテゴリを見出しだけ並べても意味がないため。
    var availableCategories: [TipCategory] {
        TipCategory.displayOrder.filter { !tips(in: $0).isEmpty }
    }
}
