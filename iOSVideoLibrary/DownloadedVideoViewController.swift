//
//  DownloadedVideoViewController.swift
//  iOSVideoLibrary
//
//  Created by William Rory Kronmiller on 6/30/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation
import UIKit
import AVKit

class DownloadedVideosViewController: UICollectionViewController {
    private var videoCategories: VideoCategories?
    
    private func updateVideoList() {
        VideoLibrary.shared.listVideos(refresh: false).done { categories in
            self.videoCategories = categories
            self.collectionView?.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.updateVideoList()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.updateVideoList()
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        NSLog("Getting number of items for section \(section)")
        if let categories = self.videoCategories {
            if(section == 0) {
                let count = categories.youtube.filter { video in
                    return VideoLibrary.shared.videoIsCached(videoId: video.videoId)
                }.count
                NSLog("Count \(count)")
                return count
            }
        }
        return 0
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "videoPreview", for: indexPath) as! VideoPreviewCell
        if(indexPath.section == 0) {
            cell.displayContent(videoOverview: (self.videoCategories?.youtube.filter{video in
                return VideoLibrary.shared.videoIsCached(videoId: video.videoId)
                }[indexPath.row])!)
            NSLog("Configured cell \(cell)")
        }
        NSLog("Returning cell \(cell) for \(indexPath)")
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if(indexPath.section == 0) {
            let video = self.videoCategories?.youtube.filter{video in
                return VideoLibrary.shared.videoIsCached(videoId: video.videoId)
                }[indexPath.row]
            let url = VideoLibrary.shared.getDownloadPath(videoId: video!.videoId)
            let player = AVPlayer(url: url)
            let controller = AVPlayerViewController()
            controller.player = player
            present(controller, animated: true) {
                player.play()
            }
        }
    }
}
