//
//  ScaledIconData.swift
//  Images
//

import Foundation
import RSCore

@MainActor func scaledIconData(_ data: Data, on queue: DispatchQueue) async -> Data {
	let maxPixelSize = RSImage.maxIconPixelSize
	return await withCheckedContinuation { continuation in
		queue.async {
			let scaledData = RSImage.scaledImageData(data, maxPixelSize: maxPixelSize) ?? data
			continuation.resume(returning: scaledData)
		}
	}
}
