//
//  Session.swift
//  ncm-peeler
//
//  Created by yuxiqian on 2019/1/20.
//  Copyright © 2019 yuxiqian. All rights reserved.
//

import Foundation

class Session {
    
    var musicObject: Music?
    
    var isOk: Bool = false
    
    var istream: InputStream?
    
    var filePath: String?
    
    init(ncmPath: String) {
        NSLog("Prepare opening stream with \(ncmPath)")
        let inputStream = InputStream(fileAtPath: ncmPath)
        if inputStream == nil {
            NSLog("Failed to open stream")
            return
        }
        inputStream!.open()
        self.filePath = ncmPath
        self.istream = inputStream
        self.musicObject = readMetaInfo(inStream: inputStream!)
        if self.musicObject != nil {
            self.isOk = true
        }
    }
    
    deinit {
        // 消失之前
        // 先关闭流吧
        self.istream?.close()
    }
    
    func deleteFile() {
        let fileManager = FileManager.default
        do {
            try fileManager.removeItem(atPath: self.filePath!)
        } catch {
            NSLog("Failed to delete file \(String(describing: self.filePath)).")
        }
    }
    
    func getOriginOutputPath() -> String {
        
        if self.filePath == nil {
            return ""
        }
        if self.filePath!.count < 4 {
            return ""
        }
        
        let format = self.musicObject!.format.rawValue
        
        if self.filePath!.suffix(4) == ".ncm" {
            let targetPath = String(self.filePath!.prefix(self.filePath!.count - 4) + ".\(format)")
            return targetPath
        } else {
            return self.filePath! + ".\(format)"
        }
    }
    
    func output(outputPath: String) -> Bool {
        
        if !self.isOk {
            return false
        }
        
        let outStream = OutputStream(toFileAtPath: outputPath, append: false)
        
        if outStream == nil {
            return false
        }

        
        outStream!.open()
        
        let bufSize = 0x8000
        var buffer: [UInt8] = [UInt8](repeating: 0, count: bufSize)
        while self.istream!.hasBytesAvailable {
            self.istream!.read(&buffer, maxLength: bufSize)
            for i in 0..<bufSize {
                let j = (i + 1) & 0xff
                buffer[i] ^= self.musicObject!.keyBox[Int((self.musicObject!.keyBox[j] &+ self.musicObject!.keyBox[Int((self.musicObject!.keyBox[j] &+ UInt8(j)) & 0xff)]) & 0xff)]
            }
            outStream!.write(&buffer, maxLength: bufSize)
        }
        
        self.istream!.close()
        outStream!.close()
        writeMetaInfo(musicTag: self.musicObject?.getTag() ?? nil, outputPath)
        return true
    }
}
