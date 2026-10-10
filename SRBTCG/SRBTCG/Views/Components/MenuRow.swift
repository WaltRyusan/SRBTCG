//
//  MenuRow.swift
//  SRBTCG
//
//  設定メニューの1行。
//
//  アイコン・見出し・補足の3点で構成する。
//  見出しだけを並べるより、アイコンの色で用途が区別でき、
//  補足があることで「押すと何が起きるか」が開く前に分かる。
//

import SwiftUI

struct MenuRow: View {
    let icon: String
    let title: String
    let color: Color
    var subtitle: String? = nil
    /// 購入済みなどの完了状態。右端にチェックを出す
    var isChecked: Bool = false
    /// 通信待ちなど。右端にインジケータを出す
    var isLoading: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [color.opacity(0.9), color.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17))
                    .foregroundColor(AppColors.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer()

            if isLoading {
                ProgressView()
            } else if isChecked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppColors.accent)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary.opacity(0.6))
            }
        }
        .padding(.vertical, 4)
        // 背景を敷かないと、下のグラデーションに文字が溶けて読みにくい
        .listRowBackground(Color.black.opacity(0.3))
    }
}

/// ナビゲーションバーに置くインフォボタン
///
/// ツールバーのボタンは、何も指定しないと丸いガラスの背景が付いて
/// くり抜かれたように見える。plain にして背景を消す。
/// 右手で持ったときに届きやすいよう、置き場所は右端で統一している。
struct InfoToolbarButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "info.circle")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(AppColors.primary)
        }
        .buttonStyle(.plain)
    }
}

/// ツールバーの項目を、ガラスの背景なしで置く
///
/// iOS 26 は隣り合う項目をまとめて丸いガラスのカプセルに載せる。
/// 独自の配色と合わず、ボタンがくり抜かれたように見えるため外す。
/// `sharedBackgroundVisibility` は iOS 26 以降にしか無いので、
/// それ以前のOSでは従来どおり置くだけにする。
@ToolbarContentBuilder
func plainToolbarItem<Content: View>(
    placement: ToolbarItemPlacement,
    @ViewBuilder content: () -> Content
) -> some ToolbarContent {
    if #available(iOS 26.0, *) {
        ToolbarItem(placement: placement) { content() }
            .sharedBackgroundVisibility(.hidden)
    } else {
        ToolbarItem(placement: placement) { content() }
    }
}

#Preview {
    List {
        MenuRow(icon: "globe", title: "言語設定", color: .teal, subtitle: "日本語")
        MenuRow(icon: "xmark.square.fill", title: "広告非表示", color: .orange, isChecked: true)
        MenuRow(icon: "arrow.clockwise", title: "購入を復元", color: .green, isLoading: true)
    }
}
