import Vision
import Foundation

func checkIrisSupport() {
    let request = VNDetectFaceLandmarksRequest()
    print("Revision 3 supported: \(VNDetectFaceLandmarksRequest.supportedRevisions.contains(3))")
    
    // Check for iris landmarks availability
    for revision in VNDetectFaceLandmarksRequest.supportedRevisions {
        print("Revision \(revision) available")
    }
}
checkIrisSupport()
