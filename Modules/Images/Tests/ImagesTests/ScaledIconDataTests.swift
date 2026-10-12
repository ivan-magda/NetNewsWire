import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Testing
import RSCore
@testable import Images

@Suite @MainActor struct ScaledIconDataTests {

	@Test func waitsForQueueWithoutBlockingMainActor() async {
		let queue = DispatchQueue(label: "ScaledIconDataTests.waiting")
		queue.suspend()
		var finished = false
		var task: Task<Data, Never>?
		await withCheckedContinuation { started in
			task = Task { @MainActor in
				started.resume()
				let result = await scaledIconData(Data([0, 1, 2]), on: queue)
				finished = true
				return result
			}
		}
		// The caller can run while image processing waits behind queued work.
		#expect(!finished)
		queue.resume()
		let result = await task?.value
		#expect(result == Data([0, 1, 2]))
		#expect(finished)
	}

	@Test func preservesSmallImageBytes() async throws {
		let data = try imageData(sizes: [16])
		let result = await scaledIconData(data, on: DispatchQueue(label: "ScaledIconDataTests.small"))
		#expect(result == data)
	}

	@Test func preservesInvalidBytes() async {
		let data = Data([0, 1, 2, 3])
		let result = await scaledIconData(data, on: DispatchQueue(label: "ScaledIconDataTests.invalid"))
		#expect(result == data)
	}

	@Test func reducesLargeImage() async throws {
		let maxPixelSize = RSImage.maxIconPixelSize
		let data = try imageData(sizes: [maxPixelSize * 4])
		let result = await scaledIconData(data, on: DispatchQueue(label: "ScaledIconDataTests.large"))
		let source = try #require(CGImageSourceCreateWithData(result as CFData, nil))
		let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
		#expect(image.width == maxPixelSize)
		#expect(image.width == image.height)
		#expect(CGImageSourceGetType(source) as String? == UTType.png.identifier)
	}

	@Test func extractsLargestFrame() async throws {
		let data = try imageData(sizes: [8, 32, 16], type: .tiff)
		let input = try #require(CGImageSourceCreateWithData(data as CFData, nil))
		#expect(CGImageSourceGetCount(input) == 3)
		let result = await scaledIconData(data, on: DispatchQueue(label: "ScaledIconDataTests.frames"))
		let source = try #require(CGImageSourceCreateWithData(result as CFData, nil))
		let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
		#expect(CGImageSourceGetCount(source) == 1)
		#expect(image.width == 32)
		#expect(image.height == 32)
		#expect(CGImageSourceGetType(source) as String? == UTType.png.identifier)
	}

	private func imageData(sizes: [Int], type: UTType = .png) throws -> Data {
		let data = NSMutableData()
		let destination = try #require(CGImageDestinationCreateWithData(data, type.identifier as CFString, sizes.count, nil))
		for size in sizes {
			let context = try #require(CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
				bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
			context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
			context.fill(CGRect(x: 0, y: 0, width: size, height: size))
			let image = try #require(context.makeImage())
			CGImageDestinationAddImage(destination, image, nil)
		}
		try #require(CGImageDestinationFinalize(destination))
		return data as Data
	}
}
