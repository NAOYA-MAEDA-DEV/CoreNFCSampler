//
//  NFCTagReader.swift
//
//
//  Created by Naoya Maeda on 2024/04/21
//
//

import CoreNFC

final class NFCTagReader: NSObject, ObservableObject {
    private var session: NFCNDEFReaderSession?
    private var tagSession: NFCTagReaderSession?
    
    var writeMesage = "CoreNFCTest"
    let readingAvailable: Bool
    
    @Published var sessionType = SessionType.read
    @Published var nfcFormat = NFCFormat.ndef
    @Published var readMessage: String?
    
    override init() {
        readingAvailable = NFCNDEFReaderSession.readingAvailable
    }
    
    func beginScanning() {
        guard readingAvailable else {
            print("This iPhone is not NFC-enabled.")
            return
        }
        
        switch nfcFormat {
        case .ndef:
            session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
            session?.alertMessage = "Please bring your iPhone close to the NFC tag."
            session?.begin()
            
        case .suica:
            tagSession = NFCTagReaderSession(pollingOption: .iso18092, delegate: self, queue: nil)
            tagSession?.alertMessage = "Please bring your iPhone close to the NFC tag."
            tagSession?.begin()
        }
    }
    
    private func read(tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        tag.readNDEF { [weak self] message, error in
            session.alertMessage = "The tag reading has been completed."
            session.invalidate()
            if let message {
                DispatchQueue.main.async {
                    self?.readMessage = self?.getStringFromNFCNDEF(message: message)
                }
            }
        }
    }
    
    private func getStringFromNFCNDEF(message: NFCNDEFMessage) -> String {
        message.records.compactMap {
            switch $0.typeNameFormat {
            case .nfcWellKnown:
                if let url = $0.wellKnownTypeURIPayload() {
                    return url.absoluteString
                }
                if let text = String(data: $0.payload, encoding: .utf8) {
                    return text
                }
                return nil
            default:
                return nil
            }
        }.joined(separator: "\n\n")
    }
}

extension NFCTagReader: NFCNDEFReaderSessionDelegate {
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        print("Reader session is active.")
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        print("error:\(error.localizedDescription)")
    }
    
    /// readerSession(_:didDetect:)を実装すると呼び出されなくなる
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        guard messages.count > 0 else { return }
        
        self.readMessage = getStringFromNFCNDEF(message: messages.first!)
        session.alertMessage = "The tag reading has been completed."
        session.invalidate()
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard tags.count < 2 else { return }
        
        let tag = tags.first!
        session.connect(to: tag, completionHandler: { (error: Error?) in
            guard error == nil else {
                session.invalidate(errorMessage: "Unable to connect to tag.")
                return
            }
            
            tag.queryNDEFStatus(completionHandler: { [weak self] (ndefStatus: NFCNDEFStatus, capacity: Int, error: Error?) in
                guard let self else { return }
                
                guard error == nil else {
                    session.invalidate(errorMessage: "Unable to query the NDEF status of tag.")
                    return
                }
                
                switch ndefStatus {
                case .notSupported:
                    session.invalidate(errorMessage: "Tag is not NDEF compliant.")
                    
                case .readOnly:
                    guard sessionType == .read else {
                        session.invalidate(errorMessage: "Tag is read only.")
                        return
                    }
                    read(tag: tag, session: session)
                    
                case .readWrite:
                    switch sessionType {
                    case .read:
                        read(tag: tag, session: session)
                        
                    case .write:
                        let data = writeMesage.data(using: .utf8)!
                        let payload = NFCNDEFPayload(format: .nfcWellKnown, type: Data("T".utf8), identifier: Data(), payload: data)
                        let message = NFCNDEFMessage(records: [payload])
                        tag.writeNDEF(message, completionHandler: { (error: Error?) in
                            if nil != error {
                                session.invalidate(errorMessage: "Write NDEF message fail: \(error!)")
                            } else {
                                session.alertMessage = "Write NDEF message successful."
                                session.invalidate()
                            }
                        })
                    case .lock:
                        session.alertMessage = "The tag locking has been completed."
                        session.invalidate()
                    }
                    
                @unknown default:
                    session.alertMessage = "Unknown NDEF tag status."
                    session.invalidate()
                }
            })
        })
    }
}

extension NFCTagReader: NFCTagReaderSessionDelegate {
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        print("Reader session is active.")
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        print("error:\(error.localizedDescription)")
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        let tag = tags.first!
        
        session.connect(to: tag) { (error) in
            if nil != error {
                session.invalidate(errorMessage: "Unable to connect to tag.")
                return
            }
            
            guard case .feliCa(let feliCaTag) = tag else {
                let retryInterval = DispatchTimeInterval.milliseconds(500)
                session.alertMessage = "A tag that is not FeliCa is detected, please try again with tag FeliCa."
                DispatchQueue.global().asyncAfter(deadline: .now() + retryInterval, execute: {
                    session.restartPolling()
                })
                return
            }
            
            let idm = feliCaTag.currentIDm.map { String(format: "%.2hhx", $0) }.joined()
            DispatchQueue.main.async { [weak self] in
                self?.readMessage = idm
            }
            session.alertMessage = "The tag reading has been completed."
            session.invalidate()
        }
    }
}
