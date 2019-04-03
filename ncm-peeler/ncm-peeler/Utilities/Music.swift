//
//  Music.swift
//  ncm-peeler
//
//  Created by yuxiqian on 2018/9/5.
//  Copyright © 2018 yuxiqian. All rights reserved.
//

import Cocoa
import ID3TagEditor

class Music: NSObject {
    var noMetaData: Bool = false
    var title: String = ""
    var musicId: Int = 0
    var artists: [String] = []
    var aliasNames: [String] = []
    var album: String = ""
    var albumCover: NSImage?
    var albumCoverLink: String = ""
    var format: MusicFormat = .unknown
    var duration: Int = 0
    var bitRate: Int = 0
    var keyBox: [UInt8] = []
    
    func getTag() -> ID3Tag {
        return ID3Tag(
            version: .version3,
            artist: self.artists.joined(separator: " / "),
            albumArtist: self.artists.joined(separator: " / "),
            album: self.album,
            title: self.title,
            recordingDateTime: nil,
            genre: nil,
            attachedPictures: [AttachedPicture(picture: (self.albumCover?.tiffRepresentation)!, type: .FrontCover, format: .Jpeg)],
            trackPosition: nil
        )
    }
    
    func getArtist() -> String {
        return self.artists.joined(separator: " / ")
    }
    
    func getTime() -> String {
        return secondsToFormat(Int(self.duration / 1000))
    }
    
    func getBitRate() -> String {
        return "\(Int(self.bitRate / 1000))kbit/s"
    }
    
    func generateFileName() -> String {
        var fileName = "/\(self.artists[0]) - \(self.title)"
        switch self.format {
        case .mp3:
            fileName += ".mp3"
            break
        case .flac:
            fileName += ".flac"
            break
        default:
            break
        }
        return fileName
    }
}
