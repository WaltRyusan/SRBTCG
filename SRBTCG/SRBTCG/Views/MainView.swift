//
//  MainView.swift
//  SRBTCG
//
//  リスト一覧画面
//

import SwiftUI

struct MainView: View {
    @State private var savedTitles: [String] = []
    @State private var isEditing = false
    @State private var editSelectedItems = Set<String>()
    @State private var showSettings = false
    @State private var showDeleteConfirmation = false
    @State private var navigationPath = NavigationPath()
    @State private var showCopyConfirmation = false
    @State private var selectedTitle: String?
    @AppStorage("skipCopyConfirmation") private var skipCopyConfirmation = false
    
    @EnvironmentObject var appStrings: AppStrings
    @StateObject private var purchaseManager = PurchaseManager.shared
    
    var filteredTitles: [String] {
        return savedTitles.reversed() // 新しいものを上に表示
    }
    
    var mainContent: some View {
        ZStack {
            AnimatedGradientBackground()
            
            LiquidShapeView()
                .ignoresSafeArea()
                .opacity(0.3)
            
            if savedTitles.isEmpty {
                emptyStateView
            } else {
                listView
            }
        }
    }
    
    var emptyStateView: some View {
        VStack(spacing: 30) {
            Text(appStrings.noSavedLists)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding()
                .liquidGlassCard()
            
            // プラスボタン（リストが空の時も表示）
            SphericalButton(
                icon: "plus",
                color: AppColors.golden,
                action: createNewList
            )
        }
        .padding(.horizontal)
        .padding(.bottom, 100)
    }
    
