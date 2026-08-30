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
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                List {
                    // 言語設定
                    Section {
                        Button(action: { showLanguageSelect = true }) {
                            HStack {
                                Label(appStrings.languageSetting, systemImage: "globe")
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                                Text(appStrings.currentLanguage.displayName)
                                    .foregroundColor(AppColors.textSecondary)
                                Image(systemName: "chevron.right")
                                    .foregroundColor(AppColors.textSecondary)
                                    .font(.system(size: 14))
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // データ管理
                    // エクスポート/インポートはv2で提供予定のため非表示。
                    // 実装（exportData / importData）は残してある。
                    if Self.showsDataManagement {
                        Section(header: Text(appStrings.dataManagement)) {
                            Button(action: exportData) {
                                Label(appStrings.exportData, systemImage: "square.and.arrow.up")
                                    .foregroundColor(AppColors.textPrimary)
                            }

                            Button(action: importData) {
                                Label(appStrings.importData, systemImage: "square.and.arrow.down")
                                    .foregroundColor(AppColors.textPrimary)
                            }
                        }
                    }
                    
                    // 課金
                    Section(header: Text(appStrings.purchaseTitle)) {
                        Button(action: { showPurchaseView = true }) {
                            HStack {
                                Label("STT+Export", systemImage: "mic.badge.plus")
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                                if purchaseManager.purchasedProducts.contains(PurchaseManager.productSttExport) ||
                                   purchaseManager.purchasedProducts.contains(PurchaseManager.productPremiumBundle) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AppColors.accent)
                                }
                            }
                        }
                        
                        Button(action: { showPurchaseView = true }) {
                            HStack {
                                Label(appStrings.purchaseAdFree, systemImage: "xmark.square")
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                                if purchaseManager.purchasedProducts.contains(PurchaseManager.productAdFree) ||
                                   purchaseManager.purchasedProducts.contains(PurchaseManager.productPremiumBundle) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AppColors.accent)
                                }
                            }
                        }
                        
                        Button(action: restorePurchases) {
                            Label(appStrings.purchaseRestore, systemImage: "arrow.clockwise")
                                .foregroundColor(AppColors.primary)
                        }
                    }
                    
                    // アプリについて
                    Section {
                        Button(action: { showAbout = true }) {
                            HStack {
                                Label(appStrings.aboutApp, systemImage: "info.circle")
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(AppColors.textSecondary)
                                    .font(.system(size: 14))
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(appStrings.settings)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showLanguageSelect) {
                LanguageChangeView()
            }
            .sheet(isPresented: $showPurchaseView) {
                PurchaseView()
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker(
                    onPick: { url in
                        let result = DataManager.shared.importData(from: url)
                        if result.success {
                            alertMessage = appStrings.importSuccess(result.count)
                        } else {
                            alertMessage = result.error ?? appStrings.importError
                        }
                        showAlert = true
                    },
                    onCancel: {}
                )
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url], completion: nil)
                }
            }
            .alert("", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
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
                    Button("閉じる") {
                        dismiss()
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
                AppColors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // アプリアイコン
                        Image("icon_image")
                            .resizable()
                            .frame(width: 120, height: 120)
                            .cornerRadius(24)
                        
                        Text("バイトチームコンテスト")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text("Version 1.0.0")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                        
                        // 説明
                        Text("サーモンランのバイトチームコンテストをサポートするアプリです。Wave管理、音声認識、タイミングガイドなどの機能を提供します。")
                            .font(.body)
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Divider()
                        
                        // リンク
                        Link("プライバシーポリシー", destination: URL(string: "https://example.com/privacy")!)
                            .foregroundColor(AppColors.primary)
                        
                        Link("利用規約", destination: URL(string: "https://example.com/terms")!)
                            .foregroundColor(AppColors.primary)
                    }
                    .padding()
                }
            }
            .navigationTitle(appStrings.aboutApp)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
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