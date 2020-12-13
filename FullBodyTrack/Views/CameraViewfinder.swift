//
//  CameraViewfinder.swift
//  FullBodyTrack
//
//  Created by DJ Figueroa on 12/13/20.
//

import UIKit

class CameraViewfinder: UIView {
    
    override init (frame : CGRect) {
        super.init(frame : frame)
        initView()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initView()
    }
    
    private func initView() {
        Bundle.main.loadNibNamed("CameraViewfinder", owner: self, options: nil)
        self.addSubview(View)
        View.frame = self.bounds
        self.clipsToBounds = true
        
    }

    @IBOutlet var View: UIView!
    @IBOutlet weak var imageView: UIImageView!
    
    public func updateWithImg(img: UIImage) {
        DispatchQueue.main.async {
            self.imageView.image = img
        }
    }
    
    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */
    
    

}
