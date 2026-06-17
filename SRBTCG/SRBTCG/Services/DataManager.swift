//
//  DataManager.swift
//  SRBTCG
//
//  データエクスポート/インポート管理
//

import SwiftUI
import UniformTypeIdentifiers
import Combine

/// データ管理クラス
class DataManager: ObservableObject {
    static let shared = DataManager()
    
    private init() {}
    
    // MARK: - Export
    
    /// 全データをエクスポート
    func exportAllData() -> URL? {
        let titles = UserDefaults.standard.stringArray(forKey: "savedTitles") ?? []
        
        guard !titles.isEmpty else {
            print("No data to export")
            return nil
        }
        
        var exportData: [String: Any] = [
            "version": "1.0",
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "titles": titles,
            "data": [:]
        ]
        
        var dataDict: [String: Any] = [:]
        for title in titles {
            if let waveData = UserDefaults.standard.data(forKey: title),
               let waveTexts = try? JSONDecoder().decode([Int: String].self, from: waveData) {
                dataDict[title] = waveTexts
            }
        }
        exportData["data"] = dataDict
        
        // JSONファイルとして保存
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
            let fileName = "SRBTCG_Export_\(Date().timeIntervalSince1970).json"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try jsonData.write(to: tempURL)
            return tempURL
        } catch {
            print("Failed to export data: \(error)")
            return nil
        }
    }
    
    // MARK: - Import
    
    /// データをインポート
    func importData(from url: URL) -> (success: Bool, count: Int, error: String?) {
        do {
            let jsonData = try Data(contentsOf: url)
            guard let importData = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let titles = importData["titles"] as? [String],
                  let dataDict = importData["data"] as? [String: Any] else {
                return (false, 0, "無効なデータ形式です")
            }
            
            // 既存のタイトルリストを取得
            var existingTitles = UserDefaults.standard.stringArray(forKey: "savedTitles") ?? []
            var importedCount = 0
            
            for title in titles {
                // 重複チェック
                var finalTitle = title
                var counter = 2
                while existingTitles.contains(finalTitle) {
                    finalTitle = "\(title)_import_\(counter)"
                    counter += 1
                }
                
                // データを保存
                if let waveTexts = dataDict[title] as? [String: Any] {
                    if let jsonData = try? JSONSerialization.data(withJSONObject: waveTexts) {
                        UserDefaults.standard.set(jsonData, forKey: finalTitle)
                        existingTitles.append(finalTitle)
                        importedCount += 1
                    }
                }
            }
            
            // タイトルリストを更新
            UserDefaults.standard.set(existingTitles, forKey: "savedTitles")
            
            return (true, importedCount, nil)
        } catch {
            return (false, 0, "データの読み込みに失敗しました: \(error.localizedDescription)")
        }
    }
}

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    let onCancel: () -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        let onCancel: () -> Void
        
        init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let completion: (() -> Void)?
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, _, _, _ in
            completion?()
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}