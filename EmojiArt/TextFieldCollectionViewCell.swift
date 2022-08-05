//
//  TextFieldCollectionViewCell.swift
//  emojiArt
//
//  Created by 1C on 03/07/2022.
//

import UIKit

class TextFieldCollectionViewCell: UICollectionViewCell, UITextFieldDelegate {
    
    @IBOutlet weak var textField: UITextField! {
        didSet{
            textField.delegate = self
            textField.inputAssistantItem.leadingBarButtonGroups = []
            textField.inputAssistantItem.trailingBarButtonGroups = []
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        textField.resignFirstResponder()
        return true
        
    }
    
    var resignHandler: (() -> Void)?
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        resignHandler?()
    }
    
}
