//
//  Service.swift
//  ServiceManager
//
//  Created by Alireza Moradi on 2/17/20.
//  Copyright © 2020 Alireza Moradi. All rights reserved.
//

import Foundation

public class Service  {
    
    private let baseURL:URL
    private let encoder:JSONEncoder
    private let decoder:JSONDecoder
    private let header:String
    private var session:URLSession!
    
    public init(baseURL:URL, header:String) {
        self.baseURL = baseURL
        self.header = header
        
        let jsonDecoder = JSONDecoder()
        jsonDecoder.dataDecodingStrategy = .base64
        //        jsonDecoder.dateDecodingStrategy = .millisecondsSince1970
        decoder = jsonDecoder
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = []
        jsonEncoder.dataEncodingStrategy = .base64
        encoder = jsonEncoder
        initialazeSession()
    }
    private func initialazeSession() {
        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.networkServiceType = .responsiveData
        config.shouldUseExtendedBackgroundIdleMode = true
        session = URLSession(configuration: config, delegate: nil, delegateQueue: .main)
    }
    
    private func configRequest<T:Requestable>(object:T) throws -> URLRequest {
        guard let url = URL(string: type(of: object).url, relativeTo: baseURL) else { throw ServiceError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if type(of: object).isHeader {
            request.setValue(header, forHTTPHeaderField: "Authorization")
        }
        request.httpMethod = type(of: object).method.rawValue
        do {
            switch type(of: object).requestType {
            case .jsonBody:
                request.httpBody = try encoder.encode(object)
            case .urlQuery:
                request = try configGet(url: url, parameters: object)
            default:
                throw ServiceError.invalidURL
            }
        } catch {
            throw ServiceError.invalidURL
        }
        return request
    }
    private func configGet<R:Requestable>(url:URL,parameters:R) throws -> URLRequest {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { throw ServiceError.invalidURL }
        let dic = parameters.dictionary
        components.setQueryItems(with: dic)
        guard let componentUrl = components.url else { throw ServiceError.invalidURL }
        return URLRequest(url: componentUrl)
    }
    private func validate(response:HTTPURLResponse?,data:Data?) throws -> Data {
        guard let data = data else { throw ServiceError.invalidResponse }
        guard let response = response else { throw ServiceError.invalidResponse }
        switch response.statusCode {
        case 401:
            let errorResponse = try decoder.decode(ErrorResponse.self, from: data)
            throw ServiceError.loginFaild(message: errorResponse.message)
        case 400,402...:
            let errorResponse = try decoder.decode(ErrorResponse.self, from: data)
            throw ServiceError.badHttpStatus(status: response.statusCode, message: errorResponse.message)
        default:
            break
        }
        return data
    }
    private func requestHandler<T:Decodable>(_ request: URLRequest, obejct:T.Type, completionHandler: @escaping (Result<T,ServiceError>) -> Void) {
        let dataTask = session.dataTask(with: request) { (data, response, error) in
            do {
                if let error = error { throw error }
                let data = try self.validate(response: response as? HTTPURLResponse, data: data)
                let result = try self.decoder.decode(obejct, from: data)
                completionHandler(.success(result))
            } catch {
                completionHandler(.failure(.invalidResponse))
            }
        }
        dataTask.resume()
    }
    public func request<T:Requestable>(object:T, completionHandler: @escaping (Result<T.ResponseType,ServiceError>) -> Void) {
        do {
            let request = try configRequest(object: object)
            requestHandler(request, obejct: T.ResponseType.self, completionHandler: completionHandler)
        } catch {
            completionHandler(.failure(.invalidURL))
        }
    }
}
//                let json = try JSONSerialization.jsonObject(with: data, options: []) as? Dictionary<String,Any>
//                print((json)!)