//
//  DraggableTable.swift
//  ncm-peeler
//
//  Created by yuxiqian on 2019/1/20.
//  Copyright © 2019 yuxiqian. All rights reserved.
//

import Cocoa

class DraggableButton: NSButton {

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // Drawing code here.
    }
    
    var delegate: dropFileDelegate?
    var filePath: String?
    let expectedExt = ["ncm"]
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.wantsLayer = true
//                self.layer?.backgroundColor = NSColor.gray.cgColor
        //                self.registerForDraggedTypes([NSURLPboardType])
        self.registerForDraggedTypes([NSPasteboard.PasteboardType.backwardsCompatibleFileURL])
    }
    
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if checkExtension(sender) == true {
//            self.layer?.backgroundColor = NSColor.blue.cgColor
            return .copy
        } else {
            return NSDragOperation()
        }
    }
    
    fileprivate func checkExtension(_ drag: NSDraggingInfo) -> Bool {
        guard let board = drag.draggingPasteboard().propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray,
            let path = board[0] as? String
            else { return false }
        
        let suffix = URL(fileURLWithPath: path).pathExtension
        for ext in self.expectedExt {
            if ext.lowercased() == suffix {
                return true
            }
        }
        return false
    }
    
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let pasteboard = sender.draggingPasteboard().propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray,
            let path = pasteboard[0] as? String
            else { return false }
        if pasteboard.count == 1 {
            self.delegate?.onFileDrop(path)
            return true
        } else {
            self.delegate?.openBatch(pasteboard)
            return true
        }
    }
}

extension NSPasteboard.PasteboardType {
    static let backwardsCompatibleFileURL: NSPasteboard.PasteboardType = {
        return NSPasteboard.PasteboardType("NSFilenamesPboardType")
    }()
}

