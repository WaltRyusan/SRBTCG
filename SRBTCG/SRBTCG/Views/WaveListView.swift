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
    /// 再生を開始するWave
    @State private var playbackStartWave = 1
    /// 許可の取得など、準備中の表示
    @State private var isPreparingRecording = false
    /// Wave間のインターバル中かどうか
    @State private var isInterval = false

    /// エクスポート/インポートのメニューを出すか
    /// v2で提供予定のため、v1ではfalseにしている
    private static let showsExportMenu = false
    /// 表示中の確認ダイアログ
    @State private var dialog: WaveDialog?
    @State private var isWaitingForStart = false
    @State private var isPlaying = false
    @State private var expandedWaves = Set<Int>()
    @State private var showPlaybackView = false
    
    // 録音関連
    @State private var progressWave = 0
    @State private var progressSecond = 0
    @State private var countdownRemaining = Int(ceil(WaveTiming.initialCountdown))
    @State private var recordingTimer: Timer?
    
    @State private var showMenu = false
    @State private var showDocumentPicker = false
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

            if isPreparingRecording {
                preparingOverlay
            }

            // 録音中オーバーレイ
            if isRecording || isWaitingForStart || isInterval {
                RecordingOverlay(
                    isWaitingForStart: isWaitingForStart,
                    isInterval: isInterval,
                    nextWave: progressWave + 1,
                    progressWave: progressWave,
                    progressSecond: progressSecond,
                    countdownRemaining: countdownRemaining,
                    onStop: requestStopRecording
                )
            }
        }
    }

    var body: some View {
        dialogs(chrome)
    }

    /// 確認ダイアログ
    ///
    /// 以前は用途ごとに .alert を7個チェーンしていたが、
    /// SwiftUIは同じビューに複数のalertを重ねると取りこぼすことがある。
    /// 加えてWave別再生と権限拒否は .alert 自体が無く、
    /// フラグを立てても何も出ないままだった。
    /// 同時に出せるのは1つなので、状態も1つにまとめる。
    private enum WaveDialog: Identifiable {
        case recordingConfirm
        case waveRecordingConfirm(Int)
        case playbackConfirm
        case wavePlaybackConfirm(Int)
        case noText
        case stopConfirm
        case purchaseRequired
        case permissionDenied
        case importError(String)

        var id: String {
            switch self {
            case .recordingConfirm: return "recordingConfirm"
            case .waveRecordingConfirm(let wave): return "waveRecording-\(wave)"
            case .playbackConfirm: return "playbackConfirm"
            case .wavePlaybackConfirm(let wave): return "wavePlayback-\(wave)"
            case .noText: return "noText"
            case .stopConfirm: return "stopConfirm"
            case .purchaseRequired: return "purchaseRequired"
            case .permissionDenied: return "permissionDenied"
            case .importError: return "importError"
            }
        }

        var title: String {
            switch self {
            case .recordingConfirm: return "録音確認"
            case .waveRecordingConfirm(let wave): return "Wave \(wave) から録音"
            case .playbackConfirm: return "再生確認"
            case .wavePlaybackConfirm(let wave): return "Wave \(wave) から再生"
            case .noText: return "テキストなし"
            case .stopConfirm: return "録音を中止しますか？"
            case .purchaseRequired: return "録音機能の購入が必要です"
            case .permissionDenied: return "マイクを使用できません"
            case .importError: return "インポートエラー"
            }
        }

        var message: String {
            switch self {
            case .recordingConfirm:
                return "「録音開始」をタップするとカウントダウンが始まり、0になるとWave1の録音を自動で開始します。"
            case .waveRecordingConfirm(let wave):
                return "Wave \(wave) から録音を開始します。カウントダウンが0になったら自動で録音を始めます。"
            case .playbackConfirm:
                return "地面に着地したタイミングで再生を開始してください。準備ができたら「再生開始」をタップしてください。"
            case .wavePlaybackConfirm(let wave):
                return "Wave \(wave) から再生します。インターバルがズレたときの合流に使ってください。"
            case .noText:
                return "再生するテキストがありません。"
            case .stopConfirm:
                return "ここまでに録音した内容だけが記録されます。中止した時点より後のWaveは記録されません。"
            case .purchaseRequired:
                return "音声を文字にして記録する機能は有料です。設定画面から購入できます。"
            case .permissionDenied:
                return "録音するにはマイクと音声認識の許可が必要です。設定アプリから許可してください。"
            case .importError(let detail):
                return detail
            }
        }
    }

    /// ダイアログ
    /// bodyのmodifierチェーンが長すぎて型チェックが通らないため分けている
    private func dialogs<C: View>(_ base: C) -> some View {
        base.alert(
            dialog?.title ?? "",
            isPresented: Binding(
                get: { dialog != nil },
                set: { if !$0 { dialog = nil } }
            ),
            presenting: dialog,
            actions: { dialogActions(for: $0) },
            message: { Text($0.message) }
        )
    }

    @ViewBuilder
    private func dialogActions(for item: WaveDialog) -> some View {
        switch item {
        case .recordingConfirm:
            Button("キャンセル", role: .cancel) { }
            Button("録音開始") { startRecordingAfterConfirm() }
        case .waveRecordingConfirm(let wave):
            Button("キャンセル", role: .cancel) { }
            Button("録音開始") { startWaveSpecificRecording(from: wave) }
        case .playbackConfirm:
            Button("キャンセル", role: .cancel) { }
            Button("再生開始") { startPlaybackAfterConfirm() }
        case .wavePlaybackConfirm(let wave):
            Button("キャンセル", role: .cancel) { }
            Button("再生開始") {
                playbackStartWave = wave
                showPlaybackView = true
            }
        case .stopConfirm:
            Button("続ける", role: .cancel) { }
            Button("中止する", role: .destructive) { stopRecording() }
        case .noText, .purchaseRequired, .permissionDenied, .importError:
            Button("OK", role: .cancel) { }
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
                    waveTexts: waveTexts,
                    startWave: playbackStartWave
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
    
    /// Waveの開閉
    ///
    /// 展開中のWaveは50行あるため、下までスクロールした状態で閉じると
    /// コンテンツが縮んで画面に何も残らなくなる。
    /// 閉じたときはその見出しの位置までスクロールを戻す。
    private func toggleWave(_ wave: Int, proxy: ScrollViewProxy? = nil) {
        let willCollapse = expandedWaves.contains(wave)

        if willCollapse {
            expandedWaves.remove(wave)
        } else {
            expandedWaves.insert(wave)
        }

        if willCollapse, let proxy {
            // レイアウトが縮んでから移動させる
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(wave, anchor: .top)
                }
            }
        }
    }
    
    
    private func startPlayback() {
        // テキストが存在するかチェック
        let hasAnyText = waveTexts.values.contains { !$0.isEmpty }
        
        dialog = hasAnyText ? .playbackConfirm : .noText
    }
    
    private func startPlaybackAfterConfirm() {
        // 下部の再生ボタンは常に最初から
        playbackStartWave = 1
        showPlaybackView = true
    }
    
    /// 準備中かどうか（許可の取得待ちなど）
    /// 何も表示しないと固まったように見えるため、インジケータを出す
    private var preparingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                Text("準備中...")
                    .foregroundColor(.white)
                    .font(.headline)
            }
        }
    }

    /// 指定Waveから再生する
    /// インターバルの秒数がズレたとき、途中から合流するために使う
    private func startWavePlayback(from wave: Int) {
        let hasText = (0..<WaveTiming.slotsPerWave).contains { slot in
            let index = (wave - 1) * WaveTiming.slotsPerWave + slot
            return !(waveTexts[index] ?? "").isEmpty
        }
        guard hasText else {
            dialog = .noText
            return
        }
        dialog = .wavePlaybackConfirm(wave)
    }

    private func startWaveRecording(wave: Int) {
        Task {
            guard await prepareRecording() else { return }
            dialog = .waveRecordingConfirm(wave)
        }
    }

    private func startWaveSpecificRecording(from wave: Int) {
        // 指定Waveからの録音を開始。
        // カウントダウンが0になったら startCountdownTimer が
        // そのまま actuallyStartRecording を呼ぶ。
        progressWave = wave
        progressSecond = 0
        isWaitingForStart = true

        announce("Wave \(wave)から録音を開始します")
        startCountdownTimer()
    }

    private func startRecording() {
        Task {
            guard await prepareRecording() else { return }
            dialog = .recordingConfirm
        }
    }

    /// 録音前の課金チェックと許可取得
    ///
    /// マイクの許可は audioEngine.start() まで要求されないため、
    /// カウントダウン前に取っておかないとOSダイアログが割り込んで
    /// 開始タイミングがずれる。
    private func prepareRecording() async -> Bool {
        // 未購入のまま無言でreturnしていたため、押しても何も起きなかった
        let hasPurchased = await purchaseManager.hasSttExport()
        guard hasPurchased else {
            dialog = .purchaseRequired
            return false
        }

        isPreparingRecording = true
        let granted = await sttManager.requestPermissions()
        isPreparingRecording = false

        guard granted else {
            dialog = .permissionDenied
            return false
        }
        return true
    }
    
    /// 録音セッション中のときだけ読み上げる
    ///
    /// speakはTaskで1フレーム後に走るため、中止した時点で積まれていた
    /// 読み上げが停止処理の後に実行され、止めたあとも喋り続けていた。
    private func announce(_ text: String) {
        Task { @MainActor in
            guard isRecording || isInterval || isWaitingForStart else { return }
            ttsManager.speak(text)
        }
    }

    private func startRecordingAfterConfirm() {
        // ダイアログ確認後にカウントダウン開始
        isWaitingForStart = true
        countdownRemaining = Int(ceil(WaveTiming.initialCountdown))
        announce(appStrings.startingRecording)
        startCountdownTimer()
    }
    
    /// Wave1開始までのカウントダウン
    /// 0になったらそのまま録音を開始する（着地時の再タップは廃止）
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
                announce("\(currentSecond)")
            }

            if remaining <= 0 {
                timer.invalidate()
                // 中止済みなら何もしない。
                // タイマーを止めても、この発火自体は既に走り始めている。
                guard isWaitingForStart else { return }
                // カウントダウンが終わったらそのまま録音を開始する
                actuallyStartRecording()
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

        announce(appStrings.waveStart(progressWave))

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
                guard isRecording else { return }
                if progressWave < WaveTiming.waveCount {
                    startRecordingInterval()
                } else {
                    stopRecording()
                }
            }
        }
    }

    /// Wave間のインターバル。終了後に次のWaveの録音を始める
    /// Wave間のインターバル
    /// 「次のWave開始まで N秒」を表示し、0になったら次のWaveの録音を自動で開始する
    private func startRecordingInterval() {
        isRecording = false
        isInterval = true

        // インターバル中はマイクを離す。
        // 掴んだままだと次のWaveでオーディオエンジンを二重に初期化することになる。
        sttManager.stopRecording()

        announce(appStrings.waveEnd(progressWave))

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
                announce("\(currentSecond)")
            }

            if remaining <= 0 {
                timer.invalidate()
                guard isInterval else { return }
                isInterval = false
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
        ScrollViewReader { proxy in
            ScrollView {
                // ヘッダーを上部に固定する。
                // 展開したWaveをスクロールしても見出しが残るので、
                // 途中の位置からでも閉じられる。
                LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
                    Spacer()
                        .frame(height: 20)

                    ForEach(1...5, id: \.self) { wave in
                        Section {
                            if expandedWaves.contains(wave) {
                                WaveIntervalList(wave: wave, waveTexts: $waveTexts)
                            }
                        } header: {
                            WaveSectionHeader(
                                wave: wave,
                                isExpanded: expandedWaves.contains(wave),
                                onToggleExpand: { toggleWave(wave, proxy: proxy) },
                                onWaveRecording: isRecording ? nil : { startWaveRecording(wave: $0) },
                                onWavePlayback: isRecording ? nil : { startWavePlayback(from: $0) }
                            )
                            .id(wave)
                        }
                    }

                    // フローティングボタンに隠れないための余白
                    Spacer()
                        .frame(height: 100)
                }
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
        if isRecording || isInterval {
            dialog = .stopConfirm
        } else {
            // カウントダウン中のキャンセルは記録が無いので確認不要
            stopRecording()
        }
    }

    private func stopRecording() {
        let wasRecording = isRecording || isInterval
        isRecording = false
        isInterval = false
        isWaitingForStart = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        sttManager.stopRecording()

        // テキストは録音タイマーが2秒枠ごとに
        // waveTexts[(wave-1)*slotsPerWave + slot] へ書き込んでいる。
        // ここで waveTexts[progressWave] に代入していたが、
        // それは「Wave番号」ではなく「Wave1の1〜5番目の枠」を指すインデックスで、
        // 停止するたびにWave1の冒頭を認識結果全文で上書きしていた。
        if wasRecording {
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
        // 認識結果の保存は録音タイマー側が2秒枠ごとに行う。
        // ここでも waveTexts へ書いていたが、Wave番号を枠インデックスとして
        // 使っていたため認識のたびにWave1の先頭が壊れていた。
        sttManager.onTextRecognized = nil
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
                dialog = .importError("JSONファイルの形式が正しくありません")
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
            dialog = .importError("ファイルの読み込みに失敗しました: \(error.localizedDescription)")
        }
    }
}

