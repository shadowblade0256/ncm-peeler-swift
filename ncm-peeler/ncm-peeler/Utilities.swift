//
//  Utilities.swift
//  ncm-peeler
//
//  Created by yuxiqian on 2018/9/3.
//  Copyright © 2018 yuxiqian. All rights reserved.
//

import Foundation

func hexToBin(hexStr: String) -> Data {
    var hex = hexStr
    var data = Data()
    while (hex.count > 0) {
        let subIndex = hex.index(hex.startIndex, offsetBy: 2)
        let c = String(hex[..<subIndex])
        hex = String(hex[subIndex...])
        var ch: UInt32 = 0
        Scanner(string: c).scanHexInt32(&ch)
        var char = UInt8(ch)
        data.append(&char, count: 1)
    }
    return data
}

func fourUInt8Combine(_ array: inout [UInt8]) -> UInt32 {
    array.reverse()
    let data = NSData(bytes: array, length: 4)
    var value : UInt32 = 0
    data.getBytes(&value, length: 4)
    value = UInt32(bigEndian: value)
    return value
}

let standardHead: [UInt8] = [0x43, 0x54, 0x45, 0x4e, 0x46, 0x44, 0x41, 0x4d]

let aesCoreKey: [UInt8] = [0x68, 0x7A, 0x48, 0x52, 0x41, 0x6D, 0x73, 0x6F, 0x35, 0x6B, 0x49, 0x6E, 0x62, 0x61, 0x78, 0x57]
let aesModifyKey: [UInt8] = [0x23, 0x31, 0x34, 0x6C, 0x6A, 0x6B, 0x5F, 0x21, 0x5C, 0x5D, 0x26, 0x30, 0x55, 0x3C, 0x27, 0x28]
