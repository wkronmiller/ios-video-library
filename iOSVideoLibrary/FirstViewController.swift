//
//  FirstViewController.swift
//  iOSVideoLibrary
//
//  Created by William Rory Kronmiller on 6/21/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import UIKit
import Alamofire

class VideoPreviewCell: UICollectionViewCell {
    @IBOutlet weak var thumbnail: UIImageView!
    @IBOutlet weak var title: UILabel!
    func displayContent(videoOverview: VideoOverview) {
        self.title.text = videoOverview.title
        Alamofire.request(videoOverview.thumbnailUrl).responseData{image in
            DispatchQueue.main.async {
                self.thumbnail.image = UIImage(data: image.data!)
            }
        }
    }
}

class FirstViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource {
    @IBOutlet weak var collectionView: UICollectionView!
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.collectionView.delegate = self
        self.collectionView.dataSource = self
        VideoLibrary.shared.listVideos().map{videoCategories in
            NSLog("Loaded videos \(videoCategories)")
            self.videoCategories = videoCategories
            
            
            return videoCategories
        }
        .then{ videoCategories in
            VideoLibrary.shared.syncVideos(videoCategories: videoCategories)
        }
        .done{ _ in
            NSLog("Videos synced...refreshing view")
            self.collectionView.reloadData()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

