//
//  BatchViewController.swift
//  ncm-peeler
//
//  Created by yuxiqian on 2019/1/20.
//  Copyright © 2019 yuxiqian. All rights reserved.
//

import Cocoa

class BatchViewController: NSViewController, dropFileDelegate {
    
    func onFileDrop(_ path: String) {
        var successCount = 0
        let openSession = Session(ncmPath: path)
        if openSession.isOk {
            if !self.batchDataList.contains(where: { (element) -> Bool in
                if element.filePath == path {
                    return true
                }
                return false
            }) {
                self.batchDataList.append(openSession)
                successCount += 1
            }
        }
        if successCount != 0 {
            self.reloadBatchData()
            self.promptText.stringValue = "已经导入 \(successCount) 则待处理文件。"
        } else {
            self.promptText.stringValue = "未导入任何文件。"
        }
        updateStatus()
    }
    
    func openBatch(_ array: NSArray) {
        var successCount = 0
        for p in array {
            let path = p as! String
            let openSession = Session(ncmPath: path)
            if openSession.isOk {
                if !self.batchDataList.contains(where: { (element) -> Bool in
                    if element.filePath == path {
                        return true
                    }
                    return false
                }) {
                    self.batchDataList.append(openSession)
                    successCount += 1
                }
            }
        }
        if successCount != 0 {
            self.reloadBatchData()
            self.promptText.stringValue = "已经导入 \(successCount) 则待处理文件。"
        } else {
            self.promptText.stringValue = "未导入任何文件。"
        }
        updateStatus()
    }
    

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        dragTarget.delegate = self
        
        self.removeButton.isEnabled = false
        self.clearButton.isEnabled = false
        self.startBatchButton.isEnabled = false
        self.pathController.isEnabled = false
        
        dataTableView.delegate = self
        dataTableView.dataSource = self
        dataTableView.target = self
        dataTableView.doubleAction = #selector(tableViewDoubleClick(_:))
        
        let descriptorName = NSSortDescriptor(key: "ByName", ascending: true)
        let descriptorArtist = NSSortDescriptor(key: "ByArtist", ascending: true)
        let descriptorDuration = NSSortDescriptor(key: "ByDuration", ascending: true)
        let descriptorFormat = NSSortDescriptor(key: "ByFormat", ascending: true)
        let descriptorPath = NSSortDescriptor(key: "ByPath", ascending: true)

