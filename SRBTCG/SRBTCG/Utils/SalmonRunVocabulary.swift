//
//  SalmonRunVocabulary.swift
//  SRBTCG
//
//  音声認識に渡すサーモンラン用語
//

import Foundation

/// 音声認識へ渡す語彙
///
/// SFSpeechAudioBufferRecognitionRequest.contextualStrings に渡すと、
/// その語が出てくる前提で認識してくれるようになる。
/// 「カタパッド」「タマヒロイ」のような固有名詞は一般の辞書に無いため、
/// 登録しないと毎回近い音の別の語に化ける。
///
/// 正式名称だけでは足りない。実際の指示では
/// カタパッドを「ミサイル」、テッパンを「鉄板」と呼ぶなど、
/// 通称のほうが口に出やすい。両方を登録している。
///
/// Appleの目安は100語程度まで。増やしすぎると逆に精度が落ちるため、
/// Wave中に実際に口に出す語だけに絞っている。
/// ステージ名は開始前に一度言う程度なので入れていない。
enum SalmonRunVocabulary {

    static func terms(for language: AppLanguage) -> [String] {
        switch language {
        case .ja: return japanese
        case .en: return english
        // 韓国語・中国語の通称は確認が取れていないため未登録。
        // 誤った語を登録すると逆に精度を落とすので、空のままにしている。
        case .ko, .zhCN: return []
        }
    }

    private static let japanese: [String] = [
        // --- ザコシャケ ---
        "シャケ", "コジャケ", "ドスコイ", "タマヒロイ",

        // --- オオモノシャケ（正式名称）---
        // 「タワー」と「ハシラ」は別のオオモノなので両方入れる
        "バクダン", "ヘビ", "テッパン", "タワー", "モグラ",
        "コウモリ", "カタパッド", "ハシラ", "ダイバー", "ナベブタ", "テッキュウ",

        // --- 特殊オオモノ ---
        "キンシャケ", "グリル", "ハコビヤ", "ドロシャケ",

        // --- オカシラシャケ ---
        "ヨコヅナ", "タツ", "ジョー",

        // --- 通称・略称 ---
        // カタパッドは両肩のミサイルから「ミサイル」と呼ばれることが多い
        "ミサイル", "カタパ", "片パ", "鉄板", "蛇", "蝙蝠", "爆弾",
        "鍋蓋", "鉄球", "デスタワー", "タゲ",

        // --- イクラ・目標 ---
        "金イクラ", "赤イクラ", "イクラ", "コンテナ", "カゴ",
        "ノルマ", "追加ノルマ", "カンケツセン", "ウマイクラ", "ニガイクラ",

        // --- WAVE・潮位 ---
        "ウェーブ", "ウェイブ", "満潮", "干潮", "通常", "潮位", "水位", "夜",

        // --- イベント ---
        "ラッシュ", "キンシャケ探し", "グリル発進", "ハコビヤ襲来",
        "ドスコイ大量発生", "巨大タツマキ", "ヒカリバエの群れ", "霧",

        // --- スペシャル ---
        "ナイスダマ", "カニタンク", "ジェットパック", "サメライド",
        "トリプルトルネード", "メガホンレーザー", "ホップソナー", "キューインキ",

        // --- 立ち回り ---
        "高台", "中央", "手前", "奥", "湧き", "寄せ", "処理", "納品",
        "抱え", "カウント", "デス", "復活", "ヘイト", "引き付け",
        "誘導", "塗り", "ボムコロ", "ボムトス", "カゴジャンプ", "水没",

        // --- 合図・その他 ---
        "ナイス", "カモン", "ハイプレ", "クマブキ", "乱獲"
    ]

    private static let english: [String] = [
        // --- Lesser Salmonids ---
        "Chum", "Cohock", "Smallfry", "Snatcher",

        // --- Boss Salmonids ---
        "Steelhead", "Steel Eel", "Stinger", "Scrapper", "Flyfish",
        "Maws", "Drizzler", "Fish Stick", "Flipper-Flopper",
        "Big Shot", "Slammin' Lid",

        // --- Special bosses ---
        "Goldie", "Griller", "Mothership", "Mudmouth",

        // --- King Salmonids ---
        "Cohozuna", "Horrorboros", "Megalodontia",

        // --- Common nicknames ---
        "missiles", "lid", "tower", "pillar", "eel", "bomb",

        // --- Eggs and objectives ---
        "Golden Egg", "Power Egg", "eggs", "basket", "quota", "geyser",

        // --- Wave and tide ---
        "wave", "high tide", "low tide", "normal tide", "night",

        // --- Events ---
        "Rush", "Goldie Seeking", "Griller", "The Mothership",
        "Fog", "Cohock Charge", "Giant Tornado", "Mudmouth Eruptions",

        // --- Specials ---
        "Booyah Bomb", "Crab Tank", "Reefslider", "Triple Inkstrike",
        "Killer Wail", "Inkjet", "Wave Breaker", "Ink Vac",

        // --- Callouts ---
        "high ground", "center", "spawn", "deliver", "carry", "count",
        "aggro", "revive", "death", "ink"
    ]
}
