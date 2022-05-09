//
//  CloudViewModel.swift
//  Kur Cepte
//
//  Created by Kemal Kaynak on 28.09.20.
//  Copyright © 2020 Kemal Kaynak. All rights reserved.
//

import Foundation
import CloudKit

class CloudViewModel {
    
    private let networkGroup = DispatchGroup()
    private var favoriteCloudModel = [CloudModel.Favorites]()
    private var investmentCloudModel = [CloudModel.Investments]()
    private var favoriteModel = [FavoriteModel]()
    private var investmentModel = [InvestmentModel]()
    
    func parseCloudData(from records: [CKRecord],
                        fileType: CacheManager.key,
                        completion: @escaping (Decodable?) -> ()) {
        switch fileType {
        case .favorite:
            favoriteCloudModel.removeAll()
            for record in records {
                guard let code = record.value(forKey: CloudRecords.Fields.Favorites.code) as? String,
                      let type = record.value(forKey: CloudRecords.Fields.Favorites.type) as? String,
                      let currencyType = CurrencyBase.type(rawValue: type) else { continue }
                favoriteCloudModel.append(CloudModel.Favorites(code: code, type: currencyType, recordName: record.recordID.recordName))
            }
            fetchFavoriteData(completion: { data in
                completion(data)
            })
        case .investment:
            investmentCloudModel.removeAll()
            for record in records {
                guard let amount = record.value(forKey: CloudRecords.Fields.Investments.amount) as? Double,
                      let code = record.value(forKey: CloudRecords.Fields.Investments.code) as? String,
                      let image = record.value(forKey: CloudRecords.Fields.Investments.image) as? String,
                      let name = record.value(forKey: CloudRecords.Fields.Investments.name) as? String,
                      let type = record.value(forKey: CloudRecords.Fields.Investments.type) as? String,
                      let currencyType = CurrencyBase.type(rawValue: type),
                      let typeName = record.value(forKey: CloudRecords.Fields.Investments.typeName) as? String,
                      let date = record.creationDate,
                      let value = record.value(forKey: CloudRecords.Fields.Investments.value) as? Double  else { continue }
                investmentCloudModel.append(CloudModel.Investments(amount: amount,
                                                                   code: code,
                                                                   image: image,
                                                                   name: name,
                                                                   type: currencyType,
                                                                   typeName: typeName,
                                                                   value: value,
                                                                   recordName: record.recordID.recordName,
                                                                   creationDate: date,
                                                                   initialValue: record.value(forKey: CloudRecords.Fields.Investments.initialValue) as? Double ?? 0.0))
            }
            fetchInvestmentData(completion: { data in
                completion(data)
            })
        default:
            completion(nil)
        }
    }
}

// MARK: - Fetch Favorite Data -

extension CloudViewModel {
    
    private func fetchFavoriteData(completion: @escaping ([FavoriteModel]?) -> ()) {
        favoriteModel.removeAll()
        guard !favoriteCloudModel.isEmpty else {
            completion(nil)
            return
        }
        
        favoriteCloudModel.forEach { item in
            networkGroup.enter()
            MarketPriceModel.getCurrencyData(item.code, success: { model in
                if var marketModel = model.first {
                    #if os(iOS)
                    MarketViewModel.shared.getGraphData(for: .day, code: item.code) { graphModel in
                        switch item.type {
                        case .currency, .crypto:
                            marketModel.image = item.code
                        case .gold:
                            if let name = marketModel.name, self.searchIn(name, searchString: "güm") {
                                marketModel.image = "silver"
                            } else {
                                marketModel.image = "gold"
                            }
                        case .stock, .indexes:
                            marketModel.image = "stock"
                        case .parity:
                            marketModel.image = item.code.stringBefore("/")
                        }
                        marketModel.recordName = item.recordName
                        marketModel.graphData = graphModel
                        self.favoriteModel.append(FavoriteModel.createFavorite(from: marketModel))
                        self.networkGroup.leave()
                    }
                    #else
                    switch item.type {
                    case .currency, .crypto:
                        marketModel.image = item.code
                    case .gold:
                        if let name = marketModel.name, self.searchIn(name, searchString: "güm") {
                            marketModel.image = "silver"
                        } else {
                            marketModel.image = "gold"
                        }
                    case .stock, .indexes:
                        marketModel.image = "stock"
                    case .parity:
                        marketModel.image = item.code.stringBefore("/")
                    }
                    marketModel.recordName = item.recordName
                    self.favoriteModel.append(FavoriteModel.createFavorite(from: marketModel))
                    self.networkGroup.leave()
                    #endif
                } else {
                    self.networkGroup.leave()
                }
            }, failure: { error in
                print("Fetch favorite currency data fail with: \(error.localizedDescription)")
                self.networkGroup.leave()
            })
        }
        
        networkGroup.notify(queue: .main) {
            self.favoriteModel = self.favoriteModel.reorder(by: self.favoriteCloudModel.map({ $0.code }))
            completion(self.favoriteModel)
        }
    }
}

