//
//  musicParser.swift
//  ncm-peeler
//
//  Created by yuxiqian on 2018/9/5.
//  Copyright © 2018 yuxiqian. All rights reserved.
//

import Foundation
import SwiftyJSON
import CryptoSwift

func readMetaInfo(inStream: InputStream) -> Music? {

    var headerBuf: [UInt8] = []
    var tmpBuf: [UInt8] = []
    var keyLenBuf: [UInt8] = []
    var keyData: [UInt8] = []
    var deKeyData: [UInt8] = []
    var cleanDeKeyData: [UInt8] = []
    var uLenBuf: [UInt8] = []
    var metaData: [UInt8] = []
    var crc32CheckBuf: [UInt8] = []
    var imageSizeBuf: [UInt8] = []
    
    do {
        headerBuf = [UInt8](repeating: 0, count: 8)
        let length = inStream.read(&headerBuf, maxLength: headerBuf.count)
        
        if length < 1 {
            NSLog("Incorrect length: \(length)")
            return nil
        }
        
        
        for i in 0..<length {
            if headerBuf[i] != standardHead[i] {
//                inStream.close()
                NSLog("file head mismatch.")
                return nil
            }
        }
        NSLog("file head matched.")
        
        tmpBuf = [UInt8](repeating: 0, count: 2)
        inStream.read(&tmpBuf, maxLength: tmpBuf.count)
        // 向后读两个字节但是啥也不干
        // 两个字节 = 两个 UInt8
        tmpBuf.removeAll()
        
        
        keyLenBuf = [UInt8](repeating: 0, count: 4)
        // 4 个 UInt8 充 UInt32
        inStream.read(&keyLenBuf, maxLength: keyLenBuf.count)
        
        let keyLen: UInt32 = fourUInt8Combine(&keyLenBuf)
        NSLog("keyLen: \(keyLen)")
        
        keyData = [UInt8](repeating: 0, count: Int(keyLen))
        var keyLength = inStream.read(&keyData, maxLength: keyData.count)
        
        if keyLength < 1 {
            NSLog("Incorrect keyLength: \(keyLength)")
            return nil
        }
        
        for i in 0..<keyLength {
            keyData[i] ^= 0x64
        }
        
        
        //            var deKeyLen: Int = 0
        deKeyData = [UInt8](repeating: 0, count: Int(keyLen))
        
        deKeyData = try AES(key: aesCoreKey,
                            blockMode: ECB(),
                            padding: .zeroPadding).decrypt(keyData)
        
        for i in 17..<keyLength {
            // Filter padding bytes
            if deKeyData[i] > 15 {
                cleanDeKeyData.append(deKeyData[i])
            }
        }
        
        keyLength = cleanDeKeyData.count
        
        let deKeyString = String(bytes: cleanDeKeyData, encoding: .ascii)
        NSLog("obtained key \(deKeyString ?? "...FAILED...")")
        
        
        
        uLenBuf = [UInt8](repeating: 0, count: 4)
        // 4 个 UInt8 充 UInt32
        inStream.read(&uLenBuf, maxLength: uLenBuf.count)
        let uLen: UInt32 = fourUInt8Combine(&uLenBuf)
        var modifyDataAsUInt8: [UInt8] = [UInt8](repeating: 0, count: Int(uLen))
        inStream.read(&modifyDataAsUInt8, maxLength: Int(uLen))
        
        if Int(uLen) < 1 {
            NSLog("Incorrect uLen: \(uLen)")
            return nil
        }
        
        
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
        
        if dataLen < 7 {
            NSLog("Incorrect dataLen: \(dataLen)")
            return nil
        }
        
        for i in 0..<(dataLen - 6) {
            metaData[i] = metaData[i + 6]
        }
        metaData[dataLen - 6] = 0
        // 手动写 C 字符串结束符 \0
        
    } catch {
        print("AES 解密失败。")
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
        if let artistArray = musicMeta["artist"].array {
            for index in 0..<artistArray.count {
                music.artists.append(artistArray[index][0].stringValue)
            }
        }
    } catch {
        print("文件元数据解析失败。")
        return nil
    }
    
    DispatchQueue.global().async {
        // 新开一个线程读图片
        do {
            let image = try NSImage(data: Data(contentsOf: URL(string: music.albumCoverLink)!))
            DispatchQueue.main.async {
                music.albumCover = image
            }
        } catch {
            DispatchQueue.main.async {
                print("未能加载服务器端的专辑封面。\n\n将会使用 ncm 文件内嵌的专辑封面。")
                // 其实两个没啥区别…
            }
        }
    }
    
    // 继续往下读 CRC32 校验和
    crc32CheckBuf = [UInt8](repeating: 0, count: 4)
    inStream.read(&crc32CheckBuf, maxLength: crc32CheckBuf.count)
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
        music.albumCover = NSImage(data: Data(imageData))
    }
    
    if deKeyData.count < 17 {
        NSLog("没读出来 deKeyData。")
        return nil
    }

    // 从第 17 位开始取 deKeyData
    // 前面有一段废话 ‘neteasecloudmusic’
    // 创建新的 realDeKeyData 并用它生成 keyBox
    music.keyBox = buildKeyBox(key: cleanDeKeyData)
    
    return music
}
