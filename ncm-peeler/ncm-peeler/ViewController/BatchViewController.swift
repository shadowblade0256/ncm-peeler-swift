//
//  BatchViewController.swift
//  ncm-peeler
//
//  Created by yuxiqian on 2019/1/20.
//  Copyright © 2019 yuxiqian. All rights reserved.
//

import Cocoa

class BatchViewController: NSViewController, dropFileDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
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
    
    @IBOutlet weak var dataTableView: NSTableView!
    @IBOutlet weak var promptText: NSTextField!

    @IBOutlet weak var addButton: NSButton!
    @IBOutlet weak var removeButton: NSButton!
    @IBOutlet weak var startBatchButton: NSButton!
    @IBOutlet weak var clearButton: NSButton!
    
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
                    self.showInfo(infoMsg: "已经导入 \(successCount) 则待处理文件。")
                    self.promptText.stringValue = "已经导入 \(successCount) 则待处理文件。"
                    self.reloadBatchData()
                } else {
                    self.showInfo(infoMsg: "未导入任何文件。")
                    self.promptText.stringValue = "未导入任何文件。"
                }
            }
        })
    }
    
    @IBAction func removeButtonClicked(_ sender: NSButton) {
    }
    
    @IBAction func startBatchButtonClicked(_ sender: NSButton) {
    }
    
    @IBAction func clearButtonClicked(_ sender: NSButton) {
    }
    
    var batchDataList: [Session] = []
    
    func reloadBatchData() {
        self.dataTableView.reloadData()
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
            text = "目前没有待处理文件。"
        }
        else if (itemsSelected == 0) {
            text = "共有 \(batchDataList.count) 则待处理文件。"
        }
        else {
            text = "\(batchDataList.count) 则待处理文件之中的 \(itemsSelected) 则被选中。"
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
            cellIdentifier = CellIdentifiers.NameCell
        } else if tableColumn == tableView.tableColumns[1] {
            text = item.musicObject?.artists.joined(separator: " / ") ?? "未知艺术家"
            cellIdentifier = CellIdentifiers.ArtistCell
        } else if tableColumn == tableView.tableColumns[2] {
            text = item.musicObject?.getTime() ?? "未知时长"
            cellIdentifier = CellIdentifiers.DurationCell
        } else if tableColumn == tableView.tableColumns[3] {
            text = (item.musicObject?.format.rawValue ?? "未知格式") + "，" + (item.musicObject?.getBitRate() ?? "未知比特率")
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

