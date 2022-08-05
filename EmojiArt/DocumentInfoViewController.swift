//
//  DocumentInfoViewController.swift
//  EmojiArt
//
//  Created by Злобин Сергей Александрович on 02.08.2022.
//

import UIKit

class DocumentInfoViewController: UIViewController {

    var document: EmojiArtDocument? {
        didSet {
            updateUI()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateUI()
    }
    
    private func updateUI() {
     
        if sizeLabel != nil, createdLabel != nil,
           let url = document?.fileURL,
           let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) {
            
            sizeLabel.text = "\(attributes[.size] ?? 0) bytes"
            if let created = attributes[.creationDate] as? Date {
                createdLabel.text = dateFormatter.string(from: created)
            }
            
            if thumbNailView != nil, let thumbNail = document?.thumbnail, thumbNailAspectRatio != nil {
                thumbNailView.image = thumbNail
                thumbNailView.removeConstraint(thumbNailAspectRatio)
                thumbNailAspectRatio = NSLayoutConstraint(
                    item: thumbNailView!,
                    attribute: .width,
                    relatedBy: .equal,
                    toItem: thumbNailView,
                    attribute: .height,
                    multiplier: thumbNail.size.width / thumbNail.size.height,
                    constant: 0
                )
                thumbNailView.addConstraint(thumbNailAspectRatio)
            }
            
            if presentationController is UIPopoverPresentationController {
                thumbNailView.isHidden = true
                returnToDocument.isHidden = true
                view.backgroundColor = .clear
            }
            
        }
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let fittedSize = topLevelStackView?.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
//            , presentationController is UIPopoverPresentationController
        {
            preferredContentSize = CGSize(width: fittedSize.width + 30, height: fittedSize.height + 30)
        }
    }
    
    private var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        return dateFormatter
    }()
    
    @IBAction private func done() {
        presentingViewController?.dismiss(animated: true)
    }
    
    @IBOutlet weak private var returnToDocument: UIButton!
    @IBOutlet weak private var topLevelStackView: UIStackView?
    @IBOutlet private var thumbNailAspectRatio: NSLayoutConstraint!
    @IBOutlet weak private var thumbNailView: UIImageView!
    @IBOutlet weak private var createdLabel: UILabel!
    @IBOutlet weak private var sizeLabel: UILabel!
}
