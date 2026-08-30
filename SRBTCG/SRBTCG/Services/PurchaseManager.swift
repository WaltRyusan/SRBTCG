//
//  PurchaseManager.swift
//  SRBTCG
//
//  アプリ内課金管理（iOS StoreKit2対応）
//

import SwiftUI
import StoreKit
import Combine

/// 購入結果
enum PurchaseResult {
    case success
    case cancelled
    case pending
    case error(String)
    case alreadyOwned
    case productNotFound
    case networkError
}

/// アプリ内課金管理クラス（iOS StoreKit2連携）
@MainActor
class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()
    
    // --- 商品ID（App Store Connectで設定する） ---
    #if DEBUG
    /// 開発中に課金機能を購入せず確認するためのフラグ
    /// リリース前に必ず false へ戻すこと
    static let unlockAllInDebug = true
    #endif

    static let productSttExport = "stt_export"         // ¥160
    static let productAdFree = "ad_free"               // ¥320
    static let productPremiumBundle = "premium_bundle" // ¥400
    
    // --- 状態管理 ---
    @Published var purchasedProducts = Set<String>()
    @Published var isLoading = false
    @Published var products: [Product] = []
    
    private var updateListenerTask: Task<Void, Error>?
    
    // --- SharedPreferencesキー（オフライン時のキャッシュ用） ---
    private let cachePrefix = "purchase_cache_"
    
    /// 権利の問い合わせを一度でも完了したか
    ///
    /// Transaction.currentEntitlements は StoreKit への往復が入る。
    /// 未購入だと結果が空でキャッシュにも残らないため、
    /// 以前は録音ボタンを押すたびに毎回問い合わせが走り、
    /// 押してから数秒反応が返らなかった。
    /// 起動時とトランザクション更新時に取れば十分なので、以後はメモリで答える。
    private var hasLoadedEntitlements = false

    private init() {
        // 保存済みの購入状態を先に反映しておく。
        // これが呼ばれておらず、毎回StoreKitに聞きに行っていた。
        loadPurchaseCache()

        updateListenerTask = listenForTransactions()

        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    /// 商品情報を読み込む
    func loadProducts() async {
        do {
            let productIds = [
                Self.productSttExport,
                Self.productAdFree,
                Self.productPremiumBundle
            ]
            
            products = try await Product.products(for: productIds)
            print("Loaded \(products.count) products")
        } catch {
            print("Failed to load products: \(error)")
        }
    }
    
    /// 購入処理
    func purchase(_ productId: String) async -> PurchaseResult {
        guard let product = products.first(where: { $0.id == productId }) else {
            return .productNotFound
        }
        
        // 既に購入済みかチェック
        if await hasPurchased(productId) {
            return .alreadyOwned
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // 購入検証
                let transaction = try checkVerified(verification)
                
                // 購入を完了
                await transaction.finish()
                
                // 購入済み商品を更新
                await updatePurchasedProducts()
                
                return .success
                
            case .userCancelled:
                return .cancelled
                
            case .pending:
                return .pending
                
            @unknown default:
                return .error("Unknown purchase result")
            }
        } catch {
            return .error(error.localizedDescription)
        }
    }
    
    /// 購入復元
    func restorePurchases() async -> PurchaseResult {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await AppStore.sync()
            // 復元は取り直しが目的なので、キャッシュ済みでも必ず問い合わせる
            hasLoadedEntitlements = false
            await updatePurchasedProducts()
            
            if purchasedProducts.isEmpty {
                return .error(AppStrings.shared.purchaseRestoreNotFound)
            }
            
            return .success
        } catch {
            return .error(error.localizedDescription)
        }
    }
    
    /// 特定商品を購入済みか確認
    func hasPurchased(_ productId: String) async -> Bool {
        await hasAny(of: [productId])
    }

    /// いずれかを購入済みか
    ///
    /// 商品ごとに hasPurchased を呼ぶと、未購入のとき商品の数だけ
    /// StoreKitへの問い合わせが走る。まとめて1回で判定する。
    private func hasAny(of productIds: [String]) async -> Bool {
        if productIds.contains(where: { purchasedProducts.contains($0) }) {
            return true
        }
        guard !hasLoadedEntitlements else { return false }

        await updatePurchasedProducts()
        return productIds.contains(where: { purchasedProducts.contains($0) })
    }
    
    /// STT+Export購入済みか（バンドル購入も含む）
    func hasSttExport() async -> Bool {
        #if DEBUG
        // 開発中は購入せずに機能を確認できるようにする。
        // #if DEBUG のため本番ビルドには含まれない。
        if Self.unlockAllInDebug { return true }
        #endif
        return await hasAny(of: [Self.productSttExport, Self.productPremiumBundle])
    }
    
    /// 広告非表示購入済みか（バンドル購入も含む）
    func hasAdFree() async -> Bool {
        #if DEBUG
        if Self.unlockAllInDebug { return true }
        #endif
        return await hasAny(of: [Self.productAdFree, Self.productPremiumBundle])
    }
    
    /// プレミアムバンドル購入済みか
    func hasPremiumBundle() async -> Bool {
        await hasPurchased(Self.productPremiumBundle)
    }
    
    // MARK: - Private Methods
    
    /// トランザクションの監視
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            // 未完了のトランザクションを監視
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    
                    // 購入済み商品を更新
                    await self.updatePurchasedProducts()
                    
                    // トランザクションを完了
                    await transaction.finish()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    /// トランザクションの検証
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PurchaseError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    /// 購入済み商品を更新
    @MainActor
    private func updatePurchasedProducts() async {
        var purchased = Set<String>()
        
        // 現在の購入履歴を確認
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                purchased.insert(transaction.productID)
            } catch {
                print("Transaction verification failed: \(error)")
            }
        }
        
        purchasedProducts = purchased
        hasLoadedEntitlements = true

        // キャッシュに保存
        for productId in purchased {
            savePurchaseCache(productId, purchased: true)
        }
    }
    
    /// キャッシュに保存
    private func savePurchaseCache(_ productId: String, purchased: Bool) {
        UserDefaults.standard.set(purchased, forKey: "\(cachePrefix)\(productId)")
    }
    
    /// キャッシュから読み込み
    private func loadPurchaseCache() {
        for productId in [Self.productSttExport, Self.productAdFree, Self.productPremiumBundle] {
            if UserDefaults.standard.bool(forKey: "\(cachePrefix)\(productId)") {
                purchasedProducts.insert(productId)
            }
        }
    }
}

/// 購入エラー
enum PurchaseError: Error {
    case verificationFailed
}