//
//  MusicTagEditorController.swift
//  Music Tag
//
//  Created by Melo on 11/22/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import PanModal
import KakaTaglibKit
import KakaPhotoBrowser
import Kingfisher
import UniformTypeIdentifiers
import StoreKit

class MusicTagEditorController: SuperViewController {
    init(_ model: MusicItemModel? = nil) {
        super.init(nibName: nil, bundle: nil)
        self.origialModel = model
        self.editModel = model
    }
    
    @MainActor public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func preSetupSubViews() {
        super.preSetupSubViews()
        contentView.addSubview(tableView)
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        tableView.frame = contentView.bounds
        
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        
        if !kaka_IsMacOS() {
            self.title = "Music Tag".localStr()
            self.navigationItem.largeTitleDisplayMode = .never
            self.navigationItem.rightBarButtonItem = self.searchItem
        }
        
        self.refreshDataAction()
    }
    
    @objc func refreshDataAction() {
        guard let fileURL = self.origialModel?.localFullFilePath() else { return }
        let metaModel = TaglibMetadataParser.readMetadata(withFileURL: fileURL, read: .all)
                
        self.fileSize = fileURL.fileSizeString
        self.coverImage = metaModel?.coverArt
        self.editModel = metaModel?.mergeTagLibInfo(self.origialModel)
        
        self.tableView.reloadData()
    }
    
    lazy var searchItem: UIBarButtonItem = {
        let storageArray: [SearchEngineType] = [.google, .bing, .naver, .duckduck, .yahooJapan, .yandex, .quark]
        
        var actionArray = [UIAction]()
        
        for subItem in storageArray {
            let iconImage = Reasource.named(subItem.iconName()).kaka_reSize(reSize: CGSizeMake(25.ckValue(), 25.ckValue()))
            let subMenu = UIAction(title: subItem.nameStr(), image: iconImage, identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off, handler: { [weak self] _ in
                guard let wSelf = self else { return }
                
                self?.searchAction(subItem)
            })
            
            actionArray.append(subMenu)
        }
                
        let addMenu = UIMenu(title: "", children: actionArray)
        
        let item = UIBarButtonItem(systemItem: .search, primaryAction: nil, menu: addMenu)
        
        return item
    }()
    
    func searchAction(_ searchEngine: SearchEngineType) {
        guard var title = self.editModel?.title, title.count > 0 else {
            if let titleCell = self.tableView.cellForRow(at: IndexPath(row: 1, section: 1)) as? MeteDataDetialViewCell {
                titleCell.kaka_playShakeAnim(4)
            }
            return
        }
        
        if let artist = self.editModel?.artist, artist.count > 0 {
            title = artist + " " + title
        }
        
        let searchStr = String(format: searchEngine.searchUrl(), title)
        
        guard let vURL = URL(string: searchStr) else { return }
        UIApplication.shared.open(vURL)
    }
    
    @objc func shareAction() {
        
        guard let tempURL = self.origialModel?.localFullFilePath() else { return }
                        
        if kaka_IsMacOS() {
            let documentPicker = UIDocumentPickerViewController(forExporting: [tempURL])
                documentPicker.modalPresentationStyle = .formSheet
            self.present(documentPicker, animated: true)
        }else{
            let shareVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            if !kaka_IsiPhone() {
                if let exportCell = self.tableView.cellForRow(at: IndexPath(row: 0, section: dataArray.count - 1)) {
                    shareVC.popoverPresentationController?.sourceView = exportCell
                }
            }
            self.present(shareVC, animated: true, completion: nil)
        }
    }
    
    @objc func vipBarAction() {
        if !DiscountIAPManager.shared.isShowDiscount() {
            DiscountIAPManager.reset()
        }
        
        AppStoreKitManager.presentPurcharseVC(self)
    }
    
    func refreshMusicModel(_ model: MusicItemModel) {
        self.origialModel = model
        self.editModel = model
        self.refreshDataAction()
    }
    
    var editModel: MusicItemModel?
    
    var origialModel: MusicItemModel?
    
    var onEditCallback: ((MusicItemModel)->Void)?
    
    var coverImage: UIImage?
    
    var fileSize: String = ""
    
