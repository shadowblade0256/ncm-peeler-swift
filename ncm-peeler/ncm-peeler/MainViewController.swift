//
//  MainViewController.swift
//  ncm-peeler
//
//  Created by yuxiqian on 2018/9/3.
//  Copyright © 2018 yuxiqian. All rights reserved.
//

import Cocoa
import CryptoSwift

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
        var headerBuf: [UInt8] = [UInt8](repeating: 0, count: 8)
        stream.open()
        do {
            let length = stream.read(&headerBuf, maxLength: headerBuf.count)
            for i in 0..<length {
                if headerBuf[i] != standardHead[i] {
                    showErrorMessage(errorMsg: "貌似不是正确的 ncm 格式文件？")
                    stream.close()
                    return
                }
            }
            print("file head matched.")
            
            var tmp: [UInt8] = [UInt8](repeating: 0, count: 2)
            stream.read(&tmp, maxLength: tmp.count)
            // 向后读两个字节但是啥也不干
            // 两个字节 = 两个 UInt8
            tmp.removeAll()
            
            var keyLenBuf: [UInt8] = [UInt8](repeating: 0, count: 4)
            // 4 个 UInt8 充 UInt32
            stream.read(&keyLenBuf, maxLength: keyLenBuf.count)

            let keyLen: UInt32 = fourUInt8Combine(&keyLenBuf)
            
            var keyData: [UInt8] = [UInt8](repeating: 0, count: Int(keyLen))
            let keyLength = stream.read(&keyData, maxLength: keyData.count)
            for i in 0..<keyLength {
                keyData[i] ^= 0x64
            }
//            var deKeyLen: Int = 0
            var deKeyData: [UInt8] = [UInt8](repeating: 0, count: Int(keyLen))

            deKeyData = try AES(key: aesCoreKey,
                                blockMode: ECB(),
                                padding: .pkcs7).decrypt(keyData)
            
            var uLenBuf: [UInt8] = [UInt8](repeating: 0, count: 4)
            // 4 个 UInt8 充 UInt32
            stream.read(&uLenBuf, maxLength: uLenBuf.count)
            let uLen: UInt32 = fourUInt8Combine(&uLenBuf)
            var modifyDataAsUInt8: [UInt8] = [UInt8](repeating: 0, count: Int(uLen))
            stream.read(&modifyDataAsUInt8, maxLength: Int(uLen))
            for i in 0..<Int(uLen) {
                modifyDataAsUInt8[i] ^= 0x63
            }
            var dataLen: Int
            var data: [CChar] = []
            var intData: [UInt8] = []
            var deData: [UInt8] = []
            
            var artistLen: Int
            let dataPart = Array(modifyDataAsUInt8[22..<Int(uLen)])
            dataLen = dataPart.count
//            data = (dataPart.toBase64()?.cString(using: .ascii))!
            let decodedData = NSData(base64Encoded: NSData(bytes: dataPart,
                                                                   length: dataLen) as Data,
                                     options: NSData.Base64DecodingOptions.init(rawValue: 0)
                                     )
            
            deData = try AES(key: aesModifyKey, blockMode: ECB()).decrypt([UInt8](decodedData! as Data))
            dataLen = deData.count

            for i in 0..<(dataLen - 6) {
                deData[i] = deData[i + 6]
            }
            deData[dataLen - 6] = 0
            // 写文件结束符
            let musicInfo = String(cString: &deData)
            print(musicInfo)
        } catch {
            print("Error")
        }
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

