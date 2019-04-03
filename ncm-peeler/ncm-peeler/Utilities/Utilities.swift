//
//  Utilities.swift
//  ncm-peeler
//
//  Created by yuxiqian on 2018/9/3.
//  Copyright © 2018 yuxiqian. All rights reserved.
//

import Foundation
import ID3TagEditor

func fourUInt8Combine(_ array: inout [UInt8]) -> UInt32 {
//    array.reverse()
    let data = NSData(bytes: array, length: 4)
    // 调用时保证传入四字节
    var value : UInt32 = 0
    data.getBytes(&value, length: 4)
  
//    value = UInt32(bigEndian: value)
    value = UInt32(littleEndian: value)
//   对不起…现在明白 little 和 big endian 了
    return value
}


let standardHead: [UInt8] = [0x43, 0x54, 0x45, 0x4e, 0x46, 0x44, 0x41, 0x4d]
// ncm 格式神奇文件头

let aesCoreKey: [UInt8] = [0x68, 0x7A, 0x48, 0x52, 0x41, 0x6D, 0x73, 0x6F, 0x35, 0x6B, 0x49, 0x6E, 0x62, 0x61, 0x78, 0x57]
let aesModifyKey: [UInt8] = [0x23, 0x31, 0x34, 0x6C, 0x6A, 0x6B, 0x5F, 0x21, 0x5C, 0x5D, 0x26, 0x30, 0x55, 0x3C, 0x27, 0x28]
// AES 解密用密钥两枚

let defaultUrl = URL(string: "https://avatars0.githubusercontent.com/u/34335406?s=400&v=4")
// when the url is invalid, which is not very likely,
// put my github photo on it.


enum MusicFormat: String {
    case mp3 = "mp3"
    case flac = "flac"
    case unknown = ""
}

func getFormat(_ Format: MusicFormat, _ bitRate: Int, _ duration: Int) -> String {
    var result = ""
    switch Format {
    case .mp3:
        result += "mp3\n"
        break
    case .flac:
        result += "flac\n"
        break
    default:
        result += "未知\n"
        break
    }
    result += "持续时间：\(secondsToFormat(Int(duration / 1000)))\n"
    result += "比特率：\(Int(bitRate / 1000))kbit/s"
    return result
}

func buildKeyBox(key: [UInt8]) -> [UInt8] {
    var keyBox: [UInt8] = [UInt8](repeating: 0, count: 256)
    var i: Int = 0
    while i < 256 {
        keyBox[i] = UInt8(i)
        i += 1
    }
    
    i = 0
    var j: UInt8 = 0
    let keyLength = key.count
    while i < 256 {
        j = (UInt8(keyBox[i]) &+ j &+ key[i % keyLength]) & 0xff
        keyBox.swapAt(i, Int(j))
        i += 1
    }
    return keyBox
}

func secondsToFormat(_ seconds: Int) -> String {
    return String(format: "%d:%02d", arguments: [Int(seconds / 60), seconds % 60])
}

protocol dropFileDelegate {
    func onFileDrop(_ path: String) -> ()
    func openBatch(_ array: NSArray) -> ()
}

func truncateFilePath(filePath: String) -> String {

    if filePath.count < 4 {
        return ""
    }

    if filePath.suffix(4) == ".ncm" {
        let targetPath = String(filePath.prefix(filePath.count - 4))
        return targetPath
    } else {
        return filePath
    }
}

func writeMetaInfo(musicTag: ID3Tag?, _ filePath: String) {
    if musicTag != nil {
        do {
            let id3TagEditor = ID3TagEditor()
            try id3TagEditor.write(tag: musicTag!, to: filePath)
        } catch {
            NSLog("未能成功写入元数据信息。")
            //                flac 格式没办法写 tag 信息……
        }
    } else {
        NSLog("没有可用的元数据信息。")
    }
}