    lazy var dataArray: [MeteDataGroupCellModel] = {
        let model1 = MeteDataGroupCellModel(group: .headGroup, headTitle: nil, itemArray: [.headerTag], footTitle: nil)
        let model2 = MeteDataGroupCellModel(group: .basicGroup, headTitle: "*" + "Basic".localStr(), itemArray: [.coverImage, .title, .artist, .album, .lyrics], footTitle: nil)
        let model3 = MeteDataGroupCellModel(group: .otherGroup, headTitle: "Others".localStr(), itemArray: [.year, .genre, .track, .comment, .channel, .bitRate, .samples], footTitle: nil)
        let model4 = MeteDataGroupCellModel(group: .readonlyGroup, headTitle: "File".localStr(), itemArray: [.fileName, .fileExtension, .fileSize, .filePath], footTitle: nil)
        let model5 = MeteDataGroupCellModel(group: .exportGroup, headTitle: nil, itemArray: [.export], footTitle: nil)
        return kaka_IsMacOS() ? [model2, model3, model4, model5] : [model1, model2, model3, model4, model5]
    }()
    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: kaka_IsMacOS() ? .grouped : .insetGrouped)
        view.dataSource = self
        view.delegate = self
        view.contentInset = kaka_IsMacOS() ? UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0) : UIEdgeInsets(top: 0, left: 0, bottom: kaka_safeAreaInsets().bottom + 30.ckValue(), right: 0)
        view.rowHeight = UITableView.automaticDimension
        view.contentInsetAdjustmentBehavior = .automatic
        view.register(MusicTagHeadCell.self, forCellReuseIdentifier: "MusicTagHeadCell")
        view.register(MeteDataDetialViewCell.self, forCellReuseIdentifier: "MeteDataDetialViewCell")
        view.register(UITableViewCell.self, forCellReuseIdentifier: "ExportTableViewCell")
        return view
    }()
    
}

extension MusicTagEditorController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataArray.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataArray[section].itemArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let groupModel = dataArray[indexPath.section]
        let itemType = groupModel.itemArray[indexPath.row]
        
        if groupModel.group == .headGroup {
            let cell = tableView.dequeueReusableCell(withIdentifier: "MusicTagHeadCell", for: indexPath) as! MusicTagHeadCell
            return cell
        } else if groupModel.group == .exportGroup {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ExportTableViewCell", for: indexPath)
            var cellConfig = UIListContentConfiguration.cell()
            cellConfig.text = itemType.titleStr()
            cellConfig.textProperties.font = UIFontBold(17.ckValue())
            cellConfig.textProperties.color = .white
            cellConfig.textProperties.alignment = .center
            cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 5)
            cell.backgroundColor = appMainColor
            cell.accessoryType = .none
            cell.contentConfiguration = cellConfig
            return cell
        }else{
            let cell = tableView.dequeueReusableCell(withIdentifier: "MeteDataDetialViewCell", for: indexPath) as! MeteDataDetialViewCell
            cell.update(model: self.editModel, itemType: itemType, coverImage: self.coverImage, fileSize: self.fileSize)
            return cell
        }
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let groupModel = dataArray[indexPath.section]
        let itemType = groupModel.itemArray[indexPath.row]
        
        if itemType == .coverImage {
            self.clickModifyCover()
        }
        
        if itemType == .title {
            self.editSongTitleAction()
        }
        
        if itemType == .artist {
            self.editArtistAction()
        }
        
        if itemType == .album {
            self.editAlbumNameAction()
        }
        
        if itemType == .genre {
            self.editGenreAction()
        }
        
        if itemType == .track {
            self.editTrackAction()
        }
        
        if itemType == .comment {
            self.editCommentAction()
        }
        
        if itemType == .genre {
            let genreVC = GenreTypeViewController(self.editModel?.musicGenreType())
            genreVC.onSelectCallback = { [weak self] (subGenre) in
                guard let wSelf = self, let filePath = wSelf.origialModel?.localFullFilePath() else { return }
                let success = TaglibMetadataParser.setGenre(subGenre.rawValue, toFileURL: filePath)
                if success {
                    self?.refreshDataAction()
                    self?.view.makeToast("Embedded Success".localStr())
                }
            }
            
            self.present(UINavigationController(rootViewController: genreVC), animated: true)
        }
        
        if itemType == .year {
            self.editYearAction()
        }
        
        if itemType == .lyrics {
            if let editModel = self.editModel {
                let lyricVC = LyricDetialViewController(editModel: editModel)
                lyricVC.onEditCallback = { [weak self] (newModel) in
                    self?.origialModel?.lyricModel = newModel.lyricModel
                    self?.refreshDataAction()
                }
                
                if kaka_IsMacOS() {
                    let navVC = KakaNavigationController(rootViewController: lyricVC)
                    self.present(navVC, animated: true)
                }else{
                    self.navigationController?.pushViewController(lyricVC, animated: true)
                }
            }
        }
        
        if itemType == .filePath {
            
            var filePath: String?
            if #available(iOS 16.0, *) {
                filePath = self.editModel?.localFullFilePath().path(percentEncoded: false)
            }else{
                filePath = self.editModel?.localFullFilePath().path
            }
            
            guard let filePath = filePath else { return }
            UIPasteboard.general.string = filePath
            self.view.makeToast("Copied".localStr())
        }
        
        if itemType == .export {
            self.shareAction()
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let groupModel = dataArray[indexPath.section]
        let itemType = groupModel.itemArray[indexPath.row]
        
        return itemType == .coverImage ? 100.ckValue() : UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let groupModel = dataArray[section]
        return groupModel.headTitle
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let groupModel = dataArray[section]
        return groupModel.footTitle
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }
    
}


