//
//  VideoLibrary.swift
//  iOSVideoLibrary
//
//  Created by William Rory Kronmiller on 6/21/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation
import FileProvider
import Alamofire
import PromiseKit

struct VideoOverview {
    let videoId: String
    let title: String
    let thumbnailUrl: String
    let infoUrl: String
    let isDownloaded: Bool
}

struct VideoDetails {
    let category: String
    let description: String
    let videoUrl: String
}

struct VideoInfo {
    let overview: VideoOverview
    let details: VideoDetails
}

struct VideoCategories {
    let numCategories = 1
    let youtube: [VideoOverview]
}

class VideoLibrary: NSObject {
    private let baseUrl = "https://a1z1gsiiuf.execute-api.us-east-1.amazonaws.com"
    private let deploymentType = "dev"
    private let filemgr = FileManager.default
    private let docsPath: URL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    
    private func getDownloadPath(videoId: String) -> URL {
        return docsPath.appendingPathComponent(videoId + ".mp4")
    }
    
    private func videoIsCached(videoId: String) -> Bool {
        let downloadPath = getDownloadPath(videoId: videoId).relativePath
        let exists = filemgr.isReadableFile(atPath: downloadPath)
        do {
            let contents = try filemgr.contentsOfDirectory(at: docsPath, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            NSLog("Checking if video is downloaded \(downloadPath): \(exists) in directory \(docsPath): \(contents)")
        } catch let error {
            NSLog("Failed to list directory \(error)")
        }
        return exists
    }
    
    private func downloadVideo(videoInfo: VideoInfo) -> Promise<String> {
        let destination: DownloadRequest.DownloadFileDestination =  { _, _ in
            return (self.getDownloadPath(videoId: videoInfo.overview.videoId), [.removePreviousFile])
        }
        return Promise{ seal in
            NSLog("Downloading video \(videoInfo)")
            Alamofire.download(videoInfo.details.videoUrl, to: destination)
                .downloadProgress(closure: { progress in
                    NSLog("Download progress \(videoInfo.overview.videoId) \(progress.fractionCompleted)")
                })
                .response { response in
                    NSLog("Completed download, error: \(response.error)")
                    seal.resolve(response.destinationURL!.absoluteString, nil)
                }
        }
    }
    
    private func extractVideo(entries: [[String: String]]) -> [VideoOverview] {
        return entries.map{ entry in
            return VideoOverview(
                videoId: entry["videoId"]!,
                title: entry["title"]!,
                thumbnailUrl: entry["thumbnailUrl"]!,
                infoUrl: entry["infoUrl"]!,
                isDownloaded: videoIsCached(videoId: entry["videoId"]!))
        }
    }
    
    private func getVideoInfo(videoOverview: VideoOverview) -> Promise<VideoInfo> {
        let url = "\(baseUrl)\(videoOverview.infoUrl)"
        return Promise<VideoInfo> { seal in
            Alamofire.request(url).responseJSON{ json in
                let video = (json.result.value as! [String: [String: String]])["video"]!
                let videoDetails = VideoDetails(
                    category: video["category"]!,
                    description: video["description"]!,
                    videoUrl: video["videoUrl"]!)
                let videoInfo = VideoInfo(overview: videoOverview, details: videoDetails)
                seal.resolve(videoInfo, nil)
            }
        }
    }
    
    func syncVideos(videoCategories: VideoCategories) -> Promise<Void> { //TODO
        assert(videoCategories.numCategories == 1) //NOTE: must update when adding categories
        let toDownload = videoCategories.youtube.filter{ video in
            return video.isDownloaded == false
        }
        let downloadPromises = toDownload
            .map { video in return self.getVideoInfo(videoOverview: video) }
            .map { infoPromise in infoPromise.then { videoInfo in self.downloadVideo(videoInfo: videoInfo)} }
        return when(resolved: downloadPromises).done { urls in
            NSLog("Downloaded videos to urls \(urls)")
        }
    }
    
    func listVideos(completionHandler: @escaping (VideoCategories) -> Void) {
        let url = "\(baseUrl)/\(deploymentType)/videos"
        Alamofire.request(url).responseJSON{ json in
            let videoCategories = (json.result.value as! [String: [String: [[String: String]]]])["videos"]!
            
            completionHandler(VideoCategories(
                youtube: self.extractVideo(entries: videoCategories["youtube"]!)
            ))
        }
    }
    
    static let shared = VideoLibrary()
}
