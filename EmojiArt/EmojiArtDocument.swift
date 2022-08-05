//
//  EmojiArtDocument.swift
//  EmojiArt
//
//  Created by 1C on 17/07/2022.
//

import UIKit

class EmojiArtDocument: UIDocument {
    
    // MARK: - Model
    
    var emojiArt: EmojiArt?
    var thumbnail: UIImage?
    
    // MARK: - Public API
    
    override func contents(forType typeName: String) throws -> Any {
        return emojiArt?.json ?? Data()
    }
    
    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        if let jsonData = contents as? Data {
            emojiArt = EmojiArt.init(json: jsonData)
        }
    }
    
    override func fileAttributesToWrite(to url: URL, for saveOperation: UIDocument.SaveOperation) throws -> [AnyHashable : Any] {
        
        var attributes = try super.fileAttributesToWrite(to: url, for: saveOperation)
        
        if let thumbnail = self.thumbnail {
            attributes[URLResourceKey.thumbnailDictionaryKey] = [URLThumbnailDictionaryItem.NSThumbnail1024x1024SizeKey: thumbnail]
        }
        
        return attributes
        
    }
    
}

