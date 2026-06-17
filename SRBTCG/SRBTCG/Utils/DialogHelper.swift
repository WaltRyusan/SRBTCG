//
//  DialogHelper.swift
//  SRBTCG
//
//  共通ダイアログユーティリティ
//

import SwiftUI

/// 共通ダイアログユーティリティ
struct DialogHelper {
    
    /// 停止確認ダイアログビュー修飾子
    struct StopConfirmationModifier: ViewModifier {
        @Binding var isPresented: Bool
        let isRecording: Bool
        let onConfirm: () -> Void
        @EnvironmentObject var appStrings: AppStrings
        
        func body(content: Content) -> some View {
            content
                .alert(
                    isRecording ? appStrings.stopRecordingTitle : appStrings.stopPlaybackTitle,
                    isPresented: $isPresented
                ) {
                    Button(appStrings.cancel, role: .cancel) { }
                    Button(
                        isRecording ? appStrings.stopRecording : appStrings.stopPlayback,
                        role: .destructive,
                        action: onConfirm
                    )
                } message: {
                    Text(isRecording ? appStrings.stopRecordingMessage : appStrings.stopPlaybackMessage)
                }
        }
    }
    
    /// 汎用確認ダイアログビュー修飾子
    struct ConfirmationModifier: ViewModifier {
        @Binding var isPresented: Bool
        let title: String
        let message: String
        let confirmText: String
        let confirmRole: ButtonRole?
        let onConfirm: () -> Void
        @EnvironmentObject var appStrings: AppStrings
        
        func body(content: Content) -> some View {
            content
                .alert(title, isPresented: $isPresented) {
                    Button(appStrings.cancel, role: .cancel) { }
                    Button(confirmText, role: confirmRole, action: onConfirm)
                } message: {
                    Text(message)
                }
        }
    }
    
    /// コピー確認ダイアログ（今後表示しないオプション付き）
    struct CopyConfirmationView: View {
        let itemName: String
        let onConfirm: (Bool) -> Void
        let onCancel: () -> Void
        
        @State private var dontAskAgain = false
        @AppStorage("skipCopyConfirmation") private var skipCopyConfirmation = false
        @EnvironmentObject var appStrings: AppStrings
        
        var body: some View {
            VStack(spacing: 20) {
                Text("コピー確認")
                    .font(.headline)
                
                Text("「\(itemName)」をコピーしますか？")
                    .multilineTextAlignment(.center)
                
                HStack {
                    Toggle(isOn: $dontAskAgain) {
                        Text("今後このダイアログを表示しない")
                            .font(.caption)
                    }
                    .toggleStyle(CheckboxToggleStyle())
                }
                
                HStack(spacing: 20) {
                    Button(appStrings.cancel) {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("コピー") {
                        if dontAskAgain {
                            skipCopyConfirmation = true
                        }
                        onConfirm(dontAskAgain)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(AppColors.surface)
            .cornerRadius(12)
            .shadow(radius: 10)
        }
    }
}

// MARK: - View Extension

extension View {
    /// 停止確認ダイアログ
    func stopConfirmationDialog(
        isPresented: Binding<Bool>,
        isRecording: Bool,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(DialogHelper.StopConfirmationModifier(
            isPresented: isPresented,
            isRecording: isRecording,
            onConfirm: onConfirm
        ))
    }
    
    /// 汎用確認ダイアログ
    func confirmationDialog(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        confirmText: String,
        confirmRole: ButtonRole? = nil,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(DialogHelper.ConfirmationModifier(
            isPresented: isPresented,
            title: title,
            message: message,
            confirmText: confirmText,
            confirmRole: confirmRole,
            onConfirm: onConfirm
        ))
    }
}

// MARK: - Checkbox Toggle Style

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }) {
            HStack {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundColor(configuration.isOn ? AppColors.primary : AppColors.textSecondary)
                configuration.label
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}