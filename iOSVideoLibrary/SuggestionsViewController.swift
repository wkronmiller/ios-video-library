//
//  SuggestionsViewController.swift
//  iOSVideoLibrary
//
//  Created by William Rory Kronmiller on 6/24/18.
//  Copyright © 2018 William Rory Kronmiller. All rights reserved.
//

import Foundation
import UIKit

class SuggestionsViewController: UICollectionViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 1 //TODO
    }
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = self.collectionView?.dequeueReusableCell(withReuseIdentifier: "videoPreview", for: indexPath)
        return cell!
    }
}
