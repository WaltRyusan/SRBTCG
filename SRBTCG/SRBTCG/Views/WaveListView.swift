//
//  WaveListView.swift
//  SRBTCG
//
//  Wave管理画面
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct WaveListView: View {
    let initialTitle: String
    let initialWaveTexts: [Int: String]?
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appStrings: AppStrings
    @EnvironmentObject var purchaseManager: PurchaseManager
    
    @State private var title: String = ""
    @State private var waveTexts: [Int: String] = [:] // 0-249 のインデックスで管理（5waves × 50entries）
    @State private var isRecording = false
    /// 実時刻ベースの経過時間
    @State private var clock = ElapsedClock()
    /// タイトル入力中かどうか（キーボード表示中は下部ボタンを隠す）
    @FocusState private var isEditingTitle: Bool

    /// エクスポート/インポートのメニューを出すか
    /// v2で提供予定のため、v1ではfalseにしている
    private static let showsExportMenu = false
    /// STT未購入で録音できないことを知らせる
    @State private var showPurchaseRequired = false
    /// 録音中止の確認
    @State private var showStopConfirmation = false
    @State private var isWaitingForStart = false
    @State private var isPlaying = false
    @State private var expandedWaves = Set<Int>()
    @State private var showPlaybackView = false
    
    // 録音関連
    @State private var progressWave = 0
    @State private var progressSecond = 0
    @State private var countdownRemaining = Int(ceil(WaveTiming.initialCountdown))
    @State private var recordingTimer: Timer?
    
    // Wave別録音
    @State private var showWaveRecordingDialog = false
    @State private var selectedWaveForRecording = 1
    @State private var showRecordingConfirmDialog = false
    @State private var showPlaybackConfirmDialog = false
    @State private var showNoTextDialog = false
    @State private var showMenu = false
    @State private var showDocumentPicker = false
    @State private var importError: String?
    @State private var showImportError = false
    @State private var currentInitialTitle: String = ""
    
    @StateObject private var ttsManager = TTSManager.shared
    @StateObject private var sttManager = STTManager.shared
    
    init(initialTitle: String, initialWaveTexts: [Int: String]? = nil) {
        self.initialTitle = initialTitle
        self.initialWaveTexts = initialWaveTexts
    }
    
    /// 画面本体（modifierを付ける前の中身）
    /// bodyに全部書くと型チェックが通らないため分けている
    @ViewBuilder
    private var content: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            // ステータスバーの背景色
            VStack {
                AppColors.surface
                    .frame(height: 0)
                    .ignoresSafeArea()
                Spacer()
            }

            waveSections
            floatingButtons

            // 録音中オーバーレイ
            if isRecording || isWaitingForStart {
                RecordingOverlay(
                    isWaitingForStart: isWaitingForStart,
                    progressWave: progressWave,
                    progressSecond: progressSecond,
                    countdownRemaining: countdownRemaining,
                    onStart: startRecording,
                    onStop: requestStopRecording
                )
            }
        }
    }

    var body: some View {
        dialogs(chrome)
    }

    /// ダイアログ群
    /// bodyのmodifierチェーンが長すぎて型チェックが通らないため分けている
    @ViewBuilder
    private func dialogs<C: View>(_ base: C) -> some View {
        base
            .alert("Wave \(selectedWaveForRecording) から録音", isPresented: $showWaveRecordingDialog) {
                Button("キャンセル", role: .cancel) { }
                Button("録音開始") {
                startWaveSpecificRecording()
            }
            } message: {
                Text("Wave \(selectedWaveForRecording) から録音を開始します。地面に着地したタイミングで録音開始してください。")
        }
            .alert("録音確認", isPresented: $showRecordingConfirmDialog) {
                Button("キャンセル", role: .cancel) { }
                Button("録音開始") {
                startRecordingAfterConfirm()
            }
            } message: {
                Text("地面に着地したタイミングで録音を開始してください。準備ができたら「録音開始」をタップしてください。")
        }
            .alert("再生確認", isPresented: $showPlaybackConfirmDialog) {
                Button("キャンセル", role: .cancel) { }
                Button("再生開始") {
                startPlaybackAfterConfirm()
            }
            } message: {
                Text("地面に着地したタイミングで再生を開始してください。準備ができたら「再生開始」をタップしてください。")
        }
            .alert("テキストなし", isPresented: $showNoTextDialog) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("再生するテキストがありません。")
        }
            .alert("録音を中止しますか？", isPresented: $showStopConfirmation) {
                Button("続ける", role: .cancel) { }
                Button("中止する", role: .destructive) { stopRecording() }
            } message: {
                Text("ここまでに録音した内容だけが記録されます。中止した時点より後のWaveは記録されません。")
        }
            .alert("STT機能が必要です", isPresented: $showPurchaseRequired) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("音声での録音にはSTT機能の購入が必要です。設定画面から購入できます。")
        }
            .alert("インポートエラー", isPresented: $showImportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importError ?? "不明なエラー")
        }
    }

    private var chrome: some View {
        content
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.surface.opacity(0.9), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    TextField("タイトルを入力", text: $title)
                        .focused($isEditingTitle)
                        .submitLabel(.done)
                        .onSubmit { isEditingTitle = false }
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(AppColors.textPrimary)
                        .textFieldStyle(.plain)
                        .frame(minWidth: 200)
                        .submitLabel(.done)
                        // 入力のたびに保存すると、1文字ずつリネームが走り
                        // 中途半端なタイトルでキーが作られては消える。
                        // 編集を終えたタイミングでまとめて確定する。
                        .onChange(of: isEditingTitle) { _, focused in
                            if !focused { commitTitleChange() }
                        }
                }
                
                // エクスポート/インポートはv2で提供予定のため、
                // v1ではメニューごと非表示にする。
                // 実装（exportData / handleImportedFile / actionSheet）は残してある。
                if WaveListView.showsExportMenu {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showMenu = true
                        }) {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(AppColors.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .sheet(isPresented: $showPlaybackView) {
                PlaybackView(
                    title: title,
                    waveTexts: waveTexts
                )
            }

            .sheet(isPresented: $showDocumentPicker) {
                JSONDocumentPicker(onPicked: handleImportedFile)
            }
            .actionSheet(isPresented: $showMenu) {
                ActionSheet(
                    title: Text("メニュー"),
                    buttons: [
                        // 「タイトル編集」は中身が空で押しても何も起きなかったため削除。
                        // タイトルは画面上部のテキストフィールドを直接タップして編集する。
                        .default(Text("エクスポート")) {
                            exportData()
                        },
                        .default(Text("インポート")) {
                            showDocumentPicker = true
                        },
                        .cancel(Text("キャンセル"))
                    ]
                )
        }
        .onAppear {
            title = initialTitle
            waveTexts = initialWaveTexts ?? [:]
            currentInitialTitle = initialTitle
            setupSTT()
            
            // ナビゲーションバーの外観を設定
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(AppColors.surface)
            appearance.titleTextAttributes = [.foregroundColor: UIColor(AppColors.textPrimary)]
            
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
        }
        .onDisappear {
            // キーボードを閉じずに戻った場合もここで確定する
            commitTitleChange()
            saveData()
        }
        .toolbar(.hidden, for: .tabBar)
    }
    
    // MARK: - Methods
    
    private func toggleWave(_ wave: Int) {
        if expandedWaves.contains(wave) {
            expandedWaves.remove(wave)
        } else {
            expandedWaves.insert(wave)
        }
    }
    
    
    private func startPlayback() {
        // テキストが存在するかチェック
        let hasAnyText = waveTexts.values.contains { !$0.isEmpty }
        
        if hasAnyText {
            showPlaybackConfirmDialog = true
        } else {
            showNoTextDialog = true
        }
    }
    
    private func startPlaybackAfterConfirm() {
        showPlaybackView = true
    }
    
    private func startWaveRecording(wave: Int) {
        selectedWaveForRecording = wave
        showWaveRecordingDialog = true
    }
    
    private func startWaveSpecificRecording() {
        Task {
            // STT機能の課金チェック
            let hasPurchased = await purchaseManager.hasSttExport()
            if !hasPurchased {
                showPurchaseRequired = true
                return
            }
            
            // 指定Waveからの録音を開始
            progressWave = selectedWaveForRecording
            progressSecond = 0
            isWaitingForStart = true
            countdownRemaining = Int(ceil(WaveTiming.initialCountdown))
            
            Task { @MainActor in
                ttsManager.speak("Wave \(selectedWaveForRecording)から録音開始。15秒後に着地タイミングでタップしてください")
            }
            startCountdownTimer()
        }
    }
    
    private func startRecording() {
        Task {
            // STT機能の課金チェック
            // 未購入のまま無言でreturnしていたため、押しても何も起きなかった
            let hasPurchased = await purchaseManager.hasSttExport()
            if !hasPurchased {
                showPurchaseRequired = true
                return
            }
            
            if isWaitingForStart {
                // 2回目のタップで実際に録音開始
                recordingTimer?.invalidate()
                actuallyStartRecording()
            } else {
                // 1回目のタップでダイアログ表示
                showRecordingConfirmDialog = true
            }
        }
    }
    
    private func startRecordingAfterConfirm() {
        // ダイアログ確認後にカウントダウン開始
        isWaitingForStart = true
        countdownRemaining = Int(ceil(WaveTiming.initialCountdown))
        Task { @MainActor in
            ttsManager.speak(appStrings.startingRecording)
        }
        startCountdownTimer()
    }
    
    /// 着地待ちのカウントダウン
    /// 0になっても自動では始めない（着地タイミングで手動タップさせる）
    private func startCountdownTimer() {
        clock.reset()
        let duration = WaveTiming.initialCountdown
        countdownRemaining = Int(ceil(duration))
        var lastSpokenSecond = countdownRemaining + 1

        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: WaveTiming.tick, repeats: true) { timer in
            let remaining = max(0, duration - clock.elapsed)
            countdownRemaining = Int(ceil(remaining))

            let currentSecond = Int(ceil(remaining))
            if currentSecond <= WaveTiming.countdownSpeakFrom,
               currentSecond > 0,
               currentSecond < lastSpokenSecond {
                lastSpokenSecond = currentSecond
                Task { @MainActor in
                    ttsManager.speak("\(currentSecond)")
                }
            }

            if remaining <= 0 {
                timer.invalidate()
            }
        }
    }
    
    /// 現在の progressWave から録音を開始する
    ///
    /// 経過時間はElapsedClockで実時刻から求める。
    /// 以前はタイマー発火ごとに progressSecond += 2 していたため、
    /// STT/TTSでメインスレッドが詰まると発火遅延がそのまま累積し、
    /// 再生側の時間とズレていた。
    private func actuallyStartRecording() {
        isWaitingForStart = false
        isRecording = true

        if progressWave == 0 {
            progressWave = 1
        }
        progressSecond = 0
        clock.reset()

        Task { @MainActor in
            ttsManager.speak(appStrings.waveStart(progressWave))
        }

        do {
            try sttManager.startRecording()
        } catch {
            print("Failed to start recording: \(error)")
            stopRecording()
            return
        }

        var previousText = ""
        var lastSavedSlot = -1

        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: WaveTiming.tick, repeats: true) { timer in
            let elapsed = min(clock.elapsed, WaveTiming.waveDuration)
            progressSecond = Int(elapsed)

            // 2秒ごとの枠に入ったら、その枠へ差分テキストを保存する
            let slot = Int(elapsed / WaveTiming.textInterval)
            if slot > lastSavedSlot, slot < WaveTiming.slotsPerWave {
                lastSavedSlot = slot

                let currentText = sttManager.recognizedText
                var newText = ""
                if currentText.count > previousText.count {
                    newText = String(currentText.dropFirst(previousText.count))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                } else if currentText != previousText && !currentText.isEmpty {
                    newText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                }

                if !newText.isEmpty {
                    let textIndex = (progressWave - 1) * WaveTiming.slotsPerWave + slot
                    waveTexts[textIndex] = newText
                }
                previousText = currentText
            }

            if clock.elapsed >= WaveTiming.waveDuration {
                timer.invalidate()
                if progressWave < WaveTiming.waveCount {
                    startRecordingInterval()
                } else {
                    stopRecording()
                }
            }
        }
    }

    /// Wave間のインターバル。終了後に次のWaveの録音を始める
    private func startRecordingInterval() {
        Task { @MainActor in
            ttsManager.speak(appStrings.waveEnd(progressWave))
        }

        clock.reset()
        countdownRemaining = Int(ceil(WaveTiming.interval))
        var lastSpokenSecond = countdownRemaining + 1

        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: WaveTiming.tick, repeats: true) { timer in
            let remaining = max(0, WaveTiming.interval - clock.elapsed)
            countdownRemaining = Int(ceil(remaining))

            let currentSecond = Int(ceil(remaining))
            if currentSecond <= WaveTiming.countdownSpeakFrom,
               currentSecond > 0,
               currentSecond < lastSpokenSecond {
                lastSpokenSecond = currentSecond
                Task { @MainActor in
                    ttsManager.speak("\(currentSecond)")
                }
            }

            if remaining <= 0 {
                timer.invalidate()
                progressWave += 1
                sttManager.recognizedText = ""
                actuallyStartRecording()
            }
        }
    }

    /// 録音中止の要求。中止すると取り消せないため確認を挟む
    /// Wave1〜5のセクション一覧
    @ViewBuilder
    private var waveSections: some View {
        ScrollView {
            VStack(spacing: 12) {
                Spacer()
                    .frame(height: 20)

                ForEach(1...5, id: \.self) { wave in
                    WaveSection(
                        wave: wave,
                        waveTexts: $waveTexts,
                        isExpanded: expandedWaves.contains(wave),
                        onToggleExpand: { toggleWave(wave) },
                        onWaveRecording: isRecording ? nil : { startWaveRecording(wave: $0) }
                    )
                }

                // フローティングボタンに隠れないための余白
                Spacer()
                    .frame(height: 100)
            }
        }
    }

    /// 画面下部の再生・録音ボタン
    /// 録音中・カウントダウン中は表示しない（録音中はオーバーレイ側で操作する）
    @ViewBuilder
    private var floatingButtons: some View {
        // フローティングボタン（画面下部固定）
        if !isRecording && !isWaitingForStart {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    // 再生ボタン
                    Button(action: startPlayback) {
                        HStack(spacing: 10) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 28))
                            Text("再生")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [AppColors.primary, AppColors.primary.opacity(0.8)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(25)
                        .shadow(color: AppColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(isRecording)
                    
                    Spacer()
                        .frame(width: 16)
                    
                    // 録音ボタン
                    Button(action: startRecording) {
                        HStack(spacing: 10) {
                            Image(systemName: "mic.circle.fill")
                                .font(.system(size: 28))
                            Text(isWaitingForStart ? "着地時にタップ" : "録音")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [AppColors.danger, AppColors.danger.opacity(0.8)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(25)
                        .shadow(color: AppColors.danger.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(isPlaying || !sttManager.isAuthorized)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
                .background(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.clear, location: 0),
                            .init(color: AppColors.background.opacity(0.8), location: 0.3),
                            .init(color: AppColors.background, location: 1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 100)
                )
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
        
    }

    private func requestStopRecording() {
        if isRecording {
            showStopConfirmation = true
        } else {
            // カウントダウン中のキャンセルは記録が無いので確認不要
            stopRecording()
        }
    }

    private func stopRecording() {
        isRecording = false
        isWaitingForStart = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        sttManager.stopRecording()
        
        // 最後のWaveのテキストを保存
        if progressWave > 0 && progressWave <= 5 {
            waveTexts[progressWave] = sttManager.recognizedText
            Task { @MainActor in
                ttsManager.speak(appStrings.recordingCompleted)
            }
        }
        
        saveData()
        
        // リセット
        progressWave = 0
        progressSecond = 0
        countdownRemaining = 0
    }
    
    private func setupSTT() {
        sttManager.onTextRecognized = { text in
            // リアルタイムで現在のWaveにテキストを反映
            if progressWave > 0 && progressWave <= 5 {
                waveTexts[progressWave] = text
            }
        }
    }
    
    private func saveData() {
        UserDefaults.standard.set(title, forKey: title)
        if let encoded = try? JSONEncoder().encode(waveTexts) {
            UserDefaults.standard.set(encoded, forKey: title)
        }
    }
    
    /// タイトルの変更を確定する
    /// 空欄のまま確定された場合は元のタイトルに戻す
    private func commitTitleChange() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            title = currentInitialTitle
            return
        }
        guard trimmed != currentInitialTitle else {
            title = trimmed
            return
        }

        title = trimmed
        updateTitleInStorage(from: currentInitialTitle, to: trimmed)
        currentInitialTitle = trimmed
    }

    private func updateTitleInStorage(from oldTitle: String, to newTitle: String) {
        // 1. 既存データを新しいキーで保存
        if let existingData = UserDefaults.standard.data(forKey: oldTitle) {
            UserDefaults.standard.set(existingData, forKey: newTitle)
        }
        
        // 2. 古いキーを削除
        UserDefaults.standard.removeObject(forKey: oldTitle)
        
        // 3. savedTitlesリストを更新
        var savedTitles = UserDefaults.standard.stringArray(forKey: "savedTitles") ?? []
        if let index = savedTitles.firstIndex(of: oldTitle) {
            savedTitles[index] = newTitle
            UserDefaults.standard.set(savedTitles, forKey: "savedTitles")
        }
        
        // 4. 現在のデータも新しいタイトルで保存
        saveData()
        
        print("Title updated from '\(oldTitle)' to '\(newTitle)'")
    }
    
    private func exportData() {
        // Int キーを String に変換
        var stringWaveTexts: [String: String] = [:]
        for (key, value) in waveTexts {
            stringWaveTexts[String(key)] = value
        }
        
        let exportData: [String: Any] = [
            "title": title,
            "version": "1.0",
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "waveTexts": stringWaveTexts
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            let fileName = "\(title.replacingOccurrences(of: " ", with: "_")).json"
            
            // 一時ファイルを作成
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try jsonData.write(to: tempURL)
            
            // 共有アイテム（ファイルとテキスト両方を提供）
            let shareItems: [Any] = [
                tempURL,  // ファイルとして
                jsonString  // テキストとして（LINE等で使用）
            ]
            
            // 共有シートで表示
            let activityVC = UIActivityViewController(activityItems: shareItems, applicationActivities: nil)
            activityVC.excludedActivityTypes = [.assignToContact, .addToReadingList]
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                // iPadの場合のポップオーバー設定
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = rootViewController.view
                    popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
                rootViewController.present(activityVC, animated: true)
            }
        } catch {
            print("Export error: \(error)")
        }
    }
    
    private func handleImportedFile(url: URL) {
        do {
            // ファイルを読み込む
            let jsonData = try Data(contentsOf: url)
            
            // JSONをパース
            guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let importedTitle = json["title"] as? String,
                  let stringWaveTexts = json["waveTexts"] as? [String: String] else {
                importError = "JSONファイルの形式が正しくありません"
                showImportError = true
                return
            }
            
            // String キーを Int に変換
            var intWaveTexts: [Int: String] = [:]
            for (key, value) in stringWaveTexts {
                if let intKey = Int(key) {
                    intWaveTexts[intKey] = value
                }
            }
            
            // インポートしたタイトルには必ず_importを付ける
            var savedTitles = UserDefaults.standard.stringArray(forKey: "savedTitles") ?? []
            var finalTitle = "\(importedTitle)_import"
            
            // 重複する場合は番号を追加
            if savedTitles.contains(finalTitle) {
                var counter = 2
                var candidateTitle = "\(importedTitle)_import\(counter)"
                while savedTitles.contains(candidateTitle) {
                    counter += 1
                    candidateTitle = "\(importedTitle)_import\(counter)"
                }
                finalTitle = candidateTitle
            }
            
            // データを保存
            if let encoded = try? JSONEncoder().encode(intWaveTexts) {
                UserDefaults.standard.set(encoded, forKey: finalTitle)
            }
            
            // タイトルリストに追加
            savedTitles.append(finalTitle)
            UserDefaults.standard.set(savedTitles, forKey: "savedTitles")
            
            // 現在の画面を更新
            title = finalTitle
            waveTexts = intWaveTexts
            
            // タイトルが変更された場合の処理
            if finalTitle != currentInitialTitle {
                updateTitleInStorage(from: currentInitialTitle, to: finalTitle)
                currentInitialTitle = finalTitle
            }
            
            print("インポート成功: \(finalTitle)")
            
        } catch {
            importError = "ファイルの読み込みに失敗しました: \(error.localizedDescription)"
            showImportError = true
        }
    }
}

// MARK: - Wave Section

struct WaveSection: View {
    let wave: Int
    @Binding var waveTexts: [Int: String]
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onWaveRecording: ((Int) -> Void)?
    @EnvironmentObject var appStrings: AppStrings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ヘッダー（高さとボタンサイズ増加）
            HStack(alignment: .center, spacing: 16) {
                Text("Wave \(wave)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Wave別録音ボタン（大きく）
                if let onWaveRecording = onWaveRecording {
                    Button(action: {
                        onWaveRecording(wave)
                    }) {
                        Image(systemName: "mic.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .padding(.all, 8)
                }
                
                // 開くボタン（大きく）
                Button(action: onToggleExpand) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .padding(.all, 8)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .background(AppColors.waveHeader)
            
            // 50個のテキスト入力エリア（展開時）
            if isExpanded {
                VStack(spacing: 10) {
                    ForEach(0..<50, id: \.self) { intervalIndex in
                        WaveIntervalRow(
                            wave: wave,
                            intervalIndex: intervalIndex,
                            waveTexts: $waveTexts
                        )
                    }
                }
                .padding(8)
                .background(AppColors.surface)
            }
        }
        .cornerRadius(12)
        .padding(.horizontal, 12)
    }
}

// MARK: - Wave Interval Row

struct WaveIntervalRow: View {
    let wave: Int
    let intervalIndex: Int
    @Binding var waveTexts: [Int: String]
    
    var textIndex: Int {
        (wave - 1) * 50 + intervalIndex
    }
    
    var timeLabel: String {
        let remainingSeconds = 100 - (intervalIndex * 2)
        return "\(remainingSeconds)秒"
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // 時間ラベル（緑がかった白）
            Text(timeLabel)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(Color(red: 0.9, green: 1.0, blue: 0.9))
                .frame(width: 50, alignment: .trailing)
            
            // テキストフィールド（クリアボタン内蔵）
            ZStack(alignment: .trailing) {
                TextField("", text: Binding(
                    get: { waveTexts[textIndex] ?? "" },
                    set: { waveTexts[textIndex] = $0 }
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 14))
                .frame(height: 36)
                
                // テキストフィールド内のクリアボタン
                if let text = waveTexts[textIndex], !text.isEmpty {
                    Button(action: {
                        waveTexts[textIndex] = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.textSecondary)
                            .font(.system(size: 16))
                    }
                    .padding(.trailing, 8)
                }
            }
        }
    }
}

// MARK: - Recording Overlay

struct RecordingOverlay: View {
    let isWaitingForStart: Bool
    let progressWave: Int
    let progressSecond: Int
    let countdownRemaining: Int
    let onStart: () -> Void
    let onStop: () -> Void
    @EnvironmentObject var appStrings: AppStrings
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                if isWaitingForStart {
                    // カウントダウン表示
                    Text(appStrings.countdownLabel(countdownRemaining))
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(appStrings.tapWhenLanding)
                        .font(.headline)
                        .foregroundColor(AppColors.golden)
                    
                    // 録音開始ボタン（着地時タップ用）
                    Button(action: onStart) {
                        HStack {
                            Image(systemName: "mic.circle.fill")
                                .font(.largeTitle)
                            Text("録音開始")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 20)
                        .background(AppColors.danger)
                        .cornerRadius(30)
                    }
                } else {
                    // 録音中表示
                    Text(appStrings.recording)
                        .font(.title)
                        .foregroundColor(AppColors.danger)
                    
                    Text(appStrings.progressLabel(progressWave, progressSecond))
                        .font(.system(size: 36, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                    
                    // プログレスバー
                    ProgressView(value: Double(progressSecond), total: 100)
                        .progressViewStyle(LinearProgressViewStyle(tint: AppColors.golden))
                        .frame(width: 250)
                }
                
                // 停止ボタン
                Button(action: onStop) {
                    Text(isWaitingForStart ? appStrings.cancel : appStrings.stopRecording)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(AppColors.danger)
                        .cornerRadius(12)
                }
            }
        }
    }
}

#Preview {
    WaveListView(initialTitle: "12月25日")
        .environmentObject(AppStrings.shared)
        .environmentObject(PurchaseManager.shared)
}