extension MusicTagEditorController {
    
    func clickModifyCover() {
        guard let editModel = self.editModel else { return }
        
        let albumName = (editModel.album ?? editModel.title) ?? (editModel.artist ?? "")
        let coverVC = CoverGalleryViewController(editStyle: .recommend(albumName))
        let navVC = KakaNavigationController(rootViewController: coverVC)
        coverVC.onSelectCallback = { [weak self] (coverImage) in
            self?.editCoverImage(coverImage)
        }
        self.present(navVC, animated: true)
    }
    
    func editCoverImage(_ image: UIImage) {
        
        guard let tempURL = self.origialModel?.localFullFilePath() else { return }
        guard let editModel = self.editModel else { return }
        
        let success = TaglibMetadataParser.setCoverArt(image, toFileURL: tempURL)
        
        debugPrint("标签元数据 = \(success)")

        if success {
            ImageCache.default.clearCache { [weak self] in
                guard let wSelf = self else { return }
                wSelf.refreshDataAction()
                wSelf.onEditCallback?(editModel)
                wSelf.view.makeToast("Embedded Success".localStr())
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    SKStoreReviewController.requestReview(in: windowScene)
                }
            }
        }
        
    }
    
    private func editSongTitleAction() {
        
        guard let oldModel = self.origialModel, let tempURL = self.origialModel?.localFullFilePath() else { return }
        guard let editModel = self.editModel else { return }

        let editAlertVC = UIAlertController(title: MusicActionType.editTitle.formatStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            textView.text = (editModel.title?.count ?? 0 > 0) ? editModel.title : oldModel.showSongName()
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Done".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, var nameText = nameField.text, nameText.count > 0 else {
                return
            }
            
            let baseFileURL: URL = tempURL.deletingLastPathComponent()
            nameText = nameText.replaceChar(oldChar: "/", newChar: "|")
            var editModel = oldModel
            editModel.title = nameText
            
            let targetFilePath = SandboxFileManager.shared.updateTitleTag(model: oldModel, folderURL: baseFileURL, title: nameText)
            if let _ = targetFilePath {
                self?.onEditCallback?(editModel)
                self?.origialModel?.title = nameText
                if editModel.handleType != .link  {
                    self?.origialModel?.originalFilePath = baseFileURL.path.ocString.appendingPathComponent(editModel.filePathName() + editModel.addPathExtension())
                }
                self?.refreshDataAction()
                self?.view.makeToast("Embedded Success".localStr())
            }else{
                self?.origialModel?.title = self?.origialModel?.title
                self?.view.makeToast("Embedded Failed".localStr())
            }

        })
        
        action1.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
    }
    
    private func editArtistAction() {
        
        guard let oldModel = self.origialModel, let tempURL = self.origialModel?.localFullFilePath() else { return }
        guard let editModel = self.editModel else { return }

        let editAlertVC = UIAlertController(title: MusicActionType.editArtName.formatStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            textView.text = (editModel.artist?.count ?? 0 > 0) ? editModel.artist : oldModel.artist
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Done".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, var nameText = nameField.text, nameText.count > 0 else {
                return
            }
            
            let baseFileURL: URL = tempURL.deletingLastPathComponent()
            nameText = nameText.replaceChar(oldChar: "/", newChar: "|")
            
            var editModel = oldModel
            editModel.artist = nameText
            
            let targetFilePath = SandboxFileManager.shared.updateArtistTag(model: oldModel, folderURL: baseFileURL, artist: nameText)
            if let _ = targetFilePath {
                self?.onEditCallback?(editModel)
                self?.origialModel?.artist = nameText
                if editModel.handleType != .link {
                    self?.origialModel?.originalFilePath = baseFileURL.path.ocString.appendingPathComponent(editModel.filePathName() + editModel.addPathExtension())
                }
                self?.refreshDataAction()
                self?.view.makeToast("Embedded Success".localStr())
            }else{
                self?.editModel?.artist = self?.origialModel?.artist
                self?.view.makeToast("Embedded Failed".localStr())
            }
            
        })
        
        action1.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
    }
    
    private func editAlbumNameAction() {
        guard var oldModel = self.origialModel, let tempURL = self.origialModel?.localFullFilePath() else { return }
        guard let editModel = self.editModel else { return }

        let editAlertVC = UIAlertController(title: MusicActionType.editAlbumName.formatStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            textView.text = (editModel.album?.count ?? 0 > 0) ? editModel.album : self.origialModel?.album
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Done".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, let nameText = nameField.text, nameText.count > 0 else {
                return
            }
            
            oldModel.album = nameText
            
            let success = TaglibMetadataParser.setAlbum(nameText, toFileURL: tempURL)
            if success {
                self?.onEditCallback?(oldModel)
                self?.refreshDataAction()
                self?.view.makeToast("Embedded Success".localStr())
            }else{
                self?.view.makeToast("Embedded Failed".localStr())
            }
            
        })
        
        action1.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
    }
    
    private func editYearAction() {
        
        guard var oldModel = self.origialModel, let tempURL = self.origialModel?.localFullFilePath() else { return }
        guard let editModel = self.editModel else { return }

        let editAlertVC = UIAlertController(title: "Year".localStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            let year = (editModel.year ?? 0 > 0) ? editModel.year : oldModel.year
            if let yearStr = year, yearStr > 0 {
                textView.text = "\(yearStr)"
            }
            
            textView.keyboardType = .numberPad
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Done".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, let nameText = Int(nameField.text ?? ""), nameText > 0 else {
                return
            }
            
            oldModel.year = nameText
            
            let success = TaglibMetadataParser.setYear(Int32(nameText), toFileURL: tempURL)
            if success {
                self?.onEditCallback?(oldModel)
                self?.refreshDataAction()
                self?.view.makeToast("Embedded Success".localStr())
            }else{
                self?.view.makeToast("Embedded Failed".localStr())
            }
            
        })
        
        action1.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
    }
    
    private func editTrackAction() {
        
        guard var oldModel = self.origialModel, let tempURL = self.origialModel?.localFullFilePath() else { return }
        guard let editModel = self.editModel else { return }

        let editAlertVC = UIAlertController(title: "Track".localStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            let track = (editModel.track ?? 0 > 0) ? editModel.track : oldModel.track
            if let trackStr = track, trackStr > 0 {
                textView.text = "\(trackStr)"
            }
            
            textView.keyboardType = .numberPad
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Done".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, let nameText = Int(nameField.text ?? ""), nameText > 0 else {
                return
            }
            
            oldModel.track = nameText
            
            let success = TaglibMetadataParser.setTrack(Int32(nameText), toFileURL: tempURL)
            if success {
                self?.onEditCallback?(oldModel)
                self?.refreshDataAction()
                self?.view.makeToast("Embedded Success".localStr())
            }else{
                self?.view.makeToast("Embedded Failed".localStr())
            }
            
        })
        
        action1.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
    }
    
    private func editCommentAction() {
        
        guard var oldModel = self.origialModel, let tempURL = self.origialModel?.localFullFilePath() else { return }
        guard let editModel = self.editModel else { return }

        let editAlertVC = UIAlertController(title: "Comment".localStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            textView.text = editModel.comment
            
            textView.keyboardType = .default
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Done".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, let nameText = nameField.text else {
                return
            }
            
            oldModel.comment = nameText
            
            let success = TaglibMetadataParser.setComment(nameText, toFileURL: oldModel.localFullFilePath())
            if success {
                self?.onEditCallback?(oldModel)
                self?.refreshDataAction()
                self?.view.makeToast("Embedded Success".localStr())
            }else{
                self?.view.makeToast("Embedded Failed".localStr())
            }
            
        })
        
        action1.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
    }
    
}

class MeteDataDetialViewCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .default
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    func update(model: MusicItemModel?, itemType: MeteDataCellItemType, coverImage: UIImage?, fileSize: String) {
        var cellConfig = UIListContentConfiguration.cell()
        cellConfig.prefersSideBySideTextAndSecondaryText = true
        cellConfig.text = itemType.titleStr()
        
        switch itemType {
        case .headerTag: break
        case .coverImage:
            coverImgView.image = coverImage ?? UIImage(named: "music_place")
            self.accessoryView = self.coverImgView
            self.accessoryType = .none
            break
        case .lyrics:
            let isNoneLyrics = (model?.lyricModel?.lyrics == nil) || (model?.lyricModel?.lyrics?.count == 0)
            self.accessoryView = self.lyricIconView(isNoneLyrics)
            self.accessoryType = .none
            break
        case .title:
            cellConfig.secondaryText = model?.title ?? ""
            self.accessoryView = nil
            self.accessoryType = .disclosureIndicator
            break
        case .artist:
            cellConfig.secondaryText = model?.artist ?? ""
            self.accessoryView = nil
            self.accessoryType = .disclosureIndicator
            break
        case .album:
            cellConfig.secondaryText = model?.album ?? ""
            self.accessoryView = nil
            self.accessoryType = .disclosureIndicator
            break
        case .track:
            cellConfig.secondaryText = (model?.track ?? 0) > 0 ? "\(model?.track ?? 0)" : ""
            self.accessoryView = nil
            self.accessoryType = .disclosureIndicator
            break
        case .comment:
            cellConfig.secondaryText = model?.comment ?? ""
            self.accessoryView = nil
            self.accessoryType = .disclosureIndicator
            break
        case .fileName:
            cellConfig.secondaryText = model?.localFullFilePath().lastPathComponent
            self.accessoryView = nil
            self.accessoryType = .none
            break
        case .fileSize:
            cellConfig.secondaryText = fileSize
            self.accessoryView = nil
            self.accessoryType = .none
            break
        case .fileExtension:
            cellConfig.secondaryText = model?.localFullFilePath().pathExtension.uppercased()
            self.accessoryView = nil
            self.accessoryType = .none
            break
        case .filePath:
            if #available(iOS 16.0, *) {
                cellConfig.secondaryText = model?.localFullFilePath().path(percentEncoded: false)
            }else{
                cellConfig.secondaryText = model?.localFullFilePath().path
            }
            self.accessoryView = nil
            self.accessoryType = kaka_IsMacOS() ? .disclosureIndicator : .none
            break
            
        case .bitRate:
            var bitrateStr: String = ""

            if let bitrate = model?.bitrate {
                if bitrate >= 1000 {
                    let bitrateInKbps = Double(bitrate) / 1000.0

                    if bitrateInKbps.truncatingRemainder(dividingBy: 1) == 0 {
                        bitrateStr = String(format: "%.0f kbps", bitrateInKbps)
                    } else {
                        bitrateStr = String(format: "%.1f kbps", bitrateInKbps)
                    }

                }else{
                    bitrateStr = String(format: "%.0f bps", Double(bitrate))
                }
            }else{
                bitrateStr = String(format: "%.0f bps", Double(model?.bitrate ?? 0))
            }
            
            cellConfig.secondaryText = bitrateStr
            
            self.accessoryView = nil
            self.accessoryType = .none
            break
        case .samples:
            var sampleRateStr: String = ""
            if let sampleRate = model?.sampleRate, sampleRate >= 1000 {
                let sampleRateInKbps = Double(sampleRate) / 1000.0
                
                if sampleRateInKbps.truncatingRemainder(dividingBy: 1) == 0 {
                    sampleRateStr = String(format: "%.0f kHz", sampleRateInKbps)
                } else {
                    sampleRateStr = String(format: "%.1f kHz", sampleRateInKbps)
                }
                
            }else{
                sampleRateStr = String(format: "%.0f Hz", Double(model?.sampleRate ?? 0))
            }
            
            cellConfig.secondaryText = sampleRateStr
            
            self.accessoryView = nil
            self.accessoryType = .none
            break
        case .channel:
            cellConfig.secondaryText = model?.channel?.formatStr()
            self.accessoryView = nil
            self.accessoryType = .none
            break
        case .genre:
            if let genreType = model?.musicGenreType() {
                cellConfig.secondaryText = genreType.formatStr()
            }else{
                cellConfig.secondaryText = model?.genre ?? ""
            }
            self.accessoryView = nil
            self.accessoryType = .disclosureIndicator
            break
        case .year:
            cellConfig.secondaryText = ((model?.year ?? 0) > 1) ? "\(model?.year ?? 0)" : ""
            self.accessoryView = nil
            self.accessoryType = .disclosureIndicator
            break
        case .export:
            break
        }
        cellConfig.prefersSideBySideTextAndSecondaryText = true
        cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: self.accessoryType == .disclosureIndicator ? 5 : 15)
        self.contentConfiguration = cellConfig
    }
    
    lazy var coverImgView: UIImageView = {
        let view = UIImageView(frame: CGRectMake(0, 0, 60.ckValue(), 60.ckValue()))
        view.contentMode = .scaleAspectFill
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 6.ckValue()
        view.clipsToBounds = true
        view.isUserInteractionEnabled = true
        let clickTap = UITapGestureRecognizer(target: self, action: #selector(coverImgViewClick))
        view.addGestureRecognizer(clickTap)
        return view
    }()
    
    func lyricIconView(_ isNoneLyric: Bool) -> UIImageView {
        let view = UIImageView(image: isNoneLyric ? Reasource.systemNamed("exclamationmark.circle.fill", color: UIColor.accent) : Reasource.systemNamed("checkmark.circle.fill", color: UIColor.systemGreen))
        view.size = CGSize(width: 20.ckValue(), height: 20.ckValue())
        view.contentMode = .scaleAspectFit
        return view
    }
    
    @objc func coverImgViewClick() {
        guard let curVC = self.currentViewController() else { return }
        let photoItem = KakaPhotoItem(sourceView: self.coverImgView, image: self.coverImgView.image)
        let photoBrowser = KakaPhotoBrowser(photoItems: [photoItem], selectedIndex: 0)
        photoBrowser.backgroundStyle = .blurPhoto
        photoBrowser.show(from: curVC)
    }
}


class MusicTagHeadCell: UITableViewCell {
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.preSetupSubViews()
        self.preSetupContains()
        self.preSetupHandleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func preSetupSubViews() {
        self.addSubview(starImgView)
    }
    
    private func preSetupContains() {
        
        let value = starImgView.image!.size.width / starImgView.image!.size.height
        starImgView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.height.equalTo(self.starSize)
            make.width.equalTo(starImgView.snp.height).multipliedBy(value)
            make.bottom.equalToSuperview()
        }
        
    }
    
    var starSize: CGFloat {
        get {
            switch kaka_osType() {
            case .iOS: return 120
            case .iPadOS: return 200
            case .macOS: return 120
            }
        }
    }
    
    
    private func preSetupHandleBuness() {
        self.backgroundColor = .clear
        self.selectionStyle = .none
        self.accessoryType = .none
    }
    
    lazy var starImgView: UIImageView = {
        let view = UIImageView(image: UIImage(systemName: "tag.fill"))
        view.contentMode = .scaleAspectFit
        return view
    }()
    
}