// MARK: - Wave Section

/// Waveの見出し。スクロール中も上部に固定される
struct WaveSectionHeader: View {
    let wave: Int
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onWaveRecording: ((Int) -> Void)?
    /// このWaveから再生する
    let onWavePlayback: ((Int) -> Void)?
    @EnvironmentObject var appStrings: AppStrings

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Text("Wave \(wave)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
                // ボタンが増えて幅が足りなくなると折り返してしまうため固定する
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Spacer()

            // このWaveから再生
            // インターバルの秒数がズレたとき、途中から復帰するために使う
            if let onWavePlayback = onWavePlayback {
                Button(action: { onWavePlayback(wave) }) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(AppColors.golden)
                }
                .buttonStyle(.plain)
                .padding(.all, 6)
            }

            // Wave別録音ボタン
            if let onWaveRecording = onWaveRecording {
                Button(action: { onWaveRecording(wave) }) {
                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .padding(.all, 6)
            }

            // 開閉ボタン
            Button(action: onToggleExpand) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .padding(.all, 6)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        // 固定表示中に後ろのテキストが透けないよう不透明にする
        .background(AppColors.waveHeader)
    }
}

/// Wave内のインターバル一覧
struct WaveIntervalList: View {
    let wave: Int
    @Binding var waveTexts: [Int: String]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(0..<WaveTiming.slotsPerWave, id: \.self) { intervalIndex in
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
    /// Wave間のインターバル中かどうか
    var isInterval: Bool = false
    /// インターバル明けに始まるWave
    var nextWave: Int = 1
    let progressWave: Int
    let progressSecond: Int
    let countdownRemaining: Int
    let onStop: () -> Void
    @EnvironmentObject var appStrings: AppStrings
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                if isInterval {
                    // Wave間のインターバル
                    Text("Wave \(progressWave) 終了")
                        .font(.title2)
                        .foregroundColor(AppColors.golden)

                    Text("次のWave \(nextWave) 開始まで")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("\(countdownRemaining)秒")
                        .font(.system(size: 64, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)

                    Text("0になると自動で録音を再開します")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                } else if isWaitingForStart {
                    // カウントダウン表示
                    Text(appStrings.countdownLabel(countdownRemaining))
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                    
                    // カウントダウンが0になると自動で録音が始まる。
                    // 以前は着地時にもう一度タップさせていたが、
                    // 「録音」を押した後にまた「録音開始」が出て分かりにくかったため廃止した。
                    Text("0になると自動で録音を開始します")
                        .font(.headline)
                        .foregroundColor(AppColors.golden)
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
