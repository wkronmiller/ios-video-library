//
//  VideoLibrary.swift
//  iOSVideoLibrary
//
//  Created by William Rory Kronmiller on 6/21/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation
import Alamofire

struct VideoOverview {
    let videoId: String
    let title: String
    let thumbnailUrl: String
    let infoUrl: String
}

struct VideoCategories {
    let numCategories = 1
    let youtube: [VideoOverview]
}

class VideoLibrary: NSObject {
    private let baseUrl = "https://a1z1gsiiuf.execute-api.us-east-1.amazonaws.com"
    private let deploymentType = "dev"
    
    private func extractVideo(entries: [[String: String]]) -> [VideoOverview] {
        return entries.map{ entry in
            return VideoOverview(
                videoId: entry["videoId"]!,
                title: entry["title"]!,
                thumbnailUrl: entry["thumbnailUrl"]!,
                infoUrl: entry["infoUrl"]!)
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
