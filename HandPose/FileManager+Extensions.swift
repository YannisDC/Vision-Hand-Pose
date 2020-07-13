//
//  FileManager+Extensions.swift
//  HandPose
//
//  Created by Yannis De Cleene on 04/07/2020.
//  Copyright © 2020 Apple. All rights reserved.
//

import Foundation

extension FileManager {
    func clearTmpDirectory() {
        do {
            let tmpDirURL = FileManager.default.temporaryDirectory
            let tmpDirectory = try contentsOfDirectory(atPath: tmpDirURL.path)
            try tmpDirectory.forEach { file in
                let fileUrl = tmpDirURL.appendingPathComponent(file)
                try removeItem(atPath: fileUrl.path)
            }
        } catch {
            //catch the error somehow
        }
    }
}
