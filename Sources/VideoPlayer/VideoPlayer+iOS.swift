//
//  VideoPlayer+iOS.swift
//  
//
//  Created by Christian Beer on 20.11.22.
//

import SwiftUI
import Foundation
import GSPlayer

#if os(iOS)
extension VideoPlayer: UIViewRepresentable {
    
    public func makeUIView(context: Context) -> VideoPlayerView {
        let uiView = VideoPlayerView()
        
        uiView.playToEndTime = {
            if self.config.autoReplay == false {
                self.play = false
            }
            DispatchQueue.main.async { self.config.handler.onPlayToEndTime?() }
        }
        
        uiView.videoContentMode = config.contentMode
        
        uiView.replay = {
            DispatchQueue.main.async { self.config.handler.onReplay?() }
        }
        
        uiView.stateDidChanged = { [unowned uiView] _ in
            let state: State = uiView.convertState()
            
            if case .playing = state {
                context.coordinator.startObserver(view: uiView)
            } else {
                context.coordinator.stopObserver(view: uiView)
            }
            
            DispatchQueue.main.async { self.config.handler.onStateChanged?(state) }
        }
        
        return uiView
    }
    
    public func updateUIView(_ uiView: VideoPlayerView, context: Context) {
        if context.coordinator.observingURL != url {
            context.coordinator.stopObserver(view: uiView)
            context.coordinator.observerTime = nil
            context.coordinator.observerBuffer = nil
            context.coordinator.observingURL = url
        }
        
        play ? uiView.play(for: url) : uiView.pause(reason: .userInteraction)
        uiView.isMuted = config.mute
        uiView.isAutoReplay = config.autoReplay
        
        if let observerTime = context.coordinator.observerTime, time != observerTime {
            uiView.seek(to: time, toleranceBefore: time, toleranceAfter: time, completion: { _ in })
        }
    }
    
    public static func dismantleUIView(_ uiView: VideoPlayerView, coordinator: VideoPlayer.Coordinator) {
        uiView.pause(reason: .hidden)
    }
    
}

#endif
