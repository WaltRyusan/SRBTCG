//
//  ReviewPromptSheet.swift
//  SRBTCG
//
//  満足度を聞いてから評価先を振り分けるシート。
//
//  「はい」と答えた人だけを App Store のレビューへ流し、
//  「いいえ」はフォームで受ける。低評価をストアに直接書かれるのを防ぎ、
//  改善点は自分に届くようにするため（共通スキル `review-and-feedback`）。
//  他の3アプリ（ポケタイプ・イカブキ・コードトーン）と同じ作り。
//

import SwiftUI
import StoreKit

/// 満足度への答え
enum ReviewAnswer {
    /// 役に立っている → App Store のレビューへ
    case helpful
    /// 役に立っていない → フィードバックフォームへ
    case notHelpful
    /// あとで
    case later
}

struct ReviewPromptSheet: View {
    let onAnswer: (ReviewAnswer) -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "heart.fill")
                .font(.system(size: 34))
                .foregroundStyle(.pink)
                .padding(.top, 28)

            Text("サモランガイドは役に立っていますか？")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            VStack(spacing: 8) {
                Button {
                    onAnswer(.helpful)
                } label: {
                    Text("はい")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(AppColors.buttonPrimary, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundColor(AppColors.buttonText)
                }

                Button {
                    onAnswer(.notHelpful)
                } label: {
                    Text("いいえ")
                        .font(.system(size: 15))
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundColor(AppColors.textPrimary)
                }

                Button("あとで") {
                    onAnswer(.later)
                }
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
                .padding(.top, 2)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
        .presentationDetents([.height(300)])
    }
}

/// 広告が始まることを事前に知らせるシート
///
/// 何の予告もなく広告が出ると「急に広告だらけになった」と受け取られる。
/// 先に一度伝えておくことで、その反応を減らす。
struct AdWarningSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onPurchase: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "megaphone.fill")
                .font(.system(size: 30))
                .foregroundColor(AppColors.golden)
                .padding(.top, 28)

            Text("ここから広告が表示されます")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)

            Text("画面下にバナーが出るほか、起動時に1日1回ほど全画面広告が表示されます。\n"
                 + "広告収入で開発を続けています。")
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 8) {
                Button {
                    dismiss()
                } label: {
                    Text("無料で続ける")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundColor(AppColors.textPrimary)
                }

                Button {
                    dismiss()
                    onPurchase()
                } label: {
                    Text("広告を消す")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(AppColors.buttonPrimary, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundColor(AppColors.buttonText)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
        .presentationDetents([.height(340)])
    }
}

#Preview {
    ReviewPromptSheet { _ in }
}
