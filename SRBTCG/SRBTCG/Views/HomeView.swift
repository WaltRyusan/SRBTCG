//
//  HomeView.swift
//  SRBTCG
//
//  メイン画面: BottomNavigationBar で バチコン / サーモンランガイド を切り替え
//

import SwiftUI

struct HomeView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var appStrings: AppStrings
    
    var body: some View {
        TabView(selection: $selectedTab) {
            MainView()
                .tabItem {
                    Image(systemName: "trophy.fill")
                }
                .tag(0)
            
            SalmonRunGuideView()
                .tabItem {
                    Image(systemName: "fish.fill")
                }
                .tag(1)
        }
        .tint(AppColors.primary) // アクティブ色をオレンジに設定
    }
}

struct GlassTabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        // 選択時の光るエフェクト
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        AppColors.primary.opacity(0.4),
                                        AppColors.primary.opacity(0.1),
                                        Color.clear
                                    ]),
                                    center: .center,
                                    startRadius: 5,
                                    endRadius: 25
                                )
                            )
                            .frame(width: 50, height: 50)
                            .blur(radius: 5)
                    }
                    
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? AppColors.primary : AppColors.textSecondary)
                        .scaleEffect(isSelected ? 1.15 : 1.0)
                        .animation(.spring(response: 0.3), value: isSelected)
                }
                
                if !label.isEmpty {
                    Text(label)
                        .font(.caption)
                        .foregroundColor(isSelected ? AppColors.primary : AppColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                ZStack {
                    if isSelected {
                        // リキッドグラス効果
                        RoundedRectangle(cornerRadius: 18)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                AppColors.primary.opacity(0.15),
                                                AppColors.primary.opacity(0.05)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                        
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        AppColors.primary.opacity(0.5),
                                        AppColors.primary.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    }
                }
            )
            .scaleEffect(isPressed ? 0.92 : 1)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

#Preview {
    HomeView()
        .environmentObject(AppStrings.shared)
}