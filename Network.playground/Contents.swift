import UIKit
import Combine

// MARK: - Wrapper
struct PhotosWrapper: Decodable {
    let photos: Photos
    let stat: String
}

// MARK: - Photos
struct Photos: Decodable {
    let photo: [Photo]
}

// MARK: - Photo
struct Photo: Identifiable, Decodable {
    let id: String
    let title: String
    let owner: String
    let imageUrl: String
    var isFavorite: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id, title, owner = "ownername", imageUrl = "url_m"
    }
}

// MARK: - API Resource
protocol APIResource {
    associatedtype ModelType: Decodable
    var methodPath: String { get }
    var queryItems: [URLQueryItem] { get }
}

extension APIResource {
    var url: URL {
        var components = URLComponents(string: "https://www.flickr.com")!
        components.path = methodPath
        components.queryItems = queryItems
        
        return components.url!
    }
}

// MARK: - Photos Resource
struct PhotosResource: APIResource {
    typealias ModelType = PhotosWrapper
    var methodPath = "/services/rest/"
    var queryItems = [
        URLQueryItem(name: "method", value: "flickr.people.getPublicPhotos"),
        URLQueryItem(name: "api_key", value: "d3c8cb57b60027413cd520f5853d01b7"),
        URLQueryItem(name: "user_id", value: "65789667@N06"),
        URLQueryItem(name: "extras", value: "url_m,owner_name"),
        URLQueryItem(name: "format", value: "json"),
        URLQueryItem(name: "nojsoncallback", value: "1")
    ]
}

enum APIError: Error, LocalizedError {
    case unknown, apiError(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .unknown:
            return "Unknown Error"
        case .apiError(let reason):
            return reason
        }
    }
}

// MARK: - Request Resource
class APIClient<Resource: APIResource> {
    let resource: Resource
    
    init(using resource: Resource) {
        self.resource = resource
    }
    
    func run() -> AnyPublisher<Resource.ModelType, Error> {
        var urlRequest = URLRequest(url: resource.url)
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 60
        
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .tryMap { $0.data }
            .decode(type: Resource.ModelType.self, decoder: JSONDecoder())
            .mapError { error in
                if let error = error as? APIError {
                    return error
                } else {
                    return APIError.apiError(reason: error.localizedDescription)
                }
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - Usage
let photosResource = PhotosResource()
let request: APIClient<PhotosResource> = APIClient(using: photosResource)

let test = request.run()
    .receive(on: DispatchQueue.main)
    .sink { completion in
        switch completion {
        case .finished:
            break
        case .failure(let error):
            print(error.localizedDescription)
        }
    } receiveValue: { data in
        print(data)
    }
