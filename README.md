# DtexCamera

[![CI Status](https://img.shields.io/travis/wenge8n/DtexCamera.svg?style=flat)](https://travis-ci.org/wenge8n/DtexCamera)
[![Version](https://img.shields.io/cocoapods/v/DtexCamera.svg?style=flat)](https://cocoapods.org/pods/DtexCamera)
[![License](https://img.shields.io/cocoapods/l/DtexCamera.svg?style=flat)](https://cocoapods.org/pods/DtexCamera)
[![Platform](https://img.shields.io/cocoapods/p/DtexCamera.svg?style=flat)](https://cocoapods.org/pods/DtexCamera)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

DtexCamera is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'DtexCamera'
```

## Usage
Step 1. Add the tflite model file to project

Step 2. Update viewcontroller
````
import UIKit
import DtexCamera

class ViewController: UIViewController, DtexCameraViewControllerDelegate {

    @IBOutlet weak var resultImageView: UIImageView!
    @IBOutlet weak var resultLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func launchCameraTapped(_ sender: Any) {
        let vc = DtexCameraViewController()
        vc.modelPath = Bundle.main.path(forResource: "modelfilename", ofType: "tflite")
        vc.detectionConfidence = 0.5
        vc.delegate = self
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    func dtexCamera(_ dtexCamera: DtexCamera.DtexCameraViewController, didTake result: DtexCamera.Result) {
        resultImageView.image = result.photo
        resultLabel.text = "Status: \(result.isAcceptable ? "Green" : "Red")"
    }

}
````

#### Set model path (Required)

````vc.modelPath = Bundle.main.path(forResource: "modelfilename", ofType: "tflite")````

#### Set detection confidence (Optional)

````vc.detectionConfidence = 0.5````

Default confidence value is `0.7`

## Author

wenge8n, wenge8n@outlook.com

## License

DtexCamera is available under the MIT license. See the LICENSE file for more info.
