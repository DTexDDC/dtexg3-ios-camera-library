//
//  ViewController.swift
//  DtexCamera
//
//  Created by wenge8n on 12/01/2023.
//  Copyright (c) 2023 wenge8n. All rights reserved.
//

import UIKit
import DtexCamera

class ViewController: UIViewController, DtexCameraViewControllerDelegate {

    @IBOutlet weak var resultImageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = "Example"
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func launchCameraTapped(_ sender: Any) {
        let vc = DtexCameraViewController()
        vc.modelPath = Bundle.main.path(forResource: "model", ofType: "tflite")
        vc.delegate = self
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    func dtexCamera(_ dtexCamera: DtexCameraViewController, didTake photo: UIImage) {
        resultImageView.image = photo
    }

}

