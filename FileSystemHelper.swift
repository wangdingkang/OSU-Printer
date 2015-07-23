//
//  FileSystemHelper.swift
//  OSU Printer
//
//  Created by Dingkang Wang on 7/16/15.
//  Copyright (c) 2015 Dingkang Wang. All rights reserved.
//

import Foundation

class FileSystemHelper {
    
    var fileManager: NSFileManager
    
    let fileQueue: dispatch_queue_t
    
    var DocumentsRootPath: String {
        get {
            return (NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as! String).stringByAppendingPathComponent("Inbox")
        }
    }
    
    init() {
        fileQueue = dispatch_queue_create("FILE.queue", DISPATCH_QUEUE_SERIAL)
        fileManager = NSFileManager.defaultManager()
    }
    
    func getUserDocumentPaths() -> [String]? {
        var noError: NSError?
        let files = fileManager.contentsOfDirectoryAtPath(DocumentsRootPath, error: &noError) as? [String]
        if noError == nil{
            if files != nil {
                for filename in files! {
                    print(filename + "\n")
                }
                return files
            }
        } else {
            print("oh, no")
            return nil
        }
        return nil
    }
    
    func getUserDocuments() -> [DocumentFile] {
        print("\(DocumentsRootPath) \n")
        var myEnumerator = fileManager.enumeratorAtPath(DocumentsRootPath)
        var ret = [DocumentFile]()
        while let filename = myEnumerator?.nextObject() as? String{
            // temporarily let the error to be nil
            print("\(filename)\n")
            if let attributes: NSDictionary? = fileManager.attributesOfItemAtPath(DocumentsRootPath.stringByAppendingPathComponent(filename), error: nil) {
                ret.append(DocumentFile(filename: filename, filesize: attributes!.fileSize(), modifiedTime: attributes!.fileModificationDate()))
            }
        }
        return ret
    }
    
    func removeDocumentWithFilename(filename: String) {
        var fullPath = DocumentsRootPath.stringByAppendingPathComponent(filename)
        var error: NSError?
        if fileManager.removeItemAtPath(fullPath, error: &error){
            print("Remove succeed")
        } else {
            print("Remove failed \(error!.localizedDescription)")
        }
    }
    
    func fileExistsInRootFolder(filename: String) -> Bool {
        let fullPath = DocumentsRootPath.stringByAppendingPathComponent(filename)
        var error: NSError?
        if fileManager.fileExistsAtPath(fullPath) {
            return true
        } else {
            return false
        }
    }
    
    
//    func copyFileFromUrlToDocument(url: NSURL) -> Bool {
//        if let sourceFilename = url.lastPathComponent {
//            var destPath = DocumentsRootPath.stringByAppendingPathComponent(sourceFilename)
//            var error: NSError?
//            print("Copy from " + url.path! + " to " + destPath + "\n")
//            fileManager.copyItemAtPath(url.path!, toPath: destPath, error: &error)
//        }
//        return true
//    }
    
}