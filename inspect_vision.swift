import Vision
import Foundation

func inspectLandmarks() {
    let request = VNDetectFaceLandmarksRequest()
    request.revision = 3
    print("Request revision: \(request.revision)")
    
    // We can't easily get an observation without a face, 
    // but we can check the class description
    print("Class: \(VNFaceLandmarks2D.self)")
}
inspectLandmarks()
