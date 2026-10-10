//
//  AppLaunchManager.swift
//  SRBTCG
//
//  起動回数をもとに、広告の解禁とレビュー催促のタイミングを決める。
//
//  共通スキル `review-and-feedback` の実装。キー名は全アプリで揃えている。
//
//  以前はバチコン再生の完了回数で判定していたが、
//  連続で再生したいときに毎回割り込まれて使いづらかった。
//  起動回数なら、アプリを開いた直後の1回で済む。
//

import SwiftUI
import Combine
import StoreKit

@MainActor
final class AppLaunchManager: ObservableObject {
    static let shared = AppLaunchManager()

    private enum Keys {
        static let launchCount = "app_launch_count"
        /// 満足度シートを出したか
        static let reviewRequested = "review_requested"
        /// 1日1回制限用
        static let lastInterstitialDate = "last_interstitial_date"
        /// 広告開始の告知を出したか
        static let adWarningShown = "ad_warning_shown"
    }

    /// 新規ユーザーを保護する起動回数。ここまでは広告を出さない
    static let trialLaunches = 3

    /// 満足度を聞くシートを出すか
    @Published var showReviewPrompt = false
    /// 広告が始まることを知らせるシートを出すか
    @Published var showAdWarning = false

    private let defaults = UserDefaults.standard

    private(set) var launchCount: Int {
        get { defaults.integer(forKey: Keys.launchCount) }
        set { defaults.set(newValue, forKey: Keys.launchCount) }
    }

    private var reviewRequested: Bool {
        get { defaults.bool(forKey: Keys.reviewRequested) }
        set { defaults.set(newValue, forKey: Keys.reviewRequested) }
    }

    private var adWarningShown: Bool {
        get { defaults.bool(forKey: Keys.adWarningShown) }
        set { defaults.set(newValue, forKey: Keys.adWarningShown) }
    }

    private var lastInterstitialDate: Date? {
        get { defaults.object(forKey: Keys.lastInterstitialDate) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastInterstitialDate) }
    }

    private init() {}

    /// 起動時に必ず呼ぶ
    func onAppLaunch() {
        launchCount += 1

        guard launchCount == Self.trialLaunches, !reviewRequested else { return }

        // 起動直後に出すと画面の描画と重なって操作を邪魔するので少し遅らせる
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.showReviewPrompt = true
        }
    }

    /// 新規ユーザーの保護期間か
    var isFreeAdsPeriod: Bool {
        launchCount <= Self.trialLaunches
    }

    /// 全画面広告を出してよいか（1日1回まで）
    var shouldShowInterstitial: Bool {
        if isFreeAdsPeriod { return false }
        if let last = lastInterstitialDate,
           Calendar.current.isDateInToday(last) { return false }
        return true
    }

    /// 全画面広告を出した時刻を記録する
    func recordInterstitialShown() {
        lastInterstitialDate = Date()
    }

    /// 満足度への回答を受けて、評価先を振り分ける
    ///
    /// 「あとで」も含めて聞くのは一度きり。
    /// 繰り返し聞かれる方が印象を悪くする。
    func handleReviewAnswer(_ answer: ReviewAnswer) {
        reviewRequested = true
        showReviewPrompt = false

        switch answer {
        case .helpful:
            requestAppStoreReview()
        case .notHelpful:
            openFeedbackForm()
        case .later:
            break
        }

        showAdWarningIfNeeded()
    }

    /// 広告開始の告知を1回だけ出す
    ///
    /// レビューへの回答が終わってから出す。順序を逆にすると、
    /// 広告の話をした直後に評価を求めることになり印象が悪い。
    private func showAdWarningIfNeeded() {
        guard !adWarningShown else { return }
        adWarningShown = true

        // レビュー用のシートが閉じきってから出す（同時に2枚は出せない）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            self?.showAdWarning = true
        }
    }

    private func requestAppStoreReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }

        if #available(iOS 18.0, *) {
            AppStore.requestReview(in: scene)
        } else {
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    /// 不満の内容はストアではなくフォームで受ける
    private func openFeedbackForm() {
        guard let url = URL(string: SupportLinks.feedbackForm) else { return }
        UIApplication.shared.open(url)
    }
}
