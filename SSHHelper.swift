//
//  SSHHelper.swift
//  OSU Printer
//
//  Created by Dingkang Wang on 7/16/15.
//  Copyright (c) 2015 Dingkang Wang. All rights reserved.
//

import Foundation

class SSHHelper {
    
    static let sharedInstance = SSHHelper()
    
    var tempSession: NMSSHSession!
    
    var tempFTPConnection: NMSFTP!
    
    var tempUser: TempUser?
    
    let hostnameForCSE = "gamma.cse.ohio-state.edu"
    
    let hostnameForECE = "rh026.ece.ohio-state.edu"
    
    let serverTempFolderPath = "temp_print"
    
    let removeFileCommand = "rm"
    
    let mkdirCommand = "mkdir temp_print"
    
    weak var taskFinishedDelegate: TaskFinishedProtocol!
    
    let sshCommandQueue: dispatch_queue_t = dispatch_queue_create("OSU_Printer.NMSSH.command.queue", DISPATCH_QUEUE_SERIAL)
    
    let sshTestQueue: dispatch_queue_t = dispatch_queue_create("OSU_Printer.NMSSH.test.queue", DISPATCH_QUEUE_SERIAL)
    
    let sshSemaphore = dispatch_semaphore_create(1)
    
    private init() {}
    
    private func getPrintCommand(printingOption: PrintingOption, filename: String) -> String {
        return printingOption.isDuplex ? "lp -d \(printingOption.printerName) -o sides=two-sided-long-edge -n \(printingOption.copies) \"\(filename)\"" :
                            "lp -d \(printingOption.printerName) -n \(printingOption.copies) \"\(filename)\""
    }
    
    private func createANewSession(tempUser: TempUser, inout error: String?){
        var hostname: String?
        switch tempUser.department {
        case Department.CSE.rawValue:
            hostname = self.hostnameForCSE
        case Department.ECE.rawValue:
            hostname = self.hostnameForECE
        default:
            break
        }
        if hostname != nil {
            tempSession = NMSSHSession(host: hostname, andUsername: tempUser.username)
            // set timeout to be 2 seconds
            tempSession.connectWithTimeout(2)
            if !tempSession.connected {
                error = "Connection error, please check you internet connection."
            } else {
                tempSession.authenticateByPassword(tempUser.password)
                if !tempSession.authorized {
                    error = "Invalid username or password."
                } else {
                    self.tempUser = tempUser
                }
            }
        } else {
            error = "No hostname found."
        }
    }
    
    func testUsernameAndPassword(newUser: TempUser, inout error: String?) {
        dispatch_semaphore_wait(sshSemaphore, DISPATCH_TIME_FOREVER)
        if !isTempSessionActive(newUser) && tempSession != nil && (tempSession!.connected) {
            tempSession?.disconnect()
            createANewSession(newUser, error: &error)
        }
        dispatch_semaphore_signal(sshSemaphore)
    }
    
    private func isTempSessionActive(newUser: TempUser) -> Bool {
        return tempUser != nil && tempUser!.isEqual(newUser) && tempSession != nil && tempSession.authorized
    }
    
    private func uploadFileToServer(foldername: String, filename: String, inout error: String?) {
        tempFTPConnection = NMSFTP(session: tempSession)
        tempFTPConnection.connect()
        let fromPath = foldername.stringByAppendingPathComponent(filename)
        let toPath = serverTempFolderPath.stringByAppendingPathComponent(filename)
        
        print("\(fromPath) to \(toPath) \n")
        
        let uploadOK = tempFTPConnection.writeFileAtPath(foldername.stringByAppendingPathComponent(filename), toFileAtPath:
            serverTempFolderPath.stringByAppendingPathComponent(filename))
        
        tempFTPConnection.disconnect()
        if !uploadOK {
            error = "Some errors happen when uploading your file"
        }
    }
    
    func printPDF(newUser: TempUser, sourceFoldername: String, sourceFilename: String, printingOption: PrintingOption, inout error: String?) {
        dispatch_semaphore_wait(sshSemaphore, DISPATCH_TIME_FOREVER)
        taskFinishedDelegate.taskFinishedfeedback("Checking...")
        if !isTempSessionActive(newUser) {
            // create a new session
            if tempSession != nil {
                tempSession?.disconnect()
            }
            createANewSession(newUser, error: &error)
            if error != nil {
                dispatch_semaphore_signal(sshSemaphore)
                return
            }
        }
        taskFinishedDelegate.taskFinishedfeedback("Creating temp folder on server...")
        commandToCreateFolderOnServer(&error)
        
        if error != nil {
            dispatch_semaphore_signal(sshSemaphore)
            return
        }
        
        taskFinishedDelegate.taskFinishedfeedback("Start uploading...")
        uploadFileToServer(sourceFoldername, filename: sourceFilename, error: &error)
        if error != nil {
            dispatch_semaphore_signal(sshSemaphore)
            return
        }
        
        taskFinishedDelegate.taskFinishedfeedback("Start Printing...")
        commandToPrintPDF(sourceFilename, printingOption: printingOption, error: &error)
        dispatch_semaphore_signal(sshSemaphore)
    }
    
    private func commandToCreateFolderOnServer(inout error: String?) {
        tempSession.channel.requestPty = true
        var isOK = tempSession.channel.startShell(nil)
        if !isOK {
            error = "Fail to start shell"
            return
        }
        tempSession.channel.execute(mkdirCommand, error: nil)
    }
    
    
    private func commandToPrintPDF(filename: String, printingOption: PrintingOption, inout error: String?) {
        if tempSession == nil || !tempSession.connected {
            error = "Connection unexpectedly interrupted."
            return
        }
        
        let command = getPrintCommand(printingOption, filename: serverTempFolderPath.stringByAppendingPathComponent(filename))
        
        tempSession.channel.execute(command, error: nil)
    }
    
    func removeFileAtPath(filename: String) {
        dispatch_semaphore_wait(sshSemaphore, DISPATCH_TIME_FOREVER)
        if tempSession != nil && tempSession.connected {
            tempSession.channel.requestPty = true
            let command = "\(removeFileCommand) \(serverTempFolderPath.stringByAppendingPathComponent(filename))"
            print(command + "\n")
            tempSession.channel.execute(command, error: nil)
        }
        dispatch_semaphore_signal(sshSemaphore)
    }
    
    
    func releaseConnection() {
        dispatch_semaphore_wait(sshSemaphore, DISPATCH_TIME_FOREVER)
        if tempSession != nil{
            tempSession.disconnect()
            tempSession = nil
        }
        dispatch_semaphore_signal(sshSemaphore)
    }
    
}