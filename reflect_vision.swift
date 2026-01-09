import Vision
import Foundation

func listMembers() {
    let landmarks = VNFaceLandmarks2D()
    let mirror = Mirror(reflecting: landmarks)
    for child in mirror.children {
        print("Member: \(child.label ?? "unknown")")
    }
}
listMembers()
