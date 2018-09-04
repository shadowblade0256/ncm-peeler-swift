//
//  MainViewController.swift
//  ncm-peeler
//
//  Created by yuxiqian on 2018/9/3.
//  Copyright © 2018 yuxiqian. All rights reserved.
//

import Cocoa
import CryptoSwift
import SwiftyJSON

class MainViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

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
    @IBOutlet weak var albumImageView: NSImageView!
    
    
    @IBAction func openCredits(_ sender: NSButton) {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let creditsWindowController = storyboard.instantiateController(withIdentifier: "Credits Window Controller") as! NSWindowController
        creditsWindowController.showWindow(sender)
    }
    
    @IBAction func browseNcmFile(_ sender: NSButton) {
        let openNcmPanel = NSOpenPanel()
        openNcmPanel.allowsMultipleSelection = false
        openNcmPanel.allowedFileTypes = ["ncm"]
        openNcmPanel.directoryURL = nil
        openNcmPanel.beginSheetModal(for: self.view.window!, completionHandler: { returnCode in
            if returnCode == NSApplication.ModalResponse.OK {
                let ncmUrl = openNcmPanel.url
                let inputStream = InputStream(fileAtPath: ((ncmUrl?.path)!))
                DispatchQueue.main.async {
                    print((ncmUrl?.path)!)
                    self.startAnalyse(stream: inputStream!)
                }
            }
        })
    }
    
    func startAnalyse(stream: InputStream) {
        var headerBuf: [UInt8] = []
        var tmpBuf: [UInt8] = []
        var keyLenBuf: [UInt8] = []
        var keyData: [UInt8] = []
        var deKeyData: [UInt8] = []
        var uLenBuf: [UInt8] = []
        var metaData: [UInt8] = []
        stream.open()
        do {
            headerBuf = [UInt8](repeating: 0, count: 8)
            let length = stream.read(&headerBuf, maxLength: headerBuf.count)
            for i in 0..<length {
                if headerBuf[i] != standardHead[i] {
                    showErrorMessage(errorMsg: "貌似不是正确的 ncm 格式文件？")
                    stream.close()
                    return
                }
            }
            print("file head matched.")
            
            tmpBuf = [UInt8](repeating: 0, count: 2)
            stream.read(&tmpBuf, maxLength: tmpBuf.count)
            // 向后读两个字节但是啥也不干
            // 两个字节 = 两个 UInt8
            tmpBuf.removeAll()
            
            keyLenBuf = [UInt8](repeating: 0, count: 4)
            // 4 个 UInt8 充 UInt32
            stream.read(&keyLenBuf, maxLength: keyLenBuf.count)

            let keyLen: UInt32 = fourUInt8Combine(&keyLenBuf)
            
            keyData = [UInt8](repeating: 0, count: Int(keyLen))
            let keyLength = stream.read(&keyData, maxLength: keyData.count)
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
            stream.read(&uLenBuf, maxLength: uLenBuf.count)
            let uLen: UInt32 = fourUInt8Combine(&uLenBuf)
            var modifyDataAsUInt8: [UInt8] = [UInt8](repeating: 0, count: Int(uLen))
            stream.read(&modifyDataAsUInt8, maxLength: Int(uLen))
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
            // 手动写 C 字符串结束符
        } catch {
            showErrorMessage(errorMsg: "读取数据失败。")
            return
        }
        var musicName: String = ""
        var albumName: String = ""
        var albumImageLink: String = ""
        var artistNameArray: [String] = []
        do {
            let musicInfo = String(cString: &metaData)
            print(musicInfo)
            let musicMeta = try JSON(data: musicInfo.data(using: .utf8)!)
            musicName = musicMeta["musicName"].stringValue
            albumName = musicMeta["album"].stringValue
            albumImageLink = musicMeta["albumPic"].stringValue
            if let artistArray = musicMeta["artist"].array {
                for index in 0..<artistArray.count {
                    artistNameArray.append(artistArray[index][0].stringValue)
                }
            }
        } catch {
            showErrorMessage(errorMsg: "文件元数据解析失败。")
            return
        }

        DispatchQueue.global().async {
            // 新开一个线程读图片
            do {
                let image = try NSImage(data: Data(contentsOf: URL(string: albumImageLink)!))
                DispatchQueue.main.async {
                    self.albumImageView.image = image
                }
            } catch {
                DispatchQueue.main.async {
                    self.showErrorMessage(errorMsg: "没获取专辑封面哦。")
                }
            }
        }
        
        self.titleTextField.stringValue = musicName
        self.albumTextField.stringValue = albumName
        self.artistTextField.stringValue = artistNameArray.joined(separator: "、")
        
        stream.close()
    }
    
    
    @IBAction func exportFile(_ sender: NSButton) {
        
    }
    
    func showErrorMessage(errorMsg: String) {
        let errorAlert: NSAlert = NSAlert()
        errorAlert.messageText = errorMsg
        errorAlert.alertStyle = NSAlert.Style.critical
        errorAlert.beginSheetModal(for: self.view.window!, completionHandler: nil)
    }
}

