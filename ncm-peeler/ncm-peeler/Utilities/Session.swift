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
        filePath = ncmPath
        istream = inputStream
        musicObject = readMetaInfo(inStream: inputStream!)
        if musicObject != nil {
            isOk = true
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
            try fileManager.removeItem(atPath: filePath!)
        } catch {
            NSLog("Failed to delete file \(String(describing: filePath)).")
        }
    }

    func getOriginOutputPath() -> String {
        if filePath == nil {
            return ""
        }
        if filePath!.count < 4 {
            return ""
        }

        let format = musicObject!.format.rawValue

        if filePath!.suffix(4) == ".ncm" {
            let targetPath = String(filePath!.prefix(filePath!.count - 4) + ".\(format)")
            return targetPath
        } else {
            return filePath! + ".\(format)"
        }
    }

    func output(outputPath: String) -> Bool {
        if !isOk {
            return false
        }

        let outStream = OutputStream(toFileAtPath: outputPath, append: false)

        if outStream == nil {
            return false
        }

        outStream!.open()

        let bufSize = 0x8000
        var buffer: [UInt8] = [UInt8](repeating: 0, count: bufSize)
        var freshHeader: [UInt8?] = [nil, nil, nil, nil]
        while istream!.hasBytesAvailable {
            istream!.read(&buffer, maxLength: bufSize)
            for i in 0 ..< bufSize {
                let j = (i + 1) & 0xFF
                buffer[i] ^= musicObject!.keyBox[Int((self.musicObject!.keyBox[j] &+ self.musicObject!.keyBox[Int((self.musicObject!.keyBox[j] &+ UInt8(j)) & 0xFF)]) & 0xFF)]
                if i < 4 && freshHeader[i] == nil {
                    freshHeader[i] = buffer[i]
                }
            }
            outStream!.write(&buffer, maxLength: bufSize)
        }

        istream!.close()
        outStream!.close()

        if musicObject != nil && !musicObject!.noMetaData {
            writeMetaInfo(musicTag: musicObject?.getTag() ?? nil, outputPath)
        } else if musicObject != nil {
            /* A poor no meta data object */
            let manager: FileManager = FileManager.default
            /* Must add files to him */
            do {
                if freshHeader == [102, 76, 97, 67] {
                    // 102, 76, 97, 67 = f L a C (FLAC header)
                    try manager.moveItem(atPath: outputPath, toPath: outputPath + MusicFormat.flac.rawValue)
                } else {
                    try manager.moveItem(atPath: outputPath, toPath: outputPath + MusicFormat.mp3.rawValue)
                }
            } catch {
                return false
            }
        }
        return true
    }
}
