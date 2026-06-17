//
//  LanguageSelectView.swift
//  SRBTCG
//
//  言語選択画面
//

import SwiftUI

struct LanguageSelectView: View {
    @EnvironmentObject var appStrings: AppStrings
    @State private var selectedLanguage: AppLanguage = .en
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Text("Select Language")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.top, 40)
                    
                    Text("言語を選択してください")
                        .font(.headline)
                        .foregroundColor(AppColors.textSecondary)
                    
                    VStack(spacing: 16) {
                        ForEach(AppLanguage.allCases, id: \.self) { language in
                            LanguageButton(
                                language: language,
                                isSelected: selectedLanguage == language,
                                action: {
                                    selectedLanguage = language
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    Button(action: confirmLanguage) {
                        Text("Continue")
                            .font(.headline)
                            .foregroundColor(AppColors.buttonText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(AppColors.buttonPrimary)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
    }
    
    private func confirmLanguage() {
        appStrings.saveLanguage(selectedLanguage)
        appStrings.needsLanguageSelection = false
    }
}

struct LanguageButton: View {
    let language: AppLanguage
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(language.displayName)
                    .font(.title3)
                    .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.primary)
                        .font(.system(size: 24))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AppColors.primary.opacity(0.1) : AppColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppColors.primary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    LanguageSelectView()
        .environmentObject(AppStrings.shared)
}