    var listView: some View {
        ScrollView {
            VStack(spacing: 12) {
                // プラスボタンを常に最上部に配置
                if !isEditing {
                    HStack {
                        Spacer()
                        
                        SphericalButton(
                            icon: "plus",
                            color: AppColors.golden,
                            action: createNewList
                        )
                        .padding(.bottom, 20)
                        
                        Spacer()
                    }
                }
                
                ForEach(filteredTitles, id: \.self) { title in
                    if isEditing {
                        Button {
                            toggleSelection(title)
                        } label: {
                            GlassListRow(
                                title: title,
                                isEditing: isEditing,
                                isSelected: editSelectedItems.contains(title)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        NavigationLink(value: title) {
                            GlassListRow(
                                title: title,
                                isEditing: isEditing,
                                isSelected: false
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
    }
    
    var floatingAddButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                FloatingActionButton(icon: "plus", action: createNewList)
                    .padding()
            }
        }
    }
    
    var leadingButton: some View {
        Group {
            if isEditing {
                Button(action: {
                    isEditing = false
                    editSelectedItems.removeAll()
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(AppColors.primary)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: { isEditing = true }) {
                    Image(systemName: "pencil")
                        .foregroundColor(AppColors.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    var trailingButton: some View {
        Group {
            if isEditing {
                HStack(spacing: 16) {
                    // コピーボタン（1つ選択時のみ活性化）
                    Button(action: duplicateSelected) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(editSelectedItems.count == 1 ? AppColors.primary : AppColors.textSecondary.opacity(0.3))
                    }
                    .disabled(editSelectedItems.count != 1)
                    .buttonStyle(.plain)
                    
                    // 削除ボタン（選択項目があるときに活性化）
                    Button(action: { showDeleteConfirmation = true }) {
                        Image(systemName: "trash")
                            .foregroundColor(editSelectedItems.isEmpty ? AppColors.textSecondary.opacity(0.3) : AppColors.danger)
                    }
                    .disabled(editSelectedItems.isEmpty)
                    .buttonStyle(.plain)
                }
            } else {
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                        .foregroundColor(AppColors.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            mainContent
            .navigationTitle(appStrings.bigRunContestHeader)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.surface.opacity(0.9), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    leadingButton
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    trailingButton
                }
            }
            .navigationDestination(for: String.self) { title in
                WaveListView(initialTitle: title, initialWaveTexts: loadWaveTexts(for: title))
                    .environmentObject(appStrings)
                    .environmentObject(purchaseManager)
            }
        }
        .onAppear {
            loadSavedTitles()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(appStrings)
        }
        .alert(appStrings.deleteConfirmTitle, isPresented: $showDeleteConfirmation) {
            Button(appStrings.cancel, role: .cancel) { }
            Button(appStrings.delete, role: .destructive) {
                deleteSelectedItems()
            }
        } message: {
            Text(appStrings.deleteConfirmMessage(editSelectedItems.count))
        }
        .sheet(isPresented: $showCopyConfirmation) {
            if let title = selectedTitle {
                DialogHelper.CopyConfirmationView(
                    itemName: title,
                    onConfirm: { _ in
                        performDuplicate(title)
                        showCopyConfirmation = false
                    },
                    onCancel: {
                        showCopyConfirmation = false
                    }
                )
                .presentationDetents([.height(250)])
                .environmentObject(appStrings)
            }
        }
    }
    
    // MARK: - Methods
    
    private func loadSavedTitles() {
        savedTitles = UserDefaults.standard.stringArray(forKey: "savedTitles") ?? []
    }
    
    private func saveTitlesList() {
        UserDefaults.standard.set(savedTitles, forKey: "savedTitles")
    }
    
    private func createNewList() {
        let newTitle = DateUtil.formattedToday(existingTitles: savedTitles)
        print("Creating new list: \(newTitle)")
        
        // タイトルをリストに追加
        savedTitles.append(newTitle)
        saveTitlesList()
        
        // 空のWaveTextsを初期化
        let emptyWaveTexts: [Int: String] = [:]
        if let data = try? JSONEncoder().encode(emptyWaveTexts) {
            UserDefaults.standard.set(data, forKey: newTitle)
        }
        
        print("Saved titles: \(savedTitles)")
        
        // WaveListViewに遷移
        navigateToWaveList(newTitle)
    }
    
    private func navigateToWaveList(_ title: String) {
        print("Navigation to WaveListView: \(title)")
        
        // タイトルがリストに存在することを確認
        if !savedTitles.contains(title) {
            print("Title not found in savedTitles, adding...")
            savedTitles.append(title)
            saveTitlesList()
        }
        
        // NavigationStackで遷移
        navigationPath.append(title)
        
        print("Opening WaveListView for: \(title)")
    }
    
    private func loadWaveTexts(for title: String) -> [Int: String]? {
        print("Loading wave texts for: \(title)")
        guard let data = UserDefaults.standard.data(forKey: title) else {
            print("No data found for \(title), returning empty dictionary")
            return [:]
        }
        
        do {
            let waveTexts = try JSONDecoder().decode([Int: String].self, from: data)
            print("Loaded \(waveTexts.count) wave texts for \(title)")
            return waveTexts
        } catch {
            print("Failed to decode wave texts for \(title): \(error)")
            return [:]
        }
    }
    
    private func toggleSelection(_ title: String) {
        if editSelectedItems.contains(title) {
            editSelectedItems.remove(title)
        } else {
            editSelectedItems.insert(title)
        }
    }
    
    private func duplicateSelected() {
        guard editSelectedItems.count == 1,
              let originalTitle = editSelectedItems.first else { return }
        
        // スキップ設定されていたら即座にコピー
        if skipCopyConfirmation {
            performDuplicate(originalTitle)
        } else {
            selectedTitle = originalTitle
            showCopyConfirmation = true
        }
    }
    
    private func performDuplicate(_ originalTitle: String) {
        var newTitle = "\(originalTitle)_copy"
        var count = 2
        while savedTitles.contains(newTitle) {
            newTitle = "\(originalTitle)_copy_\(count)"
            count += 1
        }
        
        // 元のデータをコピー
        if let waveData = UserDefaults.standard.data(forKey: originalTitle) {
            UserDefaults.standard.set(waveData, forKey: newTitle)
        }
        
        savedTitles.append(newTitle)
        saveTitlesList()
        
        isEditing = false
        editSelectedItems.removeAll()
        
        kDebugSuccessPrint("リスト「\(originalTitle)」を「\(newTitle)」にコピーしました")
    }
    
    private func deleteSelectedItems() {
        for title in editSelectedItems {
            UserDefaults.standard.removeObject(forKey: title)
            savedTitles.removeAll { $0 == title }
        }
        saveTitlesList()
        
        isEditing = false
        editSelectedItems.removeAll()
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        savedTitles.move(fromOffsets: source, toOffset: destination)
        saveTitlesList()
    }
    
    private func moveList(from title: String) {
        // ドラッグハンドル用の関数（現在は使用していない）
    }
}

struct GlassListRow: View {
    let title: String
    let isEditing: Bool
    let isSelected: Bool
    @State private var isPressed = false
    
    var body: some View {
        HStack {
            if isEditing {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? AppColors.primary : AppColors.textSecondary)
                    .font(.system(size: 22))
                    .animation(.spring(), value: isSelected)
            }
            
            Text(title)
                .foregroundColor(AppColors.textPrimary)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if isEditing {
                Image(systemName: "line.horizontal.3")
                    .foregroundColor(AppColors.textSecondary)
                    .font(.system(size: 18))
            } else {
                Image(systemName: "chevron.right")
                    .foregroundColor(AppColors.textSecondary)
                    .font(.system(size: 14))
            }
        }
        .padding()
        .liquidGlassCard()
        .scaleEffect(isPressed ? 0.98 : 1)
        // セル内のどこをタップしても反応するように、余白も含めて判定させる
        .contentShape(Rectangle())
    }

    // タップの扱いは呼び出し側に任せている。
    // ここに .onTapGesture を置くと、中身が空でもタップを消費してしまい、
    // 親のNavigationLinkに届かず画面遷移できなくなる。
}

#Preview {
    MainView()
        .environmentObject(AppStrings.shared)
}