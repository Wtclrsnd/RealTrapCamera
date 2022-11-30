//
//  ImageSaver.swift
//  RealTrapCamera
//
//  Created by Emil Shpeklord on 30.11.2022.
//

import UIKit

final class ImageSaver: NSObject {
    static func writeToPhotoAlbum(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted), nil)
    }

    @objc static func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        print("Save finished!")
    }
}