        dataTableView.tableColumns[0].sortDescriptorPrototype = descriptorName
        dataTableView.tableColumns[1].sortDescriptorPrototype = descriptorArtist
        dataTableView.tableColumns[2].sortDescriptorPrototype = descriptorDuration
        dataTableView.tableColumns[3].sortDescriptorPrototype = descriptorFormat
        dataTableView.tableColumns[4].sortDescriptorPrototype = descriptorPath
        
    }
    
    
    @IBOutlet weak var promptText: NSTextField!
    @IBOutlet weak var dataTableView: NSTableView!
    @IBOutlet weak var addButton: NSButton!
    @IBOutlet weak var removeButton: NSButton!
    @IBOutlet weak var startBatchButton: NSButton!
    @IBOutlet weak var clearButton: NSButton!
    @IBOutlet weak var dragTarget: DraggableButton!
    
    @IBOutlet weak var pathController: NSPathControl!
    @IBOutlet weak var putOriginChecker: NSButton!
    @IBOutlet weak var removeThenChecker: NSButton!
    
    var outputPath: String?
    
    var shouldRemoveFile: Bool = false
    
    var loadingWC: NSWindowController?
    
    var buttonTapCount: Int = 0
    
    var creditsWindowController: NSWindowController?
    
    @IBAction func triggerLegacy(_ sender: NSButton) {
        if (buttonTapCount == 5) {
            let storyboard = NSStoryboard(name: "Main", bundle: nil)
            creditsWindowController = storyboard.instantiateController(withIdentifier: "LegacyWindowController") as? NSWindowController
            creditsWindowController?.showWindow(sender)
            
            buttonTapCount = 0
        }
        else {
            buttonTapCount += 1
        }
    }
    
    @IBAction func selectorClicked(_ sender: NSPathControl) {
        let openFolder = NSOpenPanel()
        openFolder.canChooseDirectories = true
        openFolder.canChooseFiles = false
        openFolder.beginSheetModal(for: self.view.window!, completionHandler: { returnCode in
            if returnCode == NSApplication.ModalResponse.OK {
                sender.url = openFolder.url
                NSLog("Opened folder \(String(describing: openFolder.url?.path))")
                self.outputPath = openFolder.url?.path
            }
        })
    }
    
    @IBAction func selectAllChecked(_ sender: NSMenuItem) {
        dataTableView.selectAll(sender)
    }
    
    @IBAction func deselectAllChecked(_ sender: NSMenuItem) {
        dataTableView.deselectAll(sender)
    }
    

    @IBAction func removeSelected(_ sender: NSMenuItem) {
        removeButtonClicked(removeButton)
    }
    
    @IBAction func putOriginCheckerChecked(_ sender: NSButton) {
        pathController.isEnabled = (sender.state == .off)
    }
    
    @IBAction func shouldDeleteCheckerChecked(_ sender: NSButton) {
        self.shouldRemoveFile = (sender.state == .on)
    }
    
    @IBAction func addButtonClicked(_ sender: NSButton) {
        let openNcmPanel = NSOpenPanel()
        openNcmPanel.allowsMultipleSelection = true
        openNcmPanel.allowedFileTypes = ["ncm"]
        openNcmPanel.directoryURL = nil
        openNcmPanel.beginSheetModal(for: self.view.window!, completionHandler: { returnCode in
            if returnCode == NSApplication.ModalResponse.OK {
                var successCount = 0
                for url in openNcmPanel.urls {
                    let openSession = Session(ncmPath: url.path)
                    if openSession.isOk {
                        if !self.batchDataList.contains(where: { (element) -> Bool in
                            if element.filePath == url.path {
                                return true
                            }
                            return false
                    }) {
                            self.batchDataList.append(openSession)
                            successCount += 1
                        }
                    }
                }
                
                if successCount != 0 {
                    self.reloadBatchData()
                    self.promptText.stringValue = "已经导入 \(successCount) 则待处理文件。"
                } else {
                    self.promptText.stringValue = "未导入任何文件。"
                }
                self.updateStatus()
            }
        })
    }
    
    @IBAction func removeButtonClicked(_ sender: NSButton) {
        let itemsSelected = dataTableView.selectedRowIndexes
        
        var newBatchList: [Session] = []
        for i in 0..<batchDataList.count {
            if !itemsSelected.contains(i) {
                newBatchList.append(batchDataList[i])
            }
        }
        batchDataList = newBatchList
        reloadBatchData()
    }
    
    @IBAction func openCredits(_ sender: NSButton) {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        creditsWindowController = storyboard.instantiateController(withIdentifier: "Credits Window Controller") as? NSWindowController
        creditsWindowController?.showWindow(sender)
    }
    
    @IBAction func openGitHub(_ sender: NSButton) {
        if let url = URL(string: "https://github.com/yuxiqian/ncm-peeler-swift"), NSWorkspace.shared.open(url) {
            // 成功打开
        }
    }
    
    @IBAction func startBatchButtonClicked(_ sender: NSButton) {
        
        if self.outputPath == nil && self.putOriginChecker.state == .off {
            showErrorMessage(errorMsg: "请指定一个输出目录。")
            return
        }

        
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        loadingWC = storyboard.instantiateController(withIdentifier: "LoadingWindowController") as? NSWindowController

        self.view.window!.beginSheet(loadingWC!.window!, completionHandler: nil)
        
        
            self.promptText.stringValue = "准备开始 \(self.batchDataList.count) 例转换…"
            let shouldPutOrigin: Bool = (self.putOriginChecker.state == .on)
            for session in self.batchDataList {
                DispatchQueue.global().async {
                    if shouldPutOrigin {
                        let result = session.output(outputPath: session.getOriginOutputPath())
                            self.batchDataList.removeAll(where: { (element) -> Bool in
                                if element.filePath == session.filePath {
                                    return true
                                }
                                return false
                            })
                        DispatchQueue.main.async {
                            self.reloadBatchData()
                            if result {
                                self.promptText.stringValue = "成功转换「\(session.musicObject!.title)」。" + self.promptText.stringValue
                                if self.shouldRemoveFile {
                                    session.deleteFile()
                                }
                            } else {
                                self.promptText.stringValue = "未能转换「\(session.musicObject!.title)」。" + self.promptText.stringValue
                            }
                        }
                    } else {
                        let result: Bool?
                        if session.musicObject!.noMetaData {
                            result = session.output(outputPath: truncateFilePath(filePath: self.outputPath! + "/" + String((session.filePath?.split(separator: "/").last)!)))
                        } else {
                            result = session.output(outputPath: truncateFilePath(filePath: self.outputPath! + session.musicObject!.generateFileName()))
                        }
                        self.batchDataList.removeAll(where: { (element) -> Bool in
                            if element.filePath == session.filePath {
                                return true
                            }
                            return false
                        })
                        DispatchQueue.main.async {
                            self.reloadBatchData()
                            if result! {
                                self.promptText.stringValue = "成功转换「\(session.musicObject!.title)」。" + self.promptText.stringValue
                                if self.shouldRemoveFile {
                                    session.deleteFile()
                                }
                            } else {
                                self.promptText.stringValue = "未能转换「\(session.musicObject!.title)」。" + self.promptText.stringValue
                                
                            }
                        }
                    }
                    
                    if self.batchDataList.count == 0 {
                        DispatchQueue.main.async {
                            self.view.window?.endSheet(self.loadingWC!.window!)
                            self.loadingWC = nil
                        }
                    }
                }
        }
    }
    
    @IBAction func askWhy(_ sender: NSButton) {
        let errorAlert: NSAlert = NSAlert()
        errorAlert.messageText = "为什么部分音乐文件信息显示未知？"
        errorAlert.informativeText = "根据目前的网易云音乐下载策略，\n部分被缓存的的 FLAC 格式文件在生成 ncm 格式文件时会直接跳过元数据的写入。\n\n因此建议您在下载 ncm 格式文件之前，\n先进入设置/下载设置/清除缓存后再进行下载。"
        errorAlert.addButton(withTitle: "嗯")
        errorAlert.alertStyle = NSAlert.Style.critical
        errorAlert.beginSheetModal(for: self.view.window!, completionHandler: nil)
    }
    
    @IBAction func clearButtonClicked(_ sender: NSButton) {
        self.batchDataList.removeAll()
        reloadBatchData()
    }
    
    var batchDataList: [Session] = []
    
    func reloadBatchData() {
        self.dataTableView.reloadData()
        self.updateStatus()
    }

    func sortArray(_ sortKey: String, _ isAscend: Bool) {
        if (batchDataList.count <= 1) {
            return
        }
        var sortComment = "已按照"
        switch(sortKey) {
        case "ByName":
            DispatchQueue.global().async {
                self.batchDataList = self.batchDataList.sorted(by: { obj1, obj2 in (obj1.musicObject!.title.localizedStandardCompare(obj2.musicObject!.title) == ComparisonResult.orderedAscending) == isAscend
                })
            }
            sortComment += "名称"
            break
        case "ByArtist":
            DispatchQueue.global().async {
                self.batchDataList = self.batchDataList.sorted(by: { obj1, obj2 in (obj1.musicObject!.getArtist().localizedStandardCompare(obj2.musicObject!.getArtist()) == ComparisonResult.orderedAscending) == isAscend
                })
            }
            sortComment += "艺术家"
            break
        case "ByDuration":
            DispatchQueue.global().async {
                self.batchDataList = self.batchDataList.sorted(by: { obj1, obj2 in (obj1.musicObject!.getTime().localizedStandardCompare(obj2.musicObject!.getTime()) == ComparisonResult.orderedAscending) == isAscend
                })
            }
            sortComment += "时长"
            break
        case "ByFormat":
            DispatchQueue.global().async {
                self.batchDataList = self.batchDataList.sorted(by: { obj1, obj2 in (obj1.musicObject!.getBitRate().localizedStandardCompare(obj2.musicObject!.getBitRate()) == ComparisonResult.orderedAscending) == isAscend
                })
            }
            sortComment += "比特率"
            break
        case "ByPath":
            DispatchQueue.global().async {
                self.batchDataList = self.batchDataList.sorted(by: { obj1, obj2 in (obj1.filePath!.localizedStandardCompare(obj2.filePath!) == ComparisonResult.orderedAscending) == isAscend
                })
            }
            sortComment += "路径"
            break
        case "badSortArgument":
            return
        default:
            return
        }
        if (isAscend) {
            sortComment += "降序排序"
        } else {
            sortComment += "升序排序"
        }
        sortComment += "了 \(batchDataList.count) 项。"
        self.promptText.stringValue = sortComment
        self.reloadBatchData()
    }
    
    func updateStatus() {
        
        let text: String

        let itemsSelected = dataTableView.selectedRowIndexes.count
        
        if (batchDataList.count == 0) {
            text = "现在没有待处理文件。"
            self.removeButton.isEnabled = false
            self.clearButton.isEnabled = false
            self.startBatchButton.isEnabled = false
        }
        else if (itemsSelected == 0) {
            text = "现在有 \(batchDataList.count) 则文件待处理。"
            self.removeButton.isEnabled = false
            self.clearButton.isEnabled = true
            self.startBatchButton.isEnabled = true
        }
        else {
            text = "\(batchDataList.count) 则待处理文件之中的 \(itemsSelected) 则被选中。"
            self.removeButton.isEnabled = true
            self.clearButton.isEnabled = true
            self.startBatchButton.isEnabled = true
        }
       
        promptText.stringValue = text
    }
    
    
    func showErrorMessage(errorMsg: String) {
        DispatchQueue.main.async {
            let errorAlert: NSAlert = NSAlert()
            errorAlert.messageText = "出错啦"
            errorAlert.informativeText = errorMsg
            errorAlert.addButton(withTitle: "哦")
            errorAlert.alertStyle = NSAlert.Style.critical
            errorAlert.beginSheetModal(for: self.view.window!, completionHandler: nil)
        }
    }
    
    func showInfo(infoMsg: String) {
        DispatchQueue.main.async {
            let infoAlert: NSAlert = NSAlert()
            infoAlert.messageText = "提示"
            infoAlert.informativeText = infoMsg
            infoAlert.addButton(withTitle: "哦")
            infoAlert.alertStyle = NSAlert.Style.informational
            infoAlert.beginSheetModal(for: self.view.window!, completionHandler: nil)
        }
    }
}


