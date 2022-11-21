//
//  File.swift
//  
//
//  Created by Christian Beer on 20.11.22.
//

import Foundation
import SwiftUI
import GSPlayer
import CoreMedia

#if os(macOS)
extension VideoPlayer: NSViewRepresentable {
    
    public func makeNSView(context: Context) -> VideoPlayerView {
        let view = VideoPlayerView()
        
        view.playToEndTime = {
            if self.config.autoReplay == false {
                self.play = false
            }
            DispatchQueue.main.async { self.config.handler.onPlayToEndTime?() }
        }
        
        view.contentMode = config.contentMode
        
        view.replay = {
            DispatchQueue.main.async { self.config.handler.onReplay?() }
        }
        
        view.stateDidChanged = { [unowned view] _ in
            let state: State = view.convertState()
            
            if case .playing = state {
                context.coordinator.startObserver(view: view)
            } else {
                context.coordinator.stopObserver(view: view)
            }
            
            DispatchQueue.main.async { self.config.handler.onStateChanged?(state) }
        }
        
        return view
    }
    
    public func updateNSView(_ view: VideoPlayerView, context: Context) {
        if context.coordinator.observingURL != url {
            context.coordinator.stopObserver(view: view)
            context.coordinator.observerTime = nil
            context.coordinator.observerBuffer = nil
            context.coordinator.observingURL = url
        }
        
        play ? view.play(for: url) : view.pause(reason: .userInteraction)
        view.isMuted = config.mute
        view.isAutoReplay = config.autoReplay
        
        if let observerTime = context.coordinator.observerTime, time != observerTime {
            view.seek(to: time, toleranceBefore: time, toleranceAfter: time, completion: { _ in })
        }
    }
    
#if os(macOS)
#else
    public static func dismantleUIView(_ uiView: VideoPlayerView, coordinator: VideoPlayer.Coordinator) {
        uiView.pause(reason: .hidden)
    }
#endif

}

private extension VideoPlayerView {
    
    func convertState() -> VideoPlayer.State {
        switch state {
        case .none, .loading:
            return .loading
        case .playing:
            return .playing(totalDuration: totalDuration)
        case .paused(let p, let b):
            return .paused(playProgress: p, bufferProgress: b)
        case .error(let error):
            return .error(error)
        }
    }
}

#endif
