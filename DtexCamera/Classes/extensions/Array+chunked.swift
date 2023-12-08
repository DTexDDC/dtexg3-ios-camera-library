//
//  Array+chunked.swift
//  vision-camera-tflite-plugin
//
//  Created by Thomas Coldwell on 03/10/2022.
//

import Foundation

extension Array {
    func chunked(by chunkSize: Int) -> [[Element]] {
        return stride(from: 0, to: self.count, by: chunkSize).map {
            Array(self[$0..<Swift.min($0 + chunkSize, self.count)])
        }
    }
}