extension BatchViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return batchDataList.count
    }
    
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        // 1
        guard let sortDescriptor = tableView.sortDescriptors.first else {
            return
        }
        
        sortArray(sortDescriptor.key ?? "badSortArgument", !sortDescriptor.ascending)
    }
    
}

extension BatchViewController: NSTableViewDelegate {
    
    fileprivate enum CellIdentifiers {
        static let NameCell = "NameCell"
        static let ArtistCell = "ArtistCell"
        static let DurationCell = "DurationCell"
        static let FormatCell = "FormatCell"
        static let PathCell = "PathCell"
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        var image: NSImage?
        var text: String = ""
        var cellIdentifier: String = ""
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .long
        
        // 获取 Session 对象
        let item = batchDataList[row]
        
        // 解析 Session 对象，把它打出来
        if tableColumn == tableView.tableColumns[0] {
            image = (item.musicObject?.albumCover) ?? nil
            text = (item.musicObject?.title) ?? "未知标题"
            if text == "" {
                text = "未知标题"
            }
            cellIdentifier = CellIdentifiers.NameCell
        } else if tableColumn == tableView.tableColumns[1] {
            text = item.musicObject?.artists.joined(separator: " / ") ?? "未知艺术家"
            if text == "" {
                text = "未知艺术家"
            }
            cellIdentifier = CellIdentifiers.ArtistCell
        } else if tableColumn == tableView.tableColumns[2] {
            text = item.musicObject?.getTime() ?? "未知时长"
            if text == "0:00" {
                text = "未知时长"
            }
            cellIdentifier = CellIdentifiers.DurationCell
        } else if tableColumn == tableView.tableColumns[3] {
            text = (item.musicObject?.format.rawValue ?? "未知格式") + "，" + (item.musicObject?.getBitRate() ?? "未知比特率")
            if text == "，0kbit/s" {
                text = "未知格式和比特率"
            }
            cellIdentifier = CellIdentifiers.FormatCell
        } else if tableColumn == tableView.tableColumns[4] {
            text = item.filePath ?? "未知路径"
            cellIdentifier = CellIdentifiers.PathCell
        }
        
        // Let's make view!
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = text
            cell.imageView?.image = image ?? nil
            return cell
        }
        return nil
    }
    
    @objc func tableViewDoubleClick(_ sender: AnyObject) {
        
        if dataTableView.selectedRow < 0 {
            return
        }
        
        let item = batchDataList[dataTableView.selectedRow]
        if let url = URL(string: "https://music.163.com/#/song?id=\(item.musicObject!.musicId)"), NSWorkspace.shared.open(url) {
            // 成功打开
        }
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        updateStatus()
    }
}

