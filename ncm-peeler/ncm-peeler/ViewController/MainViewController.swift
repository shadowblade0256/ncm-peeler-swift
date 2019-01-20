//
//  MainViewController.swift
//  ncm-peeler
//
//  Created by yuxiqian on 2018/9/3.
//  Copyright © 2018 yuxiqian. All rights reserved.
//

import Cocoa
import SwiftyJSON
import ID3TagEditor
import CryptoSwift

class MainViewController: NSViewController, dropFileDelegate {
    
    func onFileDrop(_ path: String) {
        let inputStream = InputStream(fileAtPath: path)
        DispatchQueue.main.async {
            self.clearUI()
            self.globalInStream = inputStream
            print(path)
            print(self.startAnalyse(inStream: inputStream!, path: path) ?? "analyse returned nil")
        }
    }
    
    func openBatch(_ array: NSArray) {
        let infoAlert: NSAlert = NSAlert()
        infoAlert.messageText = "一共选中了 \(array.count) 个文件。\n\n下面请选择批量输出目录。"
        infoAlert.alertStyle = NSAlert.Style.informational
        infoAlert.beginSheetModal(for: self.view.window!, completionHandler: { response in
            let openFolder = NSOpenPanel()
            openFolder.canChooseDirectories = true
            openFolder.beginSheetModal(for: self.view.window!, completionHandler: { returnCode in
                if returnCode == NSApplication.ModalResponse.OK {
                    DispatchQueue.global().async {
                        let target = openFolder.url
                        for i in array {
                            let inputStream = InputStream(fileAtPath: i as! String)
                            if let path = self.startAnalyse(inStream: inputStream!, path: target!.path, batch: true) {
                                print(path)
                                let outputStream = OutputStream(toFileAtPath: path,
                                                                append: false)
                                self.startOutputBatch(inStream: inputStream!, outStream: outputStream!, path: path)
                            }
                        }
                        DispatchQueue.main.async {
                            self.clearUI()
                        }
                    }
                }
            })
        })
    }
    

