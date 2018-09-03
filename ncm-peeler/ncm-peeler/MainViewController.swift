//
//  ViewController.swift
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
            
            var keyLenBuf: [UInt8] = [UInt8](repeating: 0, count: 4)
            // 4 个 UInt8 充 UInt32
            stream.read(&keyLenBuf, maxLength: keyLenBuf.count)
            let keyLen: UInt32 = keyLenBuf.map{UInt32($0)}.first!
            
            var keyData: [UInt8] = [UInt8](repeating: 0, count: Int(keyLen))
            let keyLength = stream.read(&keyData, maxLength: keyData.count)
            for i in 0..<keyLength {
                keyData[i] ^= 0x64
            }
//            var deKeyLen: Int = 0
            var deKeyData: [UInt8] = [UInt8](repeating: 0, count: Int(keyLen))

            let iv: [UInt8] = AES.randomIV(AES.blockSize)
            let aes = try AES(key: aesCoreKey, blockMode: CBC(iv: iv))
            deKeyData = try aes.decrypt(keyData)
            
            var uLenBuf: [UInt8] = [UInt8](repeating: 0, count: 4)
            // 4 个 UInt8 充 UInt32
            stream.read(&uLenBuf, maxLength: uLenBuf.count)
            let uLen: UInt32 = uLenBuf.map{UInt32($0)}.first!
            var modifyData: [char16_t] = []
            var modifyDataAsUInt8: [UInt8] = [UInt8](repeating: 0, count: Int(uLen) * 2)
            stream.read(&modifyDataAsUInt8, maxLength: Int(uLen) * 2)
            for i in 0..<Int(uLen) {
                let tempUInt8: [UInt8] = [modifyDataAsUInt8[i * 2] ^ 0x6,
                                          modifyDataAsUInt8[i * 2 + 1] ^ 0x3]
                modifyData.append(char16_t(tempUInt8.map{char16_t($0)}.first!))
            }
            var dataLen: Int
            
        } catch {
            // do nothing
        }
        stream.close()
    }
    
    func showErrorMessage(errorMsg: String) {
        let errorAlert: NSAlert = NSAlert()
        errorAlert.messageText = errorMsg
        errorAlert.alertStyle = NSAlert.Style.critical
        errorAlert.beginSheetModal(for: self.view.window!, completionHandler: nil)
    }
}

