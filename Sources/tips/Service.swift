import Foundation

enum ServiceResult<T> {
    case failure(Error)
    case success(T)
    
    var value: T? {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return nil
        }
    }
    
    var error: Error? {
        switch self {
        case .success:
            return nil
        case .failure(let error):
            return error
        }
    }
    
    func flatMap<U>(closure: (T) throws -> U?)-> ServiceResult<U> {
        switch self {
        case .failure(let error):
            return .failure(error)
        case .success(let value):
            do {
                if let newValue = try closure(value) {
                    return .success(newValue)
                }
                else {
                    return .failure(ServiceError.invalidResponse)
                }
            }
            catch {
                return .failure(error)
            }
            
        }
    }
}

enum ServiceError: Error {
    case unknownState
    case invalidURL(String)
    case invalidResponse
    
    static func fail<T>(with error: ServiceError = .unknownState, _ closure: (ServiceResult<T>) -> Void) {
        assertionFailure("we should get an error or a data here")
        closure(.failure(error))
    }
}

class Service {
    typealias JSONDictionary = [String: Any]
    
    @discardableResult
    public static func requestText(_ url: String, completion: @escaping (ServiceResult<String>) -> Void) -> URLSessionDataTask? {
        let task = self.request(url: url) { result in
            let newResult = result.flatMap { String(data: $0, encoding: .utf8) }
            completion(newResult)
        }

        return task
    }
    
    @discardableResult
    static func request(url: String, completion: @escaping (ServiceResult<Data>) -> Void) -> URLSessionDataTask? {
        guard let baseURL = URL(string: url) else {
            completion(.failure(ServiceError.invalidURL(url)))
            return nil
        }

        var request: URLRequest = URLRequest(url: baseURL)
        request.httpMethod = "GET"
        
        let semaphore = DispatchSemaphore(value: 0)
        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
            }
            else if let data = data {
                completion(.success(data))
            }
            else {
                ServiceError.fail(completion)
            }

            semaphore.signal()
        }
        
        task.resume()
        semaphore.wait()
        
        return task
    }
}
