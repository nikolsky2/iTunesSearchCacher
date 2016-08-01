//
//  AudioPlayer.swift
//  iTunesSearchCacher
//
//  Created by Sergey Nikolsky on 1/08/2016.
//  Copyright © 2016 happyTuna. All rights reserved.
//

import Foundation
import AVFoundation

protocol AudioPlayerPlayerDelegate: class {
    func audioPlayerDidFinishPlaying(player: AudioPlayer)
}

class AudioPlayer: NSObject {
    
    weak var delegate: AudioPlayerPlayerDelegate?
    private var player: AVAudioPlayer?
    
    override init() {
        do {
            let mySession = AVAudioSession.sharedInstance()
            try mySession.setCategory(AVAudioSessionCategoryPlayback,
                                      withOptions: [.InterruptSpokenAudioAndMixWithOthers, .DuckOthers])
        } catch {
            print(error)
        }
        super.init()
    }
    
    func play() {
        player?.play()
    }
    
    func play(data: NSData) {
        stop()
        
        do {
            player = try AVAudioPlayer.init(data: data)
            player!.delegate = self
        } catch {
            print(error)
        }

        player!.prepareToPlay()
        player!.play()
    }
    
    func stop() {
        player?.stop()
    }
    
    func pause() {
        player?.pause()
    }
}

extension AudioPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(player: AVAudioPlayer, successfully flag: Bool) {
        delegate?.audioPlayerDidFinishPlaying(self)
    }
}