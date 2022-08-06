//
//  EmojiArtViewController.swift
//  emojiArt
//
//  Created by 1C on 25/06/2022.
//

import UIKit
import MobileCoreServices

extension EmojiArt.EmojiInfo {
    init? (for label: UILabel) {
        if let attributedText = label.attributedText, let font = attributedText.font {
            self.x = Int(label.center.x)
            self.y = Int(label.center.y)
            self.text = attributedText.string
            self.size = Int(font.pointSize)
        } else {
            return nil
        }
        
    }
}

class EmojiArtViewController: UIViewController, UIDropInteractionDelegate, UIScrollViewDelegate, UICollectionViewDelegate, UICollectionViewDataSource  , UICollectionViewDelegateFlowLayout, UICollectionViewDragDelegate, UICollectionViewDropDelegate, UIPopoverPresentationControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
       
    // MARK: - Model
    
    var emojiArt: EmojiArt? {
        get{
            if let url = emojiArtBackGroundImage.url {
                let emojisInfo = emojiArtView.subviews.compactMap({ $0 as? UILabel }).compactMap({ EmojiArt.EmojiInfo(for: $0) })
                return EmojiArt(url: url, emojis: emojisInfo)
            }
            return nil
        }
        set{
            emojiArtBackGroundImage = (nil, nil)
            emojiArtView.subviews.compactMap({$0 as? UILabel}).forEach({ $0.removeFromSuperview() })
            if let url = newValue?.url {
                fetcherImage = ImageFetcher(fetch: url, handler: { (url, image) in
                    DispatchQueue.main.async {
                        self.emojiArtBackGroundImage = (url, image)
                        newValue?.emojis.forEach({
                            let attributedText = $0.text.attributedString(withTextStyle: .body, ofSize: CGFloat($0.size))
                            self.emojiArtView.addLabel(with: attributedText, centered: CGPoint(x: $0.x, y: $0.y))
                        })
                        
                    }
                })
            }
        }
    }
    
    var document: EmojiArtDocument?
    
    // MARK: - Outlets
        
    @IBAction func close(_ sender: UIBarButtonItem? = nil) {

        if let observer = emojiArtViewObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        if document?.emojiArt != nil {
            document?.thumbnail = emojiArtView.snapshot
        }
        presentingViewController?.dismiss(animated: true) {
            self.document?.close(completionHandler: { success in
                if let observer = self.documentObserver {
                    NotificationCenter.default.removeObserver(observer)
                }
            })
        }
        
    }
    
    @IBAction func addEmoji(_ sender: UIButton) {
        
        addingEmoji = true
        emojiCollectionView.reloadSections(IndexSet(integer: 0))
            
    }
    
    @IBOutlet weak var dropZoneView: UIView! {
        didSet{
            dropZoneView.addInteraction(UIDropInteraction(delegate: self))
        }
    }
    
    @IBOutlet weak var embeddedDocInfoWidth: NSLayoutConstraint!
    @IBOutlet weak var embeddedDocInfoHeight: NSLayoutConstraint!
    @IBOutlet weak var scrollViewWidth: NSLayoutConstraint!
    @IBOutlet weak var scrollViewHeight: NSLayoutConstraint!
    
    @IBOutlet weak var scrollView: UIScrollView! {
        didSet{
            scrollView.minimumZoomScale = 0.1
            scrollView.maximumZoomScale = 5.0
            scrollView.delegate = self
            scrollView.addSubview(emojiArtView)
        }
    }
    
    @IBOutlet weak var emojiCollectionView: UICollectionView! {
        didSet{
            emojiCollectionView.dataSource = self
            emojiCollectionView.delegate  = self
            emojiCollectionView.dragDelegate = self
            emojiCollectionView.dropDelegate = self
            emojiCollectionView.dragInteractionEnabled = true
        }
    }
    
    @IBOutlet weak var cameraButton: UIBarButtonItem!{
        didSet{
            cameraButton.isEnabled = UIImagePickerController.isSourceTypeAvailable(.camera)
        }
    }
    @IBAction func takeFoto(_ sender: UIBarButtonItem) {
    
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        picker.allowsEditing = true
        picker.mediaTypes = [kUTTypeImage as String]
        
        present(picker, animated: true)
        
    }
    
    // MARK: - ImagePickerController delegate's methods
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.presentingViewController?.dismiss(animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        if let image = ((info[.editedImage] ?? info[.originalImage]) as? UIImage) {
            let url = image.storeLocallyAsJPEG(named: String(Date.timeIntervalSinceReferenceDate))
            emojiArtBackGroundImage = (url, image)
            documentChanged()
        }
        
        picker.presentingViewController?.dismiss(animated: true)
    }
    
    // MARK: - ViewController life cycle
        
    private var documentObserver: NSObjectProtocol?
    private var emojiArtViewObserver: NSObjectProtocol?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        guard document?.documentState != .normal else { return }
        
        documentObserver = NotificationCenter.default.addObserver(
            forName: UIDocument.stateChangedNotification,
            object: document,
            queue: OperationQueue.main,
            using: { notification in
                print("state change to \(self.document!.documentState.description)")
                if self.document?.documentState == .normal, let docInfoVC = self.embeddedDocInfo {
                    docInfoVC.document = self.document
                    self.embeddedDocInfoWidth.constant = docInfoVC.preferredContentSize.width
                    self.embeddedDocInfoHeight.constant = docInfoVC.preferredContentSize.height
                }
            }
        )
        
        //        MARK: implementation via file manager
        //        if let url = try? FileManager.default.url(for: .documentDirectory,
        //                                                  in: .userDomainMask,
        //                                                  appropriateFor: nil,
        //                                                  create: true).appendingPathComponent("Untitled.json") {
        //            if let jsonData = try? Data(contentsOf: url) {
        //                emojiArt = EmojiArt(json: jsonData)
        //            }
        //        }
        
        //      MARK: Implementation via UIDocument API
        document?.open(completionHandler: { success in
            if success {
                self.title = self.document?.localizedName
                self.emojiArt = self.document?.emojiArt
                self.emojiArtViewObserver = NotificationCenter.default.addObserver(
                    forName: .EmojiArtViewDidChange,
                    object: self.emojiArtView,
                    queue: OperationQueue.main,
                    using: { notification in
                        self.documentChanged()
                    }
                )
            }
        })
        
                
    }
    
    // MARK: - EmojiArtView delegate method's
    

    
    // MARK: - ScrollView delegate method's
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return emojiArtView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        scrollViewWidth.constant = scrollView.contentSize.width
        scrollViewHeight.constant = scrollView.contentSize.height
    }
    
    // MARK: - CollectionView dataSource & delegate method's
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        2
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch section {
        case 0: return 1
        case 1: return emojis.count
        default: return 0
        }
        
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 1 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EmojiCell", for: indexPath)
            if let emojiCell = cell as? emojiCollectionViewCell {
                let text = NSAttributedString.init(string: emojis[indexPath.item], attributes: [.font:font])
                emojiCell.label.attributedText = text
            }
            return cell
        } else if addingEmoji {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EmojiInputCell", for: indexPath)
            if let inputCell = cell as? TextFieldCollectionViewCell {
                inputCell.resignHandler = { [weak self, unowned inputCell] in
                    if let text = inputCell.textField.text {
                        self?.emojis = (text.map({String($0)}) + self!.emojis).uniquified
                    }
                    self?.addingEmoji = false
                    self?.emojiCollectionView.reloadData()
                }
            }
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AddEmojiButtonCell", for: indexPath)
            
            return cell
        }
        
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if addingEmoji, indexPath.section == 0 {
            return CGSize(width: 300, height: 80)
        } else {
            return CGSize(width: 80,height: 80)
        }
    }
        
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let inputCell = cell as? TextFieldCollectionViewCell {
            inputCell.textField.becomeFirstResponder()
            
        }
    }
    
    // MARK: - CollectionView drag&drop delegate methods
    
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        session.localContext = collectionView
        return dragItem(at: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, itemsForAddingTo session: UIDragSession, at indexPath: IndexPath, point: CGPoint) -> [UIDragItem] {
        return dragItem(at: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: NSAttributedString.self)
    }
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        
        if let destIndex = destinationIndexPath, destIndex.section == 1 {
            let isSelf = (session.localDragSession?.localContext as? UICollectionView) == collectionView
            return UICollectionViewDropProposal.init(operation: isSelf ? .move : .copy, intent: .insertAtDestinationIndexPath)
        } else {
            return UICollectionViewDropProposal(operation: .cancel)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        performDropWith coordinator: UICollectionViewDropCoordinator)
    {
        
        let destinationIndex = coordinator.destinationIndexPath ?? IndexPath(item: 0, section: 0)
        
        for item in coordinator.items {
            if let sourceIndex = item.sourceIndexPath {
                if let attributedString = item.dragItem.localObject as? NSAttributedString {
                    collectionView.performBatchUpdates {
                        emojis.remove(at: sourceIndex.item)
                        emojis.insert(attributedString.string, at: destinationIndex.item)
                        collectionView.deleteItems(at: [sourceIndex])
                        collectionView.insertItems(at: [destinationIndex])
                    }
                    coordinator.drop(item.dragItem, toItemAt: destinationIndex)
                }
            } else {
                let placeHolderContext = coordinator.drop(
                    item.dragItem,
                    to: UICollectionViewDropPlaceholder.init(insertionIndexPath: destinationIndex, reuseIdentifier: "PlaceholderCell"))
                
                item.dragItem.itemProvider.loadObject(ofClass: NSAttributedString.self) {
                    (provider, error) in

                    if let attributedString = provider as? NSAttributedString {
                        DispatchQueue.main.async {
                            
                            placeHolderContext.commitInsertion(dataSourceUpdates: {insertionIndexPath in
                                self.emojis.insert(attributedString.string, at: insertionIndexPath.item)
                            })
                        }
                    } else {
                        placeHolderContext.deletePlaceholder()
                    }
                    
                }
                
            }
        }
    }
    
    // MARK: - View drag&drop delegate method's
    
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: NSURL.self) && session.canLoadObjects(ofClass: UIImage.self)
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        return UIDropProposal(operation: .copy)
    }
        
    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        
        fetcherImage = ImageFetcher { (url, image) in
            DispatchQueue.main.async {
                self.emojiArtBackGroundImage = (url, image)
            }
        }
        
        session.loadObjects(ofClass: NSURL.self) { nsUrls in
                
            if let url = nsUrls.first as? URL {
//                self.fetcherImage.fetch(url)
                DispatchQueue.global(qos: .userInitiated).async {
                    if let data = try? Data(contentsOf: url.imageURL) , let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            self.emojiArtBackGroundImage = (url, image)
                            self.documentChanged()
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.presentBadUrlWarning(for: url)
                        }
                    }
                }
            }
            
        }
        session.loadObjects(ofClass: UIImage.self) { images in
            
            if let image = images.first as? UIImage {
                self.fetcherImage.backup = image
            }
            
        }
    }
    
    // MARK: - PopOver presentation controller delegates method's
    
    func adaptivePresentationStyle(
        for controller: UIPresentationController,
        traitCollection: UITraitCollection
    ) -> UIModalPresentationStyle {
        .none
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "Show Document Info",
           let destination = segue.destination.contents as? DocumentInfoViewController {
            
            document?.thumbnail = emojiArtView.snapshot
            destination.document = document
            
            if let ppc = destination.popoverPresentationController {
                ppc.delegate = self
            }
          
        } else if segue.identifier == "Embedded Document Info" {
            embeddedDocInfo = segue.destination.contents as? DocumentInfoViewController
        }
    }
    
    @IBAction func closeDocument(bySegue: UIStoryboardSegue) {
        close()
    }
    
    // MARK: - Private implementation
    
    private var embeddedDocInfo: DocumentInfoViewController?
    
    private var emojiArtView = EmojiArtView()
        
    private func documentChanged() {
        document?.emojiArt = emojiArt
        if document?.emojiArt != nil {
            document?.updateChangeCount(.done)
        }
    }
    
    private var supressBadUrl = false
    
    private func presentBadUrlWarning(for url: URL) {
        
        if !supressBadUrl {
            
            let alert = UIAlertController(
                title: "Drop transfer failed",
                message: "Coudn't fetch image from this source. \nWhat do you want to do in the future?",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(
                title: "Keep warning",
                style: .default
            ))
            
            alert.addAction(UIAlertAction(
                title: "Stop warning",
                style: .destructive,
                handler: { action in
                    self.supressBadUrl = true
                }
            ))
            
            present(alert, animated: true)
            
        }
        
    }
    
    private var fetcherImage: ImageFetcher!
    
    private var addingEmoji = false
        
    private var _emojiArtBackGroundUrl: URL?
    
    private var emojiArtBackGroundImage: (url: URL?, image: UIImage?) {
        get {
            return (_emojiArtBackGroundUrl, emojiArtView.backGroundImage)
        }
        set {
            _emojiArtBackGroundUrl = newValue.url
            scrollView.zoomScale = 1.0
            emojiArtView.backGroundImage = newValue.image
            let size = newValue.image?.size ?? CGSize.zero
            emojiArtView.frame = CGRect(origin: CGPoint.zero, size: size)
            scrollView.contentSize = size
            scrollViewWidth?.constant = size.width
            scrollViewHeight?.constant = size.height
            if let dropZone = self.dropZoneView, size.width>0, size.height>0 {
                scrollView.zoomScale = max(dropZone.bounds.size.width/size.width,
                                           dropZone.bounds.size.height/size.height)
            }
        }
    }
    
    private var emojis = "🐎🐄🐈🐝🦋🐌🦆🐥🐣🐓🦃🐿🐂🌳🍎🍉🍒🍆🧅🥒🌈🌪⚽️🤸🏼‍♂️🍭🍓🔥".map {
        return String($0)
    }
    
    private var font: UIFont {
        let font = UIFont.preferredFont(forTextStyle: .body).withSize(64)
        return UIFontMetrics.init(forTextStyle: .body).scaledFont(for: font)
    }
        
    private func dragItem(at indexPath: IndexPath) -> [UIDragItem] {
     
        if !addingEmoji, let attributedText = (emojiCollectionView.cellForItem(at: indexPath) as? emojiCollectionViewCell)?.label.attributedText {
            let dragItem = UIDragItem(itemProvider: NSItemProvider.init(object: attributedText))
            dragItem.localObject = attributedText
            return [dragItem]
        } else {
            return []
        }
        
    }
    
}
