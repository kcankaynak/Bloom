//
//  CloudManager.swift
//  Kur Cepte
//
//  Created by Kemal Kaynak on 28.09.20.
//  Copyright © 2020 Kemal Kaynak. All rights reserved.
//

import Foundation
import CloudKit

final class CloudManager {
    
    static let shared = CloudManager()
    private let cloudViewModel = CloudViewModel()
    private let container = CKContainer(identifier: "iCloud.com.kcankaynak.yatirimcuzdani")
    
    func upload(_ record: CKRecord,
                completion: @escaping(CKRecord?) -> ()) {
        container.privateCloudDatabase.save(record, completionHandler: { (record, error) in
            if let record = record {
                completion(record)
            } else {
                completion(nil)
            }
        })
    }
    
    func download(_ query: CKQuery,
                  fileType: CacheManager.key,
                  completion: @escaping (Decodable?) -> ()) {
        container.privateCloudDatabase.perform(query, inZoneWith: nil) { [weak self] (records, error) in
            if let error = error {
                print("Failed to download data from cloud with error: \(error.localizedDescription)")
            }
            if let records = records, let self = self {
                self.cloudViewModel.parseCloudData(from: records, fileType: fileType, completion: { data in
                    completion(data)
                })
            } else {
                completion(nil)
            }
        }
    }
    
    func update(_ record: CKRecord) {
        let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        operation.savePolicy = .changedKeys
        operation.qualityOfService = .userInitiated
        operation.modifyRecordsCompletionBlock = { (_, _, _) in }
        container.privateCloudDatabase.add(operation)
    }
    
    func delete(_ recordName: String,
                completion: @escaping (Bool) -> ()) {
        container.privateCloudDatabase.delete(withRecordID: CKRecord.ID(recordName: recordName), completionHandler: { _, error in
            completion(error == nil ? true : false)
        })
    }
}
