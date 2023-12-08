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
````
import UIKit
import DtexCamera

class ViewController: UIViewController, DtexCameraViewControllerDelegate {

    @IBOutlet weak var resultImageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func launchCameraTapped(_ sender: Any) {
        let vc = DtexCameraViewController()
        vc.delegate = self
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    func dtexCamera(_ dtexCamera: DtexCameraViewController, didTake photo: UIImage) {
        resultImageView.image = photo
    }

}
````

## Author

wenge8n, wenge8n@outlook.com

## License

DtexCamera is available under the MIT license. See the LICENSE file for more info.
