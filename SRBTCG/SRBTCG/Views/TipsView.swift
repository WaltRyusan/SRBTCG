//
//  TipsView.swift
//  SRBTCG
//
//  サーモンランのTIPS一覧。内容は Resources/tips.json。
//

import SwiftUI

struct TipsView: View {
    private let store = TipsStore.shared
    @State private var selectedCategory: TipCategory = .basic
    @EnvironmentObject var appStrings: AppStrings

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedGradientBackground()

                LiquidShapeView()
                    .ignoresSafeArea()
                    .opacity(0.3)

                VStack(spacing: 14) {
                    categoryPicker

                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(store.tips(in: selectedCategory)) { tip in
                                TipCard(tip: tip)
                            }
                        }
                        .padding(.horizontal)
                        // 最後のカードがタブバーに隠れないよう下に余白を取る。
                        // バナーは出ないことがあるので、こちら側で確保しておく。
                        .padding(.bottom, 90)
                    }

                    // 購入済み・お試し期間中は何も描かれない
                    AdBannerView()
                }
            }
            .navigationTitle("TIPS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.surface.opacity(0.9), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.availableCategories) { category in
                    categoryChip(category)
                }
            }
            .padding(.horizontal)
            // ナビゲーションバーにくっつかない程度に空ける
            .padding(.top, 10)
        }
    }

    private func categoryChip(_ category: TipCategory) -> some View {
        let isSelected = selectedCategory == category

        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                selectedCategory = category
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 18))
                Text(category.label)
                    .font(.system(size: 22, weight: .semibold))
            }
            .padding(.horizontal, 20)
            .frame(height: 52)
            .background(
                isSelected ? AppColors.primary : AppColors.surface.opacity(0.6),
                in: Capsule()
            )
            .foregroundColor(isSelected ? AppColors.buttonText : AppColors.textSecondary)
        }
        .buttonStyle(.plain)
    }
}

/// TIPS 1件のカード。長い本文はたたんでおく。
private struct TipCard: View {
    let tip: Tip
    @State private var isExpanded = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.snappy(duration: 0.22)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    // 開いているカードのタイトルは色を変える。
                    // 本文と同じ白のままだと、どれを開いているか分かりにくい。
                    Text(tip.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(isExpanded ? AppColors.primary : AppColors.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 4)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(isExpanded ? AppColors.primary : AppColors.textSecondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                // ** で囲んだ箇所を太字にする
                // タイトルと同じ色にする。
                // 薄いグレーだと本文が読みにくかった。
                // タイトルとの区別は太さ（bold / regular）で付ける。
                Text(attributedBody)
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let url = tip.sourceURL {
                    Button {
                        openURL(url)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.system(size: 10))
                            Text("出典")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(AppColors.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface.opacity(0.5))
        .cornerRadius(12)
    }

    /// Markdown の ** を太字として解釈する。
    /// 解釈に失敗したらそのまま表示する（記号が見えるだけで壊れはしない）。
    private var attributedBody: AttributedString {
        (try? AttributedString(
            markdown: tip.body,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(tip.body)
    }
}

#Preview {
    TipsView()
        .environmentObject(AppStrings.shared)
}
