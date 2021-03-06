//
//  FirstViewController.swift
//  iOSVideoLibrary
//
//  Created by William Rory Kronmiller on 6/21/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import UIKit
import Alamofire
import AVKit

class VideoPreviewCell: UICollectionViewCell {
    @IBOutlet weak var thumbnail: UIImageView!
    @IBOutlet weak var title: UILabel!
    
    func displayContent(videoOverview: VideoOverview) {
        self.title.text = videoOverview.title
        VideoLibrary.shared.getVideoThumbnail(videoOverview: videoOverview).done{ image in
            DispatchQueue.main.async {
                self.thumbnail.image = image
            }
        }
    }
}

class VideoLibraryViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource {
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var syncButton: UIButton!
    @IBOutlet weak var syncActivity: UIActivityIndicatorView!
    private var refreshControl: UIRefreshControl!
    
    private var videoCategories: VideoCategories?
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        NSLog("Getting number of items for section \(section)")
        if let categories = self.videoCategories {
            if(section == 0) {
                let count = categories.youtube.count
                NSLog("Count \(count)")
                return count
            }
        }
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = self.collectionView.dequeueReusableCell(withReuseIdentifier: "videoPreview", for: indexPath) as! VideoPreviewCell
        if(indexPath.section == 0) {
            cell.displayContent(videoOverview: (self.videoCategories?.youtube[indexPath.row])!)
            NSLog("Configured cell \(cell)")
        }
        NSLog("Returning cell \(cell) for \(indexPath)")
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if(indexPath.section == 0) {
            let video = self.videoCategories?.youtube[indexPath.row]
            let cached = VideoLibrary.shared.videoIsCached(videoId: video!.videoId)
            if(cached) {
                let url = VideoLibrary.shared.getDownloadPath(videoId: video!.videoId)
                let player = AVPlayer(url: url)
                let controller = AVPlayerViewController()
                controller.player = player
                present(controller, animated: true) {
                    player.play()
                }
            } else {
                VideoLibrary.shared.syncVideos(videos: [video!]).done { _ in
                    self.collectionView.reloadData()
                }
            }
        }
    }
    
    @objc private func updateVideoList(refresh: Bool = true) {
        VideoLibrary.shared.listVideos(refresh: refresh).done{videoCategories in
            NSLog("Loaded videos \(videoCategories)")
            self.videoCategories = videoCategories
            self.collectionView.reloadData()
            self.refreshControl.endRefreshing()
        }
    }
    
    override func viewDidLoad() {
        self.syncActivity.hidesWhenStopped = true
        self.refreshControl = UIRefreshControl()
        self.refreshControl.tintColor = UIColor.purple
        super.viewDidLoad()
        self.collectionView.delegate = self
        self.collectionView.dataSource = self
        self.refreshControl.addTarget(self, action: #selector(updateVideoList), for: .valueChanged)
        self.collectionView.addSubview(refreshControl)
        self.updateVideoList(refresh: false)
    }
    
    @IBAction func syncButtonPressed(_ sender: Any) {
        self.syncButton.isHidden = true
        self.syncActivity.startAnimating()
        
        VideoLibrary.shared.listVideos(refresh: true).map{videoCategories in
            NSLog("Loaded videos \(videoCategories)")
            self.videoCategories = videoCategories
            return videoCategories
        }
        .then{ videoCategories in
            VideoLibrary.shared.syncVideos(videoCategories: videoCategories)
        }
        .done{ _ in
            NSLog("Videos synced...refreshing view")
            self.syncActivity.stopAnimating()
            self.syncButton.isHidden = false
            self.collectionView.reloadData()
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