// MARK: - Fetch Investment Data -

extension CloudViewModel {
    
    private func fetchInvestmentData(completion: @escaping ([InvestmentModel]?) -> ()) {
        investmentModel.removeAll()
        guard !investmentCloudModel.isEmpty else {
            completion(nil)
            return
        }
        
        investmentCloudModel.forEach { item in
            networkGroup.enter()
            MarketPriceModel.getCurrencyData(item.code, success: { model in
                if let price = model.first?.data?.lastBuyPrice {
                    let image: String!
                    switch item.type {
                    case .currency, .crypto:
                        if item.code == "TRY" {
                            image = "DVZSP1"
                        } else {
                            image = item.code
                        }
                    case .gold:
                        if let name = model.first?.name, self.searchIn(name, searchString: "güm") {
                            image = "silver"
                        } else {
                            image = "gold"
                        }
                    case .stock, .indexes:
                        image = "stock"
                    case .parity:
                        image = item.code.stringBefore("/")
                    }
                    
                    let value: Double!
                    switch item.type {
                    case .currency, .stock:
                        value = item.amount * PriceEngine.getRealPrice(price)
                    case .gold:
                        if let name = model.first?.name {
                            if item.code.search("XAU") || name.search("ons") {
                                if name.search("eur") {
                                    value = item.amount * PriceEngine.getRealPrice(price) * TopCurrencyModel.shared.euroPrice
                                } else {
                                    value = item.amount * PriceEngine.getRealPrice(price) * TopCurrencyModel.shared.dollarPrice
                                }
                            } else {
                                value = item.amount * PriceEngine.getRealPrice(price)
                            }
                        } else {
                            value = item.amount * PriceEngine.getRealPrice(price)
                        }
                    default:
                        value = item.amount * PriceEngine.getRealPrice(price) * TopCurrencyModel.shared.dollarPrice
                    }
                    let investmentData = InvestmentModel(image: image,
                                                         name: item.name,
                                                         typeName: item.typeName,
                                                         amount: item.amount,
                                                         value: value,
                                                         type: item.type,
                                                         code: item.code,
                                                         recordName: item.recordName,
                                                         creationDate: item.creationDate,
                                                         initialValue: item.initialValue)
                    self.investmentModel.append(investmentData)
                }
                self.networkGroup.leave()
            }, failure: { error in
                print("Fetch favorite currency data fail with: \(error.localizedDescription)")
                self.networkGroup.leave()
            })
        }
        
        networkGroup.notify(queue: .main) {
            self.investmentModel = self.investmentModel.sorted(by: { $0.creationDate ?? Date() > $1.creationDate ?? Date() })
            completion(self.investmentModel)
        }
    }
}

// MARK: - Search String -

extension CloudViewModel {
    
    func searchIn(_ from: String, searchString: String) -> Bool {
        return from.uppercased().folding(options: [.diacriticInsensitive], locale: .current).range(of: searchString.uppercased().folding(options: [.diacriticInsensitive], locale: .current)) != nil
    }
}
