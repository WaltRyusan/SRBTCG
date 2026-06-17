//
//  SphericalButton.swift
//  SRBTCG
//
//  共通の球体ボタンコンポーネント
//

import SwiftUI

struct SphericalButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // 外側の影（深さを演出）
                Circle()
                    .fill(color.opacity(0.3))
                    .frame(width: 64, height: 64)
                    .blur(radius: 4)
                    .offset(y: 4)
                
                // メインの球体
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                color,
                                color.opacity(0.9),
                                Color(red: min(color.components.red * 1.2, 1.0), 
                                      green: min(color.components.green * 1.2, 1.0), 
                                      blue: min(color.components.blue * 1.2, 1.0))
                            ]),
                            center: .topLeading,
                            startRadius: 5,
                            endRadius: 40
                        )
                    )
                    .frame(width: 60, height: 60)
                
                // ハイライト（球体感）
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.6),
                                Color.clear
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .offset(x: -5, y: -5)
                
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppColors.background)
            }
            .shadow(color: color.opacity(0.5), radius: 12, x: 0, y: 6)
        }
    }
}

// Color extensionを追加して色の成分を取得
extension Color {
    var components: (red: CGFloat, green: CGFloat, blue: CGFloat, opacity: CGFloat) {
        guard let components = UIColor(self).cgColor.components else {
            return (0, 0, 0, 0)
        }
        
        if components.count == 2 {
            return (components[0], components[0], components[0], components[1])
        } else if components.count >= 3 {
            return (components[0], components[1], components[2], components.count > 3 ? components[3] : 1)
        }
        
        return (0, 0, 0, 0)
    }
}