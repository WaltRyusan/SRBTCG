//
//  SettingsView.swift
//  SRBTCG
//
//  設定画面
//

import SwiftUI
import StoreKit

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appStrings: AppStrings
    @EnvironmentObject var purchaseManager: PurchaseManager
    
    @State private var showLanguageSelect = false
    @State private var showPurchaseView = false
    @State private var showAbout = false
    @State private var showDocumentPicker = false

    /// データ管理（エクスポート/インポート）を表示するか
    /// v2で提供予定のため、v1ではfalseにしている
    private static let showsDataManagement = false
    @State private var showShareSheet = false
    @State private var exportURL: URL?
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    /// アプリの表示名（Info.plistから取るのでコード側で二重管理しない）
    private var appDisplayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "サモランガイド"
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    }

    /// 購入済みの項目にはチェックを出す
    private func isPurchased(_ ids: [String]) -> Bool {
        ids.contains { purchaseManager.purchasedProducts.contains($0) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 他の画面と同じ背景にして、設定だけ浮かないようにする
                AnimatedGradientBackground()

                LiquidShapeView()
                    .ignoresSafeArea()
                    .opacity(0.3)

                List {
                    // 購入
                    Section {
                        Button {
                            showPurchaseView = true
                        } label: {
                            MenuRow(
                                icon: "mic.badge.plus",
                                title: "STT+Export",
                                color: AppColors.primary,
                                subtitle: "声で記録して書き出す",
                                isChecked: isPurchased([
                                    PurchaseManager.productSttExport,
                                    PurchaseManager.productPremiumBundle
                                ])
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            showPurchaseView = true
                        } label: {
                            MenuRow(
                                icon: "xmark.square.fill",
                                title: appStrings.purchaseAdFree,
                                color: AppColors.golden,
                                subtitle: "バナーと全画面広告を消す",
                                isChecked: isPurchased([
                                    PurchaseManager.productAdFree,
                                    PurchaseManager.productPremiumBundle
                                ])
                            )
                        }
                        .buttonStyle(.plain)

                        Button(action: restorePurchases) {
                            MenuRow(
                                icon: "arrow.clockwise",
                                title: appStrings.purchaseRestore,
                                color: AppColors.accent,
                                // 復元はAppStoreとの通信を待つ。
                                // 何も出ないと固まったように見えていた。
                                isLoading: purchaseManager.isLoading
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(purchaseManager.isLoading)
                    }

                    // 表示設定
                    Section {
                        Button {
                            showLanguageSelect = true
                        } label: {
                            MenuRow(
                                icon: "globe",
                                title: appStrings.languageSetting,
                                color: .teal,
                                subtitle: appStrings.currentLanguage.displayName
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // データ管理
                    // エクスポート/インポートはv2で提供予定のため非表示。
                    // 実装（exportData / importData）は残してある。
                    if Self.showsDataManagement {
                        Section {
                            Button(action: exportData) {
                                MenuRow(icon: "square.and.arrow.up", title: appStrings.exportData, color: .blue)
                            }
                            .buttonStyle(.plain)

                            Button(action: importData) {
                                MenuRow(icon: "square.and.arrow.down", title: appStrings.importData, color: .blue)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // 問い合わせ・紹介
                    Section {
                        // レビュー導線とは別に、いつでも意見を送れる入口を用意する
                        Button {
                            if let url = URL(string: SupportLinks.feedbackForm) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            MenuRow(
                                icon: "bubble.left.and.text.bubble.right.fill",
                                title: "ご意見・ご要望",
                                color: .green,
                                subtitle: "バグ報告・機能要望はこちら"
                            )
                        }
                        .buttonStyle(.plain)

                        // 気に入った人が友達に薦められるようにする。
                        // 広告や課金より角が立たない形で広がる導線。
                        ShareLink(item: SupportLinks.shareMessage) {
                            MenuRow(
                                icon: "square.and.arrow.up.fill",
                                title: "このアプリを紹介する",
                                color: .orange,
                                subtitle: "友達に教える"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // アプリ情報
                    Section {
                        Button {
                            showAbout = true
                        } label: {
                            MenuRow(icon: "app.fill", title: appStrings.aboutApp, color: .purple)
                        }
                        .buttonStyle(.plain)

                        Link(destination: URL(string: SupportLinks.support)!) {
                            MenuRow(icon: "questionmark.circle.fill", title: "サポート", color: .blue)
                        }

                        Link(destination: URL(string: SupportLinks.privacyPolicy)!) {
                            MenuRow(icon: "hand.raised.fill", title: "プライバシーポリシー", color: .gray)
                        }

                        Link(destination: URL(string: SupportLinks.terms)!) {
                            MenuRow(icon: "doc.text.fill", title: "利用規約", color: .gray)
                        }
                    }
                }
                .scrollContentBackground(.hidden)

                // フッター（バージョン）
                VStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Divider()
                            .background(.white.opacity(0.2))
                        Text("v\(appVersion)")
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.vertical, 8)
                    }
                    .background(Color.black.opacity(0.1))
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    // 「設定」ではなくアプリ名を出す。
                    // ここは設定だけでなく、使い方や問い合わせも含む入口のため。
                    Text(appDisplayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
            .sheet(isPresented: $showLanguageSelect) {
                LanguageChangeView()
                    .environmentObject(appStrings)
            }
            .sheet(isPresented: $showPurchaseView) {
                PurchaseView()
                    .environmentObject(appStrings)
                    .environmentObject(purchaseManager)
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
                    .environmentObject(appStrings)
            }
            .alert(alertMessage, isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            }
        }
    }

    private func exportData() {
        if let url = DataManager.shared.exportAllData() {
            exportURL = url
            showShareSheet = true
        } else {
            alertMessage = appStrings.noDataToExport
            showAlert = true
        }
    }
    
    private func importData() {
        showDocumentPicker = true
    }
    
    private func restorePurchases() {
        Task {
            _ = await purchaseManager.restorePurchases()
            // TODO: 結果表示
        }
    }
}

struct LanguageChangeView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appStrings: AppStrings
    @State private var selectedLanguage: AppLanguage
    
    init() {
        _selectedLanguage = State(initialValue: AppStrings.shared.currentLanguage)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                List {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Button(action: { selectedLanguage = language }) {
                            HStack {
                                Text(language.displayName)
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                                if selectedLanguage == language {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppColors.primary)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(appStrings.languageSetting)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(appStrings.cancel) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        appStrings.saveLanguage(selectedLanguage)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PurchaseView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appStrings: AppStrings
    @EnvironmentObject var purchaseManager: PurchaseManager
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 各商品
                        ForEach(purchaseManager.products, id: \.id) { product in
                            PurchaseCard(product: product)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(appStrings.purchaseTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // 文字よりアイコンの方が、どの言語でも同じ幅で収まる
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
        }
        .task {
            await purchaseManager.loadProducts()
        }
    }
}

struct PurchaseCard: View {
    let product: Product
    @EnvironmentObject var purchaseManager: PurchaseManager
    @State private var isPurchasing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(product.displayName)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                Text(product.displayPrice)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.golden)
            }
            
            Text(product.description)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
            
            Button(action: purchase) {
                if isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.buttonText))
                } else {
                    Text("購入")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(AppColors.buttonPrimary)
            .foregroundColor(AppColors.buttonText)
            .cornerRadius(8)
            .disabled(isPurchasing)
        }
        .padding()
        .background(AppColors.surface)
        .cornerRadius(12)
    }
    
    private func purchase() {
        isPurchasing = true
        Task {
            _ = await purchaseManager.purchase(product.id)
            isPurchasing = false
            // TODO: 結果表示
        }
    }
}

struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appStrings: AppStrings

    var body: some View {
        NavigationStack {
            ZStack {
                // 他の画面と同じ背景にする
                AnimatedGradientBackground()

                LiquidShapeView()
                    .ignoresSafeArea()
                    .opacity(0.3)

                // アイコン画像は置かない。
                // Assets に icon_image.png が imageset ではなく
                // ただのファイルとして入っており、読み込めていなかった。
                //
                // バージョンとリンク類もここには出さない。
                // 呼び出し元のメニューに同じものが並んでいて重複するため。
                ScrollView {
                    VStack(spacing: 20) {
                        Text("バイトチームコンテスト")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textPrimary)

                        Text("サーモンランのバイトチームコンテストをサポートするアプリです。Wave管理、音声認識、タイミングガイドなどの機能を提供します。")
                            .font(.body)
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 40)
                    .padding()
                }
            }
            .navigationTitle(appStrings.aboutApp)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.surface.opacity(0.9), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppStrings.shared)
        .environmentObject(PurchaseManager.shared)
}