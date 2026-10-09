//
//  SupportLinks.swift
//  SRBTCG
//
//  サポート・ポリシー類のURL。
//
//  ページの実体は4アプリ分をまとめた app-support リポジトリにある。
//  https://github.com/WaltRyusan/app-support
//  内容を直すときはそちらを編集してpushする（GitHub Pagesで公開している）。
//

import Foundation

enum SupportLinks {
    /// 使い方・FAQ・問い合わせ導線を載せたページ。
    /// App Store Connect の「サポートURL」にはこれを登録する。
    static let support = "https://waltryusan.github.io/app-support/srbtcg/"

    /// App Store Connect の「プライバシーポリシーURL」に登録するもの
    static let privacyPolicy = "https://waltryusan.github.io/app-support/srbtcg/privacy.html"

    /// 自前の規約は作らず、Appleの標準ライセンス契約を適用する
    static let terms = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"

    /// App Store のページ
    ///
    /// ⚠️ `id0000000000` は仮の値。App Store Connect にアプリを登録すると
    ///    Apple ID（数字）が発行されるので、提出前に差し替える。
    ///    登録するまでこの数字は分からない。
    static let appStore = "https://apps.apple.com/jp/app/id0000000000"

    /// 人に薦めるときに送る文面
    ///
    /// URLは末尾に置く。本文の途中に入れると、SNSによっては
    /// リンクのプレビューが出ず、ただの文字列として扱われることがある。
    static var shareMessage: String {
        """
        サーモンランのバイトチームコンテストで使えるアプリ「サモランガイド」

        Waveごとの指示を声で記録して、あとから読み上げられます。

        \(appStore)
        """
    }

    /// お問い合わせフォーム（4アプリ共通・アプリ名がpre-filledされる）
    static let feedbackForm = "https://docs.google.com/forms/d/e/1FAIpQLScMXjAFuFwgxWXSm52-OZ4xQoUhjwCh-gC8QY8C7aBWEULcjA/viewform?usp=pp_url&entry.135936132=%E3%82%B5%E3%83%A2%E3%83%A9%E3%83%B3%E3%83%90%E3%83%81%E3%82%B3%E3%83%B3%E3%82%AC%E3%82%A4%E3%83%89%EF%BC%88Splatoon3+%E3%82%B5%E3%83%BC%E3%83%A2%E3%83%B3%E3%83%A9%E3%83%B3%E9%9F%B3%E5%A3%B0%E3%82%AC%E3%82%A4%E3%83%89%EF%BC%89"
}
