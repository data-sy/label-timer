//
//  AlarmPlayer.swift
//  LabelTimer
//
//  Created by 이소연 on 7/25/25.
//
/// 앱 내 알람(소리, 진동) 재생을 전담하는 오디오 핸들러
///
/// - 기능: 커스텀 사운드 반복 재생, 연속적인 시스템 진동 생성, ID 기반의 개별 알람 제어(시작/정지)

import Foundation
import AVFoundation
import AudioToolbox

/// 오디오 재생의 반복 방식을 정의하는 Enum
/// - 사용 목적: -1, 0과 같은 숫자(Magic Number) 대신 .infinite, .once처럼 의미가 명확한 타입으로 재생 방식을 지정하고 실수를 방지하기 위함
/// ### `player.numberOfLoops` 프로퍼티 참고
/// - **0 (기본값):** 반복 없이 총 1회만 재생
/// - **양수(n):** 기본 재생 후 n번 더 반복하여 총 n+1회 재생 (예: 1을 입력하면 총 2회 재생)
/// - **-1:** stop() 메서드가 호출될 때까지 무한 반복
enum RepeatMode {
    case once
    case `repeat`(times: Int)
    case infinite
    
    /// AVAudioPlayer의 numberOfLoops 프로퍼티에 할당할 Int 값 계산
    var loopValue: Int {
        switch self {
        case .once:
            return 0
        case .repeat(let times):
            return max(0, times - 1)
        case .infinite:
            return -1
        }
    }
}

@available(*, deprecated, message: "이제 로컬 알림을 사용하므로 앱 내 알람 재생 로직은 더 이상 사용되지 않습니다. '무음 사운드' 트릭 등 잠재적인 활용을 위해 코드를 남겨둡니다.")
protocol AlarmPlayable {
    func playCustomSound(for id: UUID, sound: AlarmSound, repeatMode: RepeatMode)
    func playContinuousVibration(for id: UUID)
    func playSystemSound()
    func playSingleVibration()
    func stop(for id: UUID)
    func stopAll()
}

@available(*, deprecated, message: "이제 로컬 알림을 사용하므로 앱 내 알람 재생 로직은 더 이상 사용되지 않습니다. '무음 사운드' 트릭 등 잠재적인 활용을 위해 코드를 남겨둡니다.")
final class AlarmPlayer: AlarmPlayable {
    static let shared = AlarmPlayer()

    private var players: [UUID: AVAudioPlayer] = [:]
    private var feedbackPlayers: [UUID: AVAudioPlayer] = [:]
    private var vibrationTimers: [UUID: Timer] = [:]
    private var autoStopTasks: [UUID: DispatchWorkItem] = [:]
    private let autoStopInterval: TimeInterval = 900 // 15분 (900초)
    
    // 싱글톤 패턴을 위한 기본 private init
    private init() {}
    
    // MARK: - Public Play Sound Methods

    /// 커스텀 알람(소리/진동) 재생
    func playCustomSound(for id: UUID, sound: AlarmSound, repeatMode: RepeatMode = .infinite) {
        func ts() -> String { ISO8601DateFormatter().string(from: Date()) }
        print("[\(ts())][AlarmPlayer][play] id=\(id.uuidString) sound=\(sound)")

        // 재생할 URL을 요청했을 때 없다면(기본 사운드도 없다면) 종료
        guard let finalUrl = sound.playableURL else {
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: finalUrl)
            player.numberOfLoops = repeatMode.loopValue
            
            if player.play() {
                players[id] = player
                print("[\(ts())][AlarmPlayer][play] AVAudioPlayer started=true")
                if case .infinite = repeatMode {
                    let task = schedule(after: autoStopInterval) { [weak self] in
                        print("⏰ 15분이 지나 알람을 자동으로 끕니다: \(id)")
                        self?.stop(for: id)
                    }
                    autoStopTasks[id] = task
                }
            } else {
                print("[\(ts())][AlarmPlayer][play] AVAudioPlayer started=false. Playback failed.")
            }
        } catch {
            print("[\(ts())][AlarmPlayer][play][ERROR] 플레이어 초기화 실패: \(error)")
        }
    }
    
    /// 시스템 사운드 재생
    /// - 실제 iOS 시스템 사운드가 아님
    /// - 앱 번들에 포함된 짧은 음원을 재생해 시스템 사운드와 유사한 효과를 냄
    func playSystemSound() {
        // TODO: .feedback 음원 추가 시 교체
        let feedbackSound: AlarmSound = .lowBuzz
        
        guard let url = Bundle.main.url(forResource: feedbackSound.fileName, withExtension: feedbackSound.fileExtension) else {
            print("[AlarmPlayer][playSystemSound] 피드백 사운드 파일을 찾을 수 없습니다.")
            return
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = 0
            player.play()
            
            let tempID = UUID()
            feedbackPlayers[tempID] = player
            
            DispatchQueue.main.asyncAfter(deadline: .now() + player.duration) { [weak self] in
                self?.feedbackPlayers.removeValue(forKey: tempID)
            }
        } catch {
            print("[AlarmPlayer][playSystemSound] 피드백 플레이어 생성 실패: \(error)")
        }
    }
    
    // MARK: - Public Vibration Methods

    // 연속 진동 재생
    func playContinuousVibration(for id: UUID) {
        guard vibrationTimers[id] == nil else { return } // 이미 진동 중이면 중복
        
        // n초마다 진동을 실행하는 타이머 생성
        let timer = Timer.scheduledTimer(withTimeInterval: 1.7, repeats: true) { _ in
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
        vibrationTimers[id] = timer
    }
    
    /// 1회성 진동 재생
    func playSingleVibration() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
    
    // MARK: - Stop Methods

    /// 특정 타이머의 알람(소리/진동) 정지
    func stop(for id: UUID) {
        if let task = autoStopTasks.removeValue(forKey: id) {
            cancel(task: task)
            print("🚫 '자동 끄기' 예약을 취소합니다: \(id)")
        }
        // 사운드 정지
        players[id]?.stop()
        players.removeValue(forKey: id)
        // 진동 타이머 정지
        stopVibration(for: id)
    }

    /// 모든 타이머의 알람(소리/진동) 정지
    func stopAll() {
        autoStopTasks.values.forEach { cancel(task: $0) }
        autoStopTasks.removeAll()
        print("🚫 모든 '자동 끄기' 예약을 취소합니다.")
        // 모든 사운드 정지
        players.values.forEach { $0.stop() }
        players.removeAll()
        // 모든 진동 타이머 정지
        vibrationTimers.values.forEach { $0.invalidate() }
        vibrationTimers.removeAll()
    }

    // MARK: - Private Vibration Helpers
    
    /// 진동을 멈추는 private 함수
    private func stopVibration(for id: UUID) {
        vibrationTimers[id]?.invalidate() // 타이머 무효화
        vibrationTimers.removeValue(forKey: id)
    }
}
