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
import UIKit

struct VideoOverview: Encodable, Decodable {
    let videoId: String
    let title: String
    let thumbnailUrl: String
    let infoUrl: String
    let isDownloaded: Bool
}

struct VideoDetails: Encodable, Decodable {
    let category: String
    let description: String
    let videoUrl: String
}

struct VideoInfo: Encodable, Decodable {
    let overview: VideoOverview
    let details: VideoDetails
}

struct VideoCategories: Encodable, Decodable {
    let numCategories = 1
    let youtube: [VideoOverview]
}

enum FileLoadError: Error {
    case fileNotFound
    case imageInvalid
}

class VideoLibrary: NSObject {
    private let baseUrl = "https://a1z1gsiiuf.execute-api.us-east-1.amazonaws.com"
    private let deploymentType = "dev"
    private let filemgr = FileManager.default
    private let encoder = JSONEncoder()
    private let docsPath: URL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    private let context = CIContext(options: nil)
    
    func getDownloadPath(videoId: String) -> URL {
        return docsPath.appendingPathComponent(videoId + ".mp4")
    }
    
    private func getThumbnailPath(videoOverview: VideoOverview) -> URL {
        return docsPath.appendingPathComponent(videoOverview.videoId + ".thumbnail")
    }
    
    private func getVideoListPath() -> URL {
        return docsPath.appendingPathComponent("videoCategories.json")
    }
    
    func videoIsCached(videoId: String) -> Bool {
        let downloadPath = getDownloadPath(videoId: videoId).relativePath
        return filemgr.isReadableFile(atPath: downloadPath)
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
                    if let error = response.error {
                        seal.reject(error)
                    } else {
                        seal.resolve(response.destinationURL!.absoluteString, nil)
                    }
                }
        }
    }
    
    private func storeData<T: Encodable>(data: T, url: URL) -> Bool {
        if let _ = try? encoder.encode(data).write(to: url) {
            return true
        }
        return false
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
                if let error = json.error {
                    return seal.reject(error)
                }
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
    
    private func refreshVideoList() -> Promise<VideoCategories> {
        let url = "\(baseUrl)/\(deploymentType)/videos"
        return Promise<VideoCategories> { seal in
            Alamofire.request(url).responseJSON{ json in
                if let error = json.error {
                    return seal.reject(error)
                }
                let videoCategories = (json.result.value as! [String: [String: [[String: String]]]])["videos"]!
                let categories = VideoCategories(
                    youtube: self.extractVideo(entries: videoCategories["youtube"]!)
                )
                let stored = self.storeData(data: categories, url: self.getVideoListPath())
                NSLog("Stored videos \(stored)")
                seal.resolve(categories, nil)
            }
        }
    }
    
    private func downloadVideoImage(videoOverview: VideoOverview) -> Promise<Data> {
        return Promise<Data> { seal in
            Alamofire.request(videoOverview.thumbnailUrl).responseData{image in
                seal.resolve(image.data!, nil)
            }
        }
    }
    private func recolorImage(image: UIImage, name: String) -> UIImage {
        let filter = CIFilter(name: name)
        filter!.setValue(CIImage(image: image), forKey: kCIInputImageKey)
        let outImage = filter!.outputImage
        let cgImage = context.createCGImage(outImage!, from: outImage!.extent)
        let processedImage = UIImage(cgImage: cgImage!)
        return processedImage
    }
    
    private func transformImage(videoOverview: VideoOverview, image: UIImage) -> UIImage {
        let cached = self.videoIsCached(videoId: videoOverview.videoId)
        if(cached) {
            return image
        } else {
            return self.recolorImage(image: image, name: "CIPhotoEffectNoir")
        }
    }
    
    func getVideoThumbnail(videoOverview: VideoOverview) -> Promise<UIImage> {
        if let data = self.filemgr.contents(atPath: self.getThumbnailPath(videoOverview: videoOverview).relativePath) {
            NSLog("Using cached image")
            if let image = UIImage(data: data) {
                return Promise.value(transformImage(videoOverview: videoOverview, image: image))
            }
            return Promise(error: FileLoadError.imageInvalid)
        }
        return downloadVideoImage(videoOverview: videoOverview).map { data in
            if let image = UIImage(data: data) {
                let writeResult = try? data.write(to: self.getThumbnailPath(videoOverview: videoOverview))
                NSLog("Cached thumbnail \(writeResult)")
                return self.transformImage(videoOverview: videoOverview, image: image)
            } else {
                throw FileLoadError.imageInvalid
            }
        }
    }
    
    func syncVideos(videos: [VideoOverview]) -> Promise<Void> {
        let toDownload = videos.filter{ video in
            return video.isDownloaded == false
        }
        let downloadPromises = toDownload
            .map { video in return self.getVideoInfo(videoOverview: video) }
            .map { infoPromise in infoPromise.then { videoInfo in self.downloadVideo(videoInfo: videoInfo)} }
        return when(resolved: downloadPromises).done { urls in
            NSLog("Downloaded videos to urls \(urls)")
        }
    }
    
    func syncVideos(videoCategories: VideoCategories) -> Promise<Void> {
        assert(videoCategories.numCategories == 1) //NOTE: must update when adding categories
        let videos = videoCategories.youtube
        return syncVideos(videos: videos)
    }

    
    func listVideos(refresh: Bool) -> Promise<VideoCategories> {
        if !refresh {
            if let data = self.filemgr.contents(atPath: self.getVideoListPath().relativePath) {
                if let categories = try? JSONDecoder().decode(VideoCategories.self, from: data) {
                    NSLog("Loading cached categories \(categories)")
                    return Promise.value(categories)
                }
            }
        }
        return refreshVideoList()
    }
    
    static let shared = VideoLibrary()
}