    override func viewDidLoad() {
        super.viewDidLoad()
        self.exportButton.isEnabled = false
        self.albumView.delegate = self
        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    
    @IBOutlet weak var titleTextField: NSTextField!
    @IBOutlet weak var artistTextField: NSTextField!
    @IBOutlet weak var albumTextField: NSTextField!
    @IBOutlet weak var formatTextField: NSTextField!
    @IBOutlet weak var albumView: DragableButton!
    @IBOutlet weak var exportButton: NSButton!
    
    var readyFileType: MusicFormat = .unknown
    var globalInStream: InputStream?
    var keyBox: [UInt8] = []
    var crc32Check: Int = 0
    var canOutput: Bool = false
    var musicTag: ID3Tag?
    var globalMusicId: Int = 0
    var creditsWindowController: NSWindowController?
    
    @IBAction func openCredits(_ sender: NSButton) {
        let storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
        creditsWindowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "Credits Window Controller")) as? NSWindowController
        creditsWindowController?.showWindow(sender)
    }
    
    @IBAction func browseNcmFile(_ sender: NSButton) {
        let openNcmPanel = NSOpenPanel()
        openNcmPanel.allowsMultipleSelection = true
        openNcmPanel.allowedFileTypes = ["ncm"]
        openNcmPanel.directoryURL = nil
        openNcmPanel.beginSheetModal(for: self.view.window!, completionHandler: { returnCode in
            if returnCode == NSApplication.ModalResponse.OK {
                if openNcmPanel.urls.count == 1 {
                    let ncmUrl = openNcmPanel.url
                    let inputStream = InputStream(fileAtPath: ((ncmUrl?.path)!))
                    DispatchQueue.main.async {
                        self.clearUI()
                        self.globalInStream = inputStream
                        print((ncmUrl?.path)!)
                        print(self.startAnalyse(inStream: inputStream!) ?? "analyse returned nil")
                    }
                } else if openNcmPanel.urls.count > 1 {
                    var paths: NSArray = []
                    for url in openNcmPanel.urls {
                        paths = paths.adding(url.path) as NSArray
                    }
                    self.openBatch(paths)
                }
            }
        })
    }
    
    
    
    @IBAction func exportFile(_ sender: NSButton) {
        let savePanel = NSSavePanel()
        switch self.readyFileType {
        case .mp3:
            savePanel.allowedFileTypes = ["mp3"]
            break
        case .flac:
            savePanel.allowedFileTypes = ["flac"]
            break
        default:
            break
        }
        savePanel.nameFieldStringValue = "\(musicTag?.artist ?? "Artist") - \(musicTag?.title ?? "Title")"
        savePanel.beginSheetModal(for: self.view.window!, completionHandler: { returnCode in
            if returnCode == NSApplication.ModalResponse.OK {
                self.exportButton.isEnabled = false
                let saveUrl = savePanel.url
                let outputStream = OutputStream(toFileAtPath: (saveUrl?.path)!, append: false)
                DispatchQueue.global().async {
                    if self.globalInStream != nil {
                        let outputPath = saveUrl?.path
                        print("准备输出到：\(outputPath ?? "bad path")")
                        self.startOutput(inStream: self.globalInStream!,
                                         outStream: outputStream!,
                                         path: outputPath!)
                    }
                }
            }
        })
    }
    
    
    @IBAction func tappedAlbum(_ sender: NSButton) {
//        print("tapped")
        if self.globalMusicId != 0 {
            if let url = URL(string: "https://music.163.com/#/song?id=\(globalMusicId)"), NSWorkspace.shared.open(url) {
                // 成功打开
            }
        } else {
            browseNcmFile(sender)
        }
    }
    
    func startAnalyse(inStream: InputStream, path: String = "/", batch: Bool = false) -> String? {
        var headerBuf: [UInt8] = []
        var tmpBuf: [UInt8] = []
        var keyLenBuf: [UInt8] = []
        var keyData: [UInt8] = []
        var deKeyData: [UInt8] = []
        var uLenBuf: [UInt8] = []
        var metaData: [UInt8] = []
        var crc32CheckBuf: [UInt8] = []
        var imageSizeBuf: [UInt8] = []
        
        inStream.open()
        do {
            headerBuf = [UInt8](repeating: 0, count: 8)
            let length = inStream.read(&headerBuf, maxLength: headerBuf.count)
            for i in 0..<length {
                if headerBuf[i] != standardHead[i] {
                    showErrorMessage(errorMsg: "貌似不是正确的 ncm 格式文件？")
                    inStream.close()
                    self.clearUI()
                    return nil
                }
            }
            print("file head matched.")
            
            tmpBuf = [UInt8](repeating: 0, count: 2)
            inStream.read(&tmpBuf, maxLength: tmpBuf.count)
            // 向后读两个字节但是啥也不干
            // 两个字节 = 两个 UInt8
            tmpBuf.removeAll()
            
            
            keyLenBuf = [UInt8](repeating: 0, count: 4)
            // 4 个 UInt8 充 UInt32
            inStream.read(&keyLenBuf, maxLength: keyLenBuf.count)

            let keyLen: UInt32 = fourUInt8Combine(&keyLenBuf)
            
            keyData = [UInt8](repeating: 0, count: Int(keyLen))
            let keyLength = inStream.read(&keyData, maxLength: keyData.count)
            for i in 0..<keyLength {
                keyData[i] ^= 0x64
            }
            
            
//            var deKeyLen: Int = 0
            deKeyData = [UInt8](repeating: 0, count: Int(keyLen))

            deKeyData = try AES(key: aesCoreKey,
                                blockMode: ECB(),
                                padding: .pkcs7).decrypt(keyData)
            
            uLenBuf = [UInt8](repeating: 0, count: 4)
            // 4 个 UInt8 充 UInt32
            inStream.read(&uLenBuf, maxLength: uLenBuf.count)
            let uLen: UInt32 = fourUInt8Combine(&uLenBuf)
            var modifyDataAsUInt8: [UInt8] = [UInt8](repeating: 0, count: Int(uLen))
            inStream.read(&modifyDataAsUInt8, maxLength: Int(uLen))
            for i in 0..<Int(uLen) {
                modifyDataAsUInt8[i] ^= 0x63
            }
            
            
            var dataLen: Int
            
            let dataPart = Array(modifyDataAsUInt8[22..<Int(uLen)])
            dataLen = dataPart.count
//            data = (dataPart.toBase64()?.cString(using: .ascii))!
            let decodedData = NSData(base64Encoded: NSData(bytes: dataPart,
                                                                   length: dataLen) as Data,
                                     options: NSData.Base64DecodingOptions.init(rawValue: 0)
                                     )
            
            metaData = try AES(key: aesModifyKey, blockMode: ECB()).decrypt([UInt8](decodedData! as Data))
            dataLen = metaData.count
            for i in 0..<(dataLen - 6) {
                metaData[i] = metaData[i + 6]
            }
            metaData[dataLen - 6] = 0
            // 手动写 C 字符串结束符 \0
            
        } catch {
            showErrorMessage(errorMsg: "读取数据失败。")
            self.clearUI()
            return nil
        }
        
        
//        var musicName: String = ""
//        var albumName: String = ""
//        var albumImageLink: String = ""
//        var artistNameArray: [String] = []
//        var musicFormat: MusicFormat
//        var musicId: Int = 0
//        var duration: Int = 0
//        var bitRate: Int = 0
//
        let music = Music()
        
        do {
            let musicInfo = String(cString: &metaData)
            print(musicInfo)
            let musicMeta = try JSON(data: musicInfo.data(using: .utf8)!)
            music.title = musicMeta["musicName"].stringValue
            music.album = musicMeta["album"].stringValue
            music.duration = musicMeta["duration"].intValue
            music.albumCoverLink = musicMeta["albumPic"].stringValue
            music.bitRate = musicMeta["bitrate"].intValue
            music.musicId = musicMeta["musicId"].intValue
            switch musicMeta["format"].stringValue {
            case "mp3":
                music.format = .mp3
                break
            case "flac":
                music.format = .flac
                break
            default:
                music.format = .unknown
                break
            }
            self.readyFileType = music.format
            if let artistArray = musicMeta["artist"].array {
                for index in 0..<artistArray.count {
                    music.artists.append(artistArray[index][0].stringValue)
                }
            }
            
            if let aliasNames = musicMeta["alias"].array {
                for index in 0..<aliasNames.count {
                    music.aliasNames.append(aliasNames[index].stringValue)
                }
            }
            
            if let transNames = musicMeta["transNames"].array {
                for index in 0..<transNames.count {
                    music.aliasNames.append(transNames[index].stringValue)
                }
            }
            
        } catch {
            showErrorMessage(errorMsg: "文件元数据解析失败。")
            self.clearUI()
            return nil
        }

        if !batch {
            DispatchQueue.global().async {
                // 新开一个线程读图片
                do {
                    let image = try NSImage(data: Data(contentsOf: URL(string: music.albumCoverLink)!))
                    DispatchQueue.main.async {
                        music.albumCover = image
                        self.albumView.image = image
                        self.albumView.title = ""
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.showInfo(infoMsg: "未能加载服务器端的专辑封面。\n\n将会使用 ncm 文件内嵌的专辑封面。")
                        // 其实两个没啥区别…
                    }
                }
            }
        } else {
            do {
                let image = try NSImage(data: Data(contentsOf: URL(string: music.albumCoverLink)!))
                DispatchQueue.main.async {
                    music.albumCover = image
                    self.albumView.image = image
                    self.albumView.title = ""
                }
            } catch {
                print("未能加载服务器端的专辑封面。\n\n将会使用 ncm 文件内嵌的专辑封面。")
                    // 其实两个没啥区别…
            }
        }
        
        DispatchQueue.main.async {
            self.titleTextField.stringValue = "\(music.title)"
            if music.aliasNames.count > 1 {
                self.titleTextField.stringValue += " (\(music.aliasNames.joined(separator: "/")))"
            } else if music.aliasNames.count == 1 {
                self.titleTextField.stringValue += " (\(music.aliasNames[0]))"
            }
            self.albumTextField.stringValue = "专辑：\(music.album)"
            self.artistTextField.stringValue = "艺术家：\(music.artists.joined(separator: "/"))"
            self.formatTextField.stringValue = "格式：\(getFormat(music.format, music.bitRate, music.duration))"
        }

        
        // 继续往下读 CRC32 校验和
        crc32CheckBuf = [UInt8](repeating: 0, count: 4)
        inStream.read(&crc32CheckBuf, maxLength: crc32CheckBuf.count)
        self.crc32Check = Int(fourUInt8Combine(&crc32CheckBuf))
        
        tmpBuf = [UInt8](repeating: 0, count: 5)
        inStream.read(&tmpBuf, maxLength: tmpBuf.count)
        // 向后读 5 个字节，读完就丢
        // 充当了 C 里面的 f.seek...
        tmpBuf.removeAll()
        
        // JSON 里嵌入了专辑封面的 url
        // ncm 里面也嵌入了图片文件…
        // 要是没读出来呢？
        // 读本地的
        
        imageSizeBuf = [UInt8](repeating: 0, count: 4)
        inStream.read(&imageSizeBuf, maxLength: imageSizeBuf.count)
        let imageSize: UInt32 = fourUInt8Combine(&imageSizeBuf)
        var imageData = [UInt8](repeating: 0, count: Int(imageSize))
        inStream.read(&imageData, maxLength: Int(imageSize))
        
        // 就算决定不用本地的版本
        // 也还是要 read 出来这么多字节
        // 否则后面没法继续
        if music.albumCover == nil {
            music.albumCover = NSImage(data: Data(bytes: imageData))
            DispatchQueue.main.async {
                self.albumView.image = music.albumCover
                self.albumView.title = ""
            }
        }
        
        let id3Tag = music.getTag()
        self.musicTag = id3Tag
        self.globalMusicId = music.musicId
        
        let realDeKeyData = Array(deKeyData[17..<(deKeyData.count)])
        // 从第 17 位开始取 deKeyData
        // 创建新的 realDeKeyData 并用它生成 keyBox
        self.keyBox = buildKeyBox(key: realDeKeyData)
        if !batch {
            self.exportButton.isEnabled = true
        }
        return path + "\(music.generateFileName())"
    }

    func startOutput(inStream: InputStream, outStream: OutputStream, path: String) {
        outStream.open()
        let bufSize = 0x8000
        var buffer: [UInt8] = [UInt8](repeating: 0, count: bufSize)
        while inStream.hasBytesAvailable {
            inStream.read(&buffer, maxLength: bufSize)
            for i in 0..<bufSize {
                let j = (i + 1) & 0xff;
                buffer[i] ^= keyBox[Int((keyBox[j] &+ keyBox[Int((keyBox[j] &+ UInt8(j)) & 0xff)]) & 0xff)]
            }
            outStream.write(&buffer, maxLength: bufSize)
        }
        inStream.close()
        outStream.close()
        writeMetaInfo(path)
        DispatchQueue.main.async {
            self.showInfo(infoMsg: "成功输出文件到 \(path)。\n\n校验和：\(self.crc32Check)。")
            // 其实也不知道这个校验码有啥用……跟生成的文件 crc32 并不匹配
            self.clearUI()
        }
    }
    
    func startOutputBatch(inStream: InputStream, outStream: OutputStream, path: String) {
        outStream.open()
        let bufSize = 0x8000
        var buffer: [UInt8] = [UInt8](repeating: 0, count: bufSize)
        while inStream.hasBytesAvailable {
            inStream.read(&buffer, maxLength: bufSize)
            for i in 0..<bufSize {
                let j = (i + 1) & 0xff;
                buffer[i] ^= keyBox[Int((keyBox[j] &+ keyBox[Int((keyBox[j] &+ UInt8(j)) & 0xff)]) & 0xff)]
            }
            outStream.write(&buffer, maxLength: bufSize)
        }
        inStream.close()
        outStream.close()
        writeMetaInfo(path)
    }
    
    func writeMetaInfo(_ filePath: String) {
        if musicTag != nil {
            do {
                let id3TagEditor = ID3TagEditor()
                try id3TagEditor.write(tag: self.musicTag!, to: filePath)
            } catch {
//                showErrorMessage(errorMsg: "未能成功写入元数据信息。")
//                flac 格式没办法写 tag 信息……
            }
        }
    }
    
    func showErrorMessage(errorMsg: String) {
        let errorAlert: NSAlert = NSAlert()
        errorAlert.messageText = errorMsg
        errorAlert.alertStyle = NSAlert.Style.critical
        errorAlert.beginSheetModal(for: self.view.window!, completionHandler: nil)
    }
    
    func showInfo(infoMsg: String) {
        let infoAlert: NSAlert = NSAlert()
        infoAlert.messageText = infoMsg
        infoAlert.alertStyle = NSAlert.Style.informational
        infoAlert.beginSheetModal(for: self.view.window!, completionHandler: nil)
    }
    
    func askQuestion(question: String) -> Bool {
        let questionAlert: NSAlert = NSAlert()
        questionAlert.messageText = question
        questionAlert.alertStyle = NSAlert.Style.critical
        questionAlert.addButton(withTitle: "替换")
        questionAlert.addButton(withTitle: "取消")
        return questionAlert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn
    }
    
    func clearUI() {
        
        self.titleTextField.stringValue = "本程序可以将 ncm 格式"
        self.artistTextField.stringValue = "转化为 mp3 或 flac 格式。"
        self.albumTextField.stringValue = "（网易云音乐加密格式）"
        self.formatTextField.stringValue = "元数据会得到保留。"
        self.albumView.title = "…或者拖放到这里。"
        self.albumView.image = nil
        self.exportButton.isEnabled = false
        self.globalMusicId = 0
        self.readyFileType = .unknown
        self.globalInStream = nil
        self.keyBox = []
        self.crc32Check = 0
        self.canOutput = false
    }
    
    
}
