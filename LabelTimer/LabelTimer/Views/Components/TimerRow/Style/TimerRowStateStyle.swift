import SwiftUI

//
//  TimerRowStateStyle.swift
//  LabelTimer
//
//  Created by 이소연 on 7/24/25.
//
/// 타이머 상태에 따라 배경색, 텍스트 색상을 설정하는 ViewModifier
///
/// - 사용 목적: 실행 중, 일시정지, 정지 등의 상태에 따라 TimerRowView에 일관된 스타일을 적용

struct TimerRowStateStyle: ViewModifier {
    let state: TimerInteractionState

    var labelFont: Font {
        .headline
    }
    
    var timeFont: Font {
        switch state {
        case .waiting:
            return .system(size: 44, weight: .light)
        case .running:
            return .system(size: 44, weight: .semibold)
        case .paused:
            return .system(size: 44, weight: .semibold)
        case .stopped:
            return .system(size: 44, weight: .semibold)
        }
    }
    
    private var textColor: Color {
        switch state {
        case .waiting:
            return .white
        case .running:
            return .black
        case .paused, .stopped:
            return .gray
        }
    }
    
    private var backgroundColor: Color {
        switch state {
        case .waiting:
            return .black
        case .running, .paused:
            return .white
        case .stopped:
            return Color(.systemGray6)
        }
    }

    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
            )
            .foregroundColor(textColor)
    }

    
}

extension View {
    /// 타이머 상태에 따라 배경색/텍스트 색상을 적용하는 Modifier
    func timerRowStateStyle(for state: TimerInteractionState) -> some View {
        self.modifier(TimerRowStateStyle(state: state))
    }
}
