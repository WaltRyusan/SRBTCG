//
//  LiquidGlassEffects.swift
//  SRBTCG
//
//  リキッドグラスデザインエフェクト
//

import SwiftUI

// MARK: - Glass Morphism View Modifier

struct GlassMorphismModifier: ViewModifier {
    let cornerRadius: CGFloat
    let blurRadius: CGFloat
    let saturation: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // ベースグラス効果
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                    
                    // グラデーション効果
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.25),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .cornerRadius(cornerRadius)
                    
                    // ボーダーライト
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.6),
                                    Color.white.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
            )
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            .shadow(color: AppColors.primary.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Liquid Animation Effect

struct LiquidShapeView: View {
    @State private var offset1: CGSize = .zero
    @State private var offset2: CGSize = .zero
    @State private var offset3: CGSize = .zero
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            // 複数の流体形状
            LiquidBlob(offset: offset1, color: AppColors.primary.opacity(0.3))
                .rotationEffect(.degrees(rotation))
            
            LiquidBlob(offset: offset2, color: AppColors.accent.opacity(0.3))
                .rotationEffect(.degrees(rotation + 120))
            
            LiquidBlob(offset: offset3, color: AppColors.golden.opacity(0.3))
                .rotationEffect(.degrees(rotation + 240))
        }
        .blur(radius: 30)
        .onAppear {
            // 流体アニメーション
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                offset1 = CGSize(width: 50, height: -30)
                offset2 = CGSize(width: -30, height: 50)
                offset3 = CGSize(width: -50, height: -50)
            }
            
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

struct LiquidBlob: View {
    let offset: CGSize
    let color: Color
    
    var body: some View {
        Ellipse()
            .fill(color)
            .frame(width: 200, height: 200)
            .offset(offset)
            .scaleEffect(CGFloat.random(in: 0.8...1.2))
    }
}

// MARK: - Animated Gradient Background

struct AnimatedGradientBackground: View {
    @State private var animateGradient = false
    
    var body: some View {
        LinearGradient(
            colors: [
                AppColors.background,
                AppColors.surface.opacity(0.8),
                AppColors.primary.opacity(0.2),
                AppColors.accent.opacity(0.2),
                AppColors.background
            ],
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}

// MARK: - Neumorphic Button Style

struct NeumorphicButtonStyle: ButtonStyle {
    @State private var isPressed = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(
                ZStack {
                    if configuration.isPressed {
                        // 押下時の内側シャドウ
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppColors.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(AppColors.background, lineWidth: 4)
                                    .blur(radius: 4)
                                    .offset(x: 2, y: 2)
                                    .mask(RoundedRectangle(cornerRadius: 16).fill(LinearGradient(.black, .clear)))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 4)
                                    .blur(radius: 4)
                                    .offset(x: -2, y: -2)
                                    .mask(RoundedRectangle(cornerRadius: 16).fill(LinearGradient(.clear, .black)))
                            )
                    } else {
                        // 通常時の浮き出し効果
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        AppColors.surface.opacity(0.9),
                                        AppColors.surface
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 5, y: 5)
                            .shadow(color: .white.opacity(0.05), radius: 10, x: -5, y: -5)
                    }
                }
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Floating Action Button

struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    @State private var isFloating = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // 背景の流体効果
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColors.primary,
                                AppColors.primary.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // グラスエフェクト
                Circle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.3)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
            }
            .frame(width: 56, height: 56)
            .shadow(color: AppColors.primary.opacity(0.4), radius: 20, x: 0, y: 10)
            .offset(y: isFloating ? -10 : 0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                isFloating = true
            }
        }
    }
}

// MARK: - Wave Animation View

struct WaveAnimationView: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let midHeight = height * 0.5
                let wavelength = width / 2
                
                path.move(to: CGPoint(x: 0, y: midHeight))
                
                for x in stride(from: 0, to: width, by: 1) {
                    let relativeX = x / wavelength
                    let y = sin(relativeX * .pi * 2 + phase) * 20 + midHeight
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                
                path.addLine(to: CGPoint(x: width, y: height))
                path.addLine(to: CGPoint(x: 0, y: height))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [
                        AppColors.primary.opacity(0.3),
                        AppColors.primary.opacity(0.1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - Extensions

extension View {
    func glassMorphism(cornerRadius: CGFloat = 20, blurRadius: CGFloat = 10, saturation: CGFloat = 1.5) -> some View {
        modifier(GlassMorphismModifier(cornerRadius: cornerRadius, blurRadius: blurRadius, saturation: saturation))
    }
    
    func liquidGlassCard() -> some View {
        self
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.5),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    func shimmer() -> some View {
        self.overlay(
            GeometryReader { geometry in
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.white.opacity(0.5),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geometry.size.width * 0.3)
                .offset(x: -geometry.size.width * 0.3)
                .animation(
                    .linear(duration: 2)
                        .repeatForever(autoreverses: false),
                    value: true
                )
            }
            .mask(self)
        )
    }
}

// MARK: - LinearGradient Convenience Init

extension LinearGradient {
    init(_ firstColor: Color, _ secondColor: Color) {
        self.init(colors: [firstColor, secondColor], startPoint: .leading, endPoint: .trailing)
    }
}