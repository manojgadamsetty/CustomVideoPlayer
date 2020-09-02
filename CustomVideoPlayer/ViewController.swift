//
//  ViewController.swift
//  CustomVideoPlayer
//
//  Created by Manoj Gadamsetty on 17/06/20.
//  Copyright © 2020 Manoj Gadamsetty. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    var player : Player = {
        let playeView = CustomPlayerView()
        let playe = Player(playerView: playeView)
        let pl = Player(playeView)
        return playe
    }()
    var url : URL?
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //        self.url = URL(string: "http://download.3g.joy.cn/video/236/60236853/1450837945724_hd.mp4")
//        if  let srt = Bundle.main.url(forResource: "Despacito Remix Luis Fonsi ft.Daddy Yankee Justin Bieber Lyrics [Spanish]", withExtension: "srt") {
//            let playerView = self.player.displayView as! CustomPlayerView
//            playerView.setSubtitles(Subtitles(filePath: srt))
//        }
        let url = URL(fileURLWithPath: Bundle.main.path(forResource: "2", ofType: "mp4")!)
        self.player.replaceVideo(url)
        view.addSubview(self.player.displayView)
        self.player.play()
        self.player.backgroundMode = .suspend
        self.player.delegate = self
        self.player.displayView.delegate = self
        self.player.displayView.snp.makeConstraints { [weak self] (make) in
            guard let strongSelf = self else { return }
            make.top.equalTo(strongSelf.view.snp.top)
            make.left.equalTo(strongSelf.view.snp.left)
            make.right.equalTo(strongSelf.view.snp.right)
            make.height.equalTo(strongSelf.view.snp.width).multipliedBy(9.0/16.0) // you can 9.0/16.0
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: true)
        UIApplication.shared.setStatusBarStyle(UIStatusBarStyle.lightContent, animated: false)
        self.player.play()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        UIApplication.shared.setStatusBarStyle(UIStatusBarStyle.default, animated: false)
        UIApplication.shared.setStatusBarHidden(false, with: .none)
        self.player.pause()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func changeMedia(_ sender: Any) {
        player.replaceVideo(url!)
        player.play()
    }
}

extension ViewController: PlayerDelegate {
    func Player(_ player: Player, playerFailed error: PlayerError) {
        print(error)
    }
    func Player(_ player: Player, stateDidChange state: PlayerState) {
        print("player State ",state)
    }
    func Player(_ player: Player, bufferStateDidChange state: PlayerBufferstate) {
        print("buffer State", state)
    }
    
}

extension ViewController:PlayerViewDelegate {
    
    
    func PlayerView(_ playerView: PlayerView, willFullscreen fullscreen: Bool) {
        
    }
    func PlayerView(didTappedClose playerView: PlayerView) {
        if playerView.isFullScreen {
            playerView.exitFullscreen()
        } else {
            self.navigationController?.popViewController(animated: true)
        }
        
    }
    func PlayerView(didDisplayControl playerView: PlayerView) {
        UIApplication.shared.setStatusBarHidden(!playerView.isDisplayControl, with: .fade)
    }
}


