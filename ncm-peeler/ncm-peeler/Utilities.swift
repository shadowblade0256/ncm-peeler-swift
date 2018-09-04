//
//  Utilities.swift
//  ncm-peeler
//
//  Created by yuxiqian on 2018/9/3.
//  Copyright © 2018 yuxiqian. All rights reserved.
//

import Foundation

func fourUInt8Combine(_ array: inout [UInt8]) -> UInt32 {
    array.reverse()
    // 需要先 reverse bytes 再进行合并
    let data = NSData(bytes: array, length: 4)
    // 调用时保证传入四字节
    var value : UInt32 = 0
    data.getBytes(&value, length: 4)
    value = UInt32(bigEndian: value)
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

enum MusicFormat {
    case mp3
    case flac
    case unknown
}

func getFormat(_ Format: MusicFormat, _ bitRate: Int) -> String {
    var result = ""
    switch Format {
    case .mp3:
        result += "MP3\n"
        break
    case .flac:
        result += "FLAC\n"
        break
    default:
        break
    }
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
