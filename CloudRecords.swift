//
//  CloudManager.swift
//  Kur Cepte
//
//  Created by Kemal Kaynak on 19.07.19.
//  Copyright © 2019 Kemal Kaynak. All rights reserved.
//

import Foundation

struct CloudRecords {
    
    enum recordType: String {
        case favorites = "favorites"
        case investment = "investment"
        case convert = "convert"
    }
    
    struct Fields {
        
        struct Favorites {
            static let code = "code"
            static let type = "type"
            static let createdDate = "createdTimestamp"
        }
        
        struct Investments {
            static let amount = "amount"
            static let code = "code"
            static let image = "image"
            static let name = "name"
            static let type = "type"
            static let typeName = "typeName"
            static let value = "value"
            static let createdDate = "createdTimestamp"
            static let initialValue = "initialValue"
        }
    }
}

struct CloudModel {
    
    struct Favorites {
        var code: String
        var type: CurrencyBase.type
        var recordName: String
    }
    
    struct Investments {
        var amount: Double
        var code: String
        var image: String
        var name: String
        var type: CurrencyBase.type
        var typeName: String
        var value: Double
        var recordName: String
        var creationDate: Date
        var initialValue: Double
    }
}
