# Swift Implementation Details for Mac Client

This document outlines specific Swift implementation details for the Mac client, including concurrency approaches, property wrapper usage for state management, and dependency injection patterns.

## 1. Swift Concurrency Approach

### 1.1 Async/Await Implementation

```swift
// MARK: - Core Async API Client

class AsyncAPIClient {
    private let baseURL: URL
    private let session: URLSession
    
    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }
    
    // Generic request method using async/await
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: Any]? = nil,
        headers: [String: String]? = nil
    ) async throws -> T {
        // Construct URL
        let url = baseURL.appendingPathComponent(endpoint)
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        // Add headers
        headers?.forEach { request.addValue($1, forHTTPHeaderField: $0) }
        
        // Add default headers
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add parameters
        if let parameters = parameters {
            switch method {
            case .get:
                // Add query parameters
                var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
                components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
                request.url = components.url
                
            case .post, .put, .patch:
                // Add body parameters
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
                
            case .delete:
                // Add body parameters for DELETE if needed
                if !parameters.isEmpty {
                    request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
                }
            }
        }
        
        // Perform request
        let (data, response) = try await session.data(for: request)
        
        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        // Check status code
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
        }
        
        // Decode response
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
    
    // Upload file using async/await
    func uploadFile(
        endpoint: String,
        fileURL: URL,
        mimeType: String,
        parameters: [String: String]? = nil
    ) async throws -> UploadResponse {
        // Construct URL
        let url = baseURL.appendingPathComponent(endpoint)
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.post.rawValue
        
        // Generate boundary
        let boundary = UUID().uuidString
        
        // Set content type
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Create body
        var body = Data()
        
        // Add parameters
        parameters?.forEach { key, value in
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // Add file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(try Data(contentsOf: fileURL))
        body.append("\r\n".data(using: .utf8)!)
        
        // Add closing boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // Set body
        request.httpBody = body
        
        // Perform request
        let (data, response) = try await session.data(for: request)
        
        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        // Check status code
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
        }
        
        // Decode response
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(UploadResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
    
    // Download file using async/await
    func downloadFile(
        endpoint: String,
        parameters: [String: Any]? = nil,
        destination: URL
    ) async throws -> URL {
        // Construct URL
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: true)!
        
        // Add query parameters
        if let parameters = parameters {
            urlComponents.queryItems = parameters.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
        }
        
        // Create request
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = HTTPMethod.get.rawValue
        
        // Perform download
        let (fileURL, response) = try await session.download(for: request)
        
        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        // Check status code
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode, data: Data())
        }
        
        // Move file to destination
        try FileManager.default.moveItem(at: fileURL, to: destination)
        
        return destination
    }
}

// HTTP Method enum
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

// API Error enum
enum APIError: Error {
    case invalidResponse
    case httpError(statusCode: Int, data: Data)
    case decodingError(Error)
    case invalidURL
    case networkError(Error)
}

// Upload Response model
struct UploadResponse: Codable {
    let id: String
    let url: String
    let filename: String
    let size: Int
}

// MARK: - Usage Examples

// Example service using async/await
class UserService {
    private let apiClient: AsyncAPIClient
    
    init(apiClient: AsyncAPIClient) {
        self.apiClient = apiClient
    }
    
    // Get user profile
    func getUserProfile() async throws -> UserProfile {
        return try await apiClient.request(endpoint: "users/profile")
    }
    
    // Update user profile
    func updateUserProfile(name: String, email: String) async throws -> UserProfile {
        return try await apiClient.request(
            endpoint: "users/profile",
            method: .put,
            parameters: ["name": name, "email": email]
        )
    }
    
    // Upload profile picture
    func uploadProfilePicture(imageURL: URL) async throws -> UploadResponse {
        return try await apiClient.uploadFile(
            endpoint: "users/profile/picture",
            fileURL: imageURL,
            mimeType: "image/jpeg"
        )
    }
}

// User Profile model
struct UserProfile: Codable {
    let id: String
    let name: String
    let email: String
    let profilePictureURL: String?
}

// Example view model using async/await
class ProfileViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var isLoading = false
    @Published var error: Error?
    
    private let userService: UserService
    
    init(userService: UserService) {
        self.userService = userService
    }
    
    // Load profile using async/await
    @MainActor
    func loadProfile() async {
        isLoading = true
        error = nil
        
        do {
            profile = try await userService.getUserProfile()
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    // Update profile using async/await
    @MainActor
    func updateProfile(name: String, email: String) async {
        isLoading = true
        error = nil
        
        do {
            profile = try await userService.updateUserProfile(name: name, email: email)
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    // Upload profile picture using async/await
    @MainActor
    func uploadProfilePicture(imageURL: URL) async {
        isLoading = true
        error = nil
        
        do {
            let response = try await userService.uploadProfilePicture(imageURL: imageURL)
            
            // Reload profile to get updated picture URL
            profile = try await userService.getUserProfile()
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
}

// Example view using async/await
struct ProfileView: View {
    @StateObject private var viewModel: ProfileViewModel
    
    init(viewModel: ProfileViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
            } else if let profile = viewModel.profile {
                Text("Name: \(profile.name)")
                Text("Email: \(profile.email)")
                
                Button("Refresh") {
                    Task {
                        await viewModel.loadProfile()
                    }
                }
            } else if let error = viewModel.error {
                Text("Error: \(error.localizedDescription)")
                
                Button("Retry") {
                    Task {
                        await viewModel.loadProfile()
                    }
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadProfile()
            }
        }
    }
}
```

### 1.2 Combine Implementation

```swift
// MARK: - Core Combine API Client

class CombineAPIClient {
    private let baseURL: URL
    private let session: URLSession
    
    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }
    
    // Generic request method using Combine
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: Any]? = nil,
        headers: [String: String]? = nil
    ) -> AnyPublisher<T, Error> {
        // Construct URL
        let url = baseURL.appendingPathComponent(endpoint)
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        // Add headers
        headers?.forEach { request.addValue($1, forHTTPHeaderField: $0) }
        
        // Add default headers
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add parameters
        if let parameters = parameters {
            do {
                switch method {
                case .get:
                    // Add query parameters
                    var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
                    components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
                    request.url = components.url
                    
                case .post, .put, .patch:
                    // Add body parameters
                    request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
                    
                case .delete:
                    // Add body parameters for DELETE if needed
                    if !parameters.isEmpty {
                        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
                    }
                }
            } catch {
                return Fail(error: APIError.networkError(error)).eraseToAnyPublisher()
            }
        }
        
        // Perform request
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                // Check response
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }
                
                // Check status code
                guard (200...299).contains(httpResponse.statusCode) else {
                    throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
                }
                
                return data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error in
                if let apiError = error as? APIError {
                    return apiError
                } else if error is DecodingError {
                    return APIError.decodingError(error)
                } else {
                    return APIError.networkError(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    // Upload file using Combine
    func uploadFile(
        endpoint: String,
        fileURL: URL,
        mimeType: String,
        parameters: [String: String]? = nil
    ) -> AnyPublisher<UploadResponse, Error> {
        // Construct URL
        let url = baseURL.appendingPathComponent(endpoint)
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.post.rawValue
        
        // Generate boundary
        let boundary = UUID().uuidString
        
        // Set content type
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Create body
        var body = Data()
        
        // Add parameters
        parameters?.forEach { key, value in
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // Add file
        do {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(try Data(contentsOf: fileURL))
            body.append("\r\n".data(using: .utf8)!)
            
            // Add closing boundary
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            // Set body
            request.httpBody = body
        } catch {
            return Fail(error: APIError.networkError(error)).eraseToAnyPublisher()
        }
        
        // Perform request
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                // Check response
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }
                
                // Check status code
                guard (200...299).contains(httpResponse.statusCode) else {
                    throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
                }
                
                return data
            }
            .decode(type: UploadResponse.self, decoder: JSONDecoder())
            .mapError { error in
                if let apiError = error as? APIError {
                    return apiError
                } else if error is DecodingError {
                    return APIError.decodingError(error)
                } else {
                    return APIError.networkError(error)
                }
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - Usage Examples

// Example service using Combine
class CombineUserService {
    private let apiClient: CombineAPIClient
    
    init(apiClient: CombineAPIClient) {
        self.apiClient = apiClient
    }
    
    // Get user profile
    func getUserProfile() -> AnyPublisher<UserProfile, Error> {
        return apiClient.request(endpoint: "users/profile")
    }
    
    // Update user profile
    func updateUserProfile(name: String, email: String) -> AnyPublisher<UserProfile, Error> {
        return apiClient.request(
            endpoint: "users/profile",
            method: .put,
            parameters: ["name": name, "email": email]
        )
    }
    
    // Upload profile picture
    func uploadProfilePicture(imageURL: URL) -> AnyPublisher<UploadResponse, Error> {
        return apiClient.uploadFile(
            endpoint: "users/profile/picture",
            fileURL: imageURL,
            mimeType: "image/jpeg"
        )
    }
}

// Example view model using Combine
class CombineProfileViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var isLoading = false
    @Published var error: Error?
    
    private let userService: CombineUserService
    private var cancellables = Set<AnyCancellable>()
    
    init(userService: CombineUserService) {
        self.userService = userService
    }
    
    // Load profile using Combine
    func loadProfile() {
        isLoading = true
        error = nil
        
        userService.getUserProfile()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    
                    self.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self.error = error
                    }
                },
                receiveValue: { [weak self] profile in
                    self?.profile = profile
                }
            )
            .store(in: &cancellables)
    }
    
    // Update profile using Combine
    func updateProfile(name: String, email: String) {
        isLoading = true
        error = nil
        
        userService.updateUserProfile(name: name, email: email)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    
                    self.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self.error = error
                    }
                },
                receiveValue: { [weak self] profile in
                    self?.profile = profile
                }
            )
            .store(in: &cancellables)
    }
    
    // Upload profile picture using Combine
    func uploadProfilePicture(imageURL: URL) {
        isLoading = true
        error = nil
        
        userService.uploadProfilePicture(imageURL: imageURL)
            .flatMap { [weak self] _ -> AnyPublisher<UserProfile, Error> in
                guard let self = self else {
                    return Fail(error: NSError(domain: "ProfileViewModel", code: -1, userInfo: nil)).eraseToAnyPublisher()
                }
                
                // Reload profile to get updated picture URL
                return self.userService.getUserProfile()
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    
                    self.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self.error = error
                    }
                },
                receiveValue: { [weak self] profile in
                    self?.profile = profile
                }
            )
            .store(in: &cancellables)
    }
}

// Example view using Combine
struct CombineProfileView: View {
    @StateObject private var viewModel: CombineProfileViewModel
    
    init(viewModel: CombineProfileViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
            } else if let profile = viewModel.profile {
                Text("Name: \(profile.name)")
                Text("Email: \(profile.email)")
                
                Button("Refresh") {
                    viewModel.loadProfile()
                }
            } else if let error = viewModel.error {
                Text("Error: \(error.localizedDescription)")
                
                Button("Retry") {
                    viewModel.loadProfile()
                }
            }
        }
        .onAppear {
            viewModel.loadProfile()
        }
    }
}
```

### 1.3 Hybrid Approach (Combining Async/Await with Combine)

```swift
// MARK: - Hybrid API Client

class HybridAPIClient {
    private let baseURL: URL
    private let session: URLSession
    
    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }
    
    // Async/await method
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: Any]? = nil,
        headers: [String: String]? = nil
    ) async throws -> T {
        // Implementation as in AsyncAPIClient
        // ...
        
        // Placeholder implementation
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        // Configure request...
        
        let (data, response) = try await session.data(for: request)
        
        // Process response...
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    // Combine method that wraps the async method
    func requestPublisher<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: Any]? = nil,
        headers: [String: String]? = nil
    ) -> AnyPublisher<T, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(APIError.invalidResponse))
                return
            }
            
            Task {
                do {
                    let result = try await self.request(
                        endpoint: endpoint,
                        method: method,
                        parameters: parameters,
                        headers: headers
                    ) as T
                    
                    promise(.success(result))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Combine Extensions for Async/Await

extension Publisher {
    // Convert publisher to async/await
    func asyncFirst() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            
            cancellable = first()
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                        
                        cancellable?.cancel()
                    },
                    receiveValue: { value in
                        continuation.resume(returning: value)
                        cancellable?.cancel()
                    }
                )
        }
    }
    
    // Convert publisher to async sequence
    func values() -> AsyncThrowingPublisher<Self> {
        AsyncThrowingPublisher(self)
    }
}

// Async publisher wrapper
struct AsyncThrowingPublisher<P: Publisher>: AsyncSequence {
    typealias Element = P.Output
    typealias AsyncIterator = Iterator
    
    struct Iterator: AsyncIteratorProtocol {
        private let publisher: P
        private var continuation: AsyncThrowingStream<P.Output, Error>.Continuation?
        private var cancellable: AnyCancellable?
        private var stream: AsyncThrowingStream<P.Output, Error>?
        
        init(publisher: P) {
            self.publisher = publisher
            
            let (stream, continuation) = AsyncThrowingStream<P.Output, Error>.makeStream()
            self.stream = stream
            self.continuation = continuation
            
            self.cancellable = publisher.sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        continuation.finish()
                    case .failure(let error):
                        continuation.finish(throwing: error)
                    }
                },
                receiveValue: { value in
                    continuation.yield(value)
                }
            )
        }
        
        mutating func next() async throws -> P.Output? {
            try await stream?.next()
        }
    }
    
    let publisher: P
    
    init(_ publisher: P) {
        self.publisher = publisher
    }
    
    func makeAsyncIterator() -> Iterator {
        Iterator(publisher: publisher)
    }
}

// MARK: - Usage Examples

// Example service using hybrid approach
class HybridUserService {
    private let apiClient: HybridAPIClient
    
    init(apiClient: HybridAPIClient) {
        self.apiClient = apiClient
    }
    
    // Async/await methods
    func getUserProfile() async throws -> UserProfile {
        return try await apiClient.request(endpoint: "users/profile")
    }
    
    func updateUserProfile(name: String, email: String) async throws -> UserProfile {
        return try await apiClient.request(
            endpoint: "users/profile",
            method: .put,
            parameters: ["name": name, "email": email]
        )
    }
    
    // Combine methods
    func getUserProfilePublisher() -> AnyPublisher<UserProfile, Error> {
        return apiClient.requestPublisher(endpoint: "users/profile")
    }
    
    func updateUserProfilePublisher(name: String, email: String) -> AnyPublisher<UserProfile, Error> {
        return apiClient.requestPublisher(
            endpoint: "users/profile",
            method: .put,
            parameters: ["name": name, "email": email]
        )
    }
}

// Example view model using hybrid approach
class HybridProfileViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var isLoading = false
    @Published var error: Error?
    
    private let userService: HybridUserService
    private var cancellables = Set<AnyCancellable>()
    
    init(userService: HybridUserService) {
        self.userService = userService
    }
    
    // Load profile using async/await
    @MainActor
    func loadProfileAsync() async {
        isLoading = true
        error = nil
        
        do {
            profile = try await userService.getUserProfile()
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    // Load profile using Combine
    func loadProfileCombine() {
        isLoading = true
        error = nil
        
        userService.getUserProfilePublisher()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    
                    self.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self.error = error
                    }
                },
                receiveValue: { [weak self] profile in
                    self?.profile = profile
                }
            )
            .store(in: &cancellables)
    }
    
    // Convert Combine publisher to async/await
    @MainActor
    func loadProfileHybrid() async {
        isLoading = true
        error = nil
        
        do {
            profile = try await userService.getUserProfilePublisher().asyncFirst()
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    // Process async sequence from publisher
    @MainActor
    func processProfileUpdates() async {
        let profileUpdates = userService.getUserProfilePublisher()
            .receive(on: DispatchQueue.main)
            .values()
        
        do {
            for try await profile in profileUpdates {
                self.profile = profile
                // Process each update as it arrives
            }
        } catch {
            self.error = error
        }
    }
}
```

### 1.4 Recommended Approach for Mac Client

For the OpenHands Mac client, we recommend a hybrid approach that leverages both async/await and Combine:

1. **Use async/await for:**
   - Network requests and file operations
   - Sequential operations with clear dependencies
   - Error handling with try/catch
   - Background processing with Task

2. **Use Combine for:**
   - UI state management and binding
   - Event streams and real-time updates (like Socket.IO events)
   - Reactive data transformations
   - Coordinating multiple asynchronous operations

3. **Integration patterns:**
   - Convert between async/await and Combine using the bridge methods shown above
   - Use @MainActor for UI updates from async code
   - Use Combine's receive(on:) for thread management

This hybrid approach gives us the best of both worlds: the clarity and error handling of async/await with the reactive capabilities of Combine.

## 2. Property Wrapper Usage for State Management

### 2.1 Custom Property Wrappers

```swift
// MARK: - Persistence Property Wrapper

@propertyWrapper
struct Persisted<T: Codable> {
    private let key: String
    private let defaultValue: T
    private let storage: UserDefaults
    
    init(wrappedValue defaultValue: T, key: String, storage: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.storage = storage
    }
    
    var wrappedValue: T {
        get {
            guard let data = storage.data(forKey: key) else {
                return defaultValue
            }
            
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                print("Error decoding \(T.self) from UserDefaults: \(error)")
                return defaultValue
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                storage.set(data, forKey: key)
            } catch {
                print("Error encoding \(T.self) to UserDefaults: \(error)")
            }
        }
    }
    
    var projectedValue: Binding<T> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }
}

// MARK: - Throttled Property Wrapper

@propertyWrapper
class Throttled<T> {
    private var value: T
    private let duration: TimeInterval
    private var lastUpdateTime: Date = .distantPast
    private var timer: Timer?
    private var pendingValue: T?
    
    init(wrappedValue: T, duration: TimeInterval) {
        self.value = wrappedValue
        self.duration = duration
    }
    
    var wrappedValue: T {
        get { value }
        set {
            let now = Date()
            let timeSinceLastUpdate = now.timeIntervalSince(lastUpdateTime)
            
            if timeSinceLastUpdate >= duration {
                // Update immediately
                value = newValue
                lastUpdateTime = now
                pendingValue = nil
                timer?.invalidate()
                timer = nil
            } else {
                // Schedule update
                pendingValue = newValue
                
                if timer == nil {
                    let delay = duration - timeSinceLastUpdate
                    timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                        guard let self = self, let pendingValue = self.pendingValue else { return }
                        
                        self.value = pendingValue
                        self.lastUpdateTime = Date()
                        self.pendingValue = nil
                        self.timer = nil
                    }
                }
            }
        }
    }
    
    var projectedValue: Binding<T> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }
}

// MARK: - Validated Property Wrapper

@propertyWrapper
struct Validated<T> {
    private var value: T
    private let validator: (T) -> Bool
    private let errorMessage: String
    
    var isValid: Bool {
        validator(value)
    }
    
    var validationError: String? {
        isValid ? nil : errorMessage
    }
    
    init(wrappedValue: T, validator: @escaping (T) -> Bool, errorMessage: String) {
        self.value = wrappedValue
        self.validator = validator
        self.errorMessage = errorMessage
    }
    
    var wrappedValue: T {
        get { value }
        set { value = newValue }
    }
    
    var projectedValue: ValidatedValue<T> {
        ValidatedValue(value: value, isValid: isValid, errorMessage: validationError)
    }
}

struct ValidatedValue<T> {
    let value: T
    let isValid: Bool
    let errorMessage: String?
}

// MARK: - Observable Property Wrapper

@propertyWrapper
class Observable<T> {
    private var value: T
    private var observers: [(T) -> Void] = []
    
    init(wrappedValue: T) {
        self.value = wrappedValue
    }
    
    var wrappedValue: T {
        get { value }
        set {
            value = newValue
            notifyObservers()
        }
    }
    
    var projectedValue: Observable<T> {
        return self
    }
    
    func observe(_ observer: @escaping (T) -> Void) -> ObservationToken {
        observers.append(observer)
        observer(value) // Notify with current value
        
        return ObservationToken { [weak self] in
            self?.observers.removeAll { $0 as AnyObject === observer as AnyObject }
        }
    }
    
    private func notifyObservers() {
        observers.forEach { $0(value) }
    }
}

class ObservationToken {
    private let cancellation: () -> Void
    
    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }
    
    func cancel() {
        cancellation()
    }
    
    deinit {
        cancel()
    }
}

// MARK: - Debounced Property Wrapper

@propertyWrapper
class Debounced<T> {
    private var value: T
    private let delay: TimeInterval
    private var timer: Timer?
    
    init(wrappedValue: T, delay: TimeInterval) {
        self.value = wrappedValue
        self.delay = delay
    }
    
    var wrappedValue: T {
        get { value }
        set {
            timer?.invalidate()
            
            timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                self.value = newValue
                self.timer = nil
            }
        }
    }
    
    var projectedValue: Binding<T> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }
}
```

### 2.2 State Management with Property Wrappers

```swift
// MARK: - App Settings with Property Wrappers

class AppSettings {
    @Persisted(key: "theme")
    var theme: AppTheme = .system
    
    @Persisted(key: "fontSize")
    var fontSize: Int = 14
    
    @Persisted(key: "enableNotifications")
    var enableNotifications: Bool = true
    
    @Persisted(key: "autoSaveInterval")
    var autoSaveInterval: TimeInterval = 60.0
    
    @Persisted(key: "recentFiles")
    var recentFiles: [RecentFile] = []
    
    @Throttled(duration: 0.5)
    var searchQuery: String = ""
    
    @Validated(validator: { $0.count >= 3 }, errorMessage: "Username must be at least 3 characters")
    var username: String = ""
    
    @Observable
    var connectionStatus: ConnectionStatus = .disconnected
    
    @Debounced(delay: 0.3)
    var windowSize: CGSize = .zero
}

// MARK: - View Model with Property Wrappers

class SearchViewModel: ObservableObject {
    @Published var results: [SearchResult] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    @Throttled(duration: 0.5)
    var searchQuery: String = ""
    
    @Persisted(key: "recentSearches")
    var recentSearches: [String] = []
    
    private let searchService: SearchService
    private var cancellables = Set<AnyCancellable>()
    
    init(searchService: SearchService) {
        self.searchService = searchService
        
        // Observe throttled search query changes
        $searchQuery.sink { [weak self] query in
            guard let self = self, !query.isEmpty else { return }
            self.performSearch(query: query)
        }
        .store(in: &cancellables)
    }
    
    private func performSearch(query: String) {
        isLoading = true
        error = nil
        
        searchService.search(query: query)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    
                    self.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self.error = error
                    } else {
                        // Add to recent searches
                        if !self.recentSearches.contains(query) {
                            self.recentSearches.insert(query, at: 0)
                            
                            // Limit recent searches
                            if self.recentSearches.count > 10 {
                                self.recentSearches = Array(self.recentSearches.prefix(10))
                            }
                        }
                    }
                },
                receiveValue: { [weak self] results in
                    self?.results = results
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - SwiftUI View with Property Wrappers

struct SettingsView: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.presentationMode) var presentationMode
    
    @State private var tempUsername: String = ""
    @State private var showUsernameError = false
    
    var body: some View {
        Form {
            Section(header: Text("Appearance")) {
                Picker("Theme", selection: $appSettings.theme) {
                    Text("System").tag(AppTheme.system)
                    Text("Light").tag(AppTheme.light)
                    Text("Dark").tag(AppTheme.dark)
                }
                
                Stepper("Font Size: \(appSettings.fontSize)", value: $appSettings.fontSize, in: 10...24)
            }
            
            Section(header: Text("Notifications")) {
                Toggle("Enable Notifications", isOn: $appSettings.enableNotifications)
            }
            
            Section(header: Text("Auto Save")) {
                Picker("Auto Save Interval", selection: $appSettings.autoSaveInterval) {
                    Text("30 seconds").tag(30.0)
                    Text("1 minute").tag(60.0)
                    Text("5 minutes").tag(300.0)
                    Text("10 minutes").tag(600.0)
                }
            }
            
            Section(header: Text("User Profile")) {
                TextField("Username", text: $tempUsername)
                    .onAppear {
                        tempUsername = appSettings.username
                    }
                
                if showUsernameError, let error = appSettings.$username.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Button("Save Username") {
                    appSettings.username = tempUsername
                    showUsernameError = !appSettings.$username.isValid
                }
                .disabled(tempUsername.isEmpty)
            }
            
            Section(header: Text("Recent Files")) {
                if appSettings.recentFiles.isEmpty {
                    Text("No recent files")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(appSettings.recentFiles) { file in
                        Text(file.path)
                    }
                    .onDelete { indexSet in
                        appSettings.recentFiles.remove(atOffsets: indexSet)
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}
```

### 2.3 Recommended Property Wrappers for Mac Client

For the OpenHands Mac client, we recommend the following property wrapper usage:

1. **@Published** - For SwiftUI binding and Combine integration
2. **@State, @StateObject, @ObservedObject, @EnvironmentObject** - For SwiftUI state management
3. **@Persisted** - For persistent settings and user preferences
4. **@Throttled** - For search queries and frequent UI updates
5. **@Validated** - For form validation
6. **@Observable** - For non-UI state that needs observation
7. **@Debounced** - For window resizing and other events that should be delayed

These property wrappers provide a clean, declarative way to manage state throughout the application while handling common patterns like persistence, validation, and throttling.

## 3. Dependency Injection Approach

### 3.1 Service Locator Pattern

```swift
// MARK: - Service Locator

class ServiceLocator {
    static let shared = ServiceLocator()
    
    private var services: [String: Any] = [:]
    
    private init() {}
    
    // Register a service
    func register<T>(_ service: T, for type: T.Type) {
        let key = String(describing: type)
        services[key] = service
    }
    
    // Resolve a service
    func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        return services[key] as? T
    }
    
    // Remove a service
    func remove<T>(_ type: T.Type) {
        let key = String(describing: type)
        services.removeValue(forKey: key)
    }
    
    // Clear all services
    func clear() {
        services.removeAll()
    }
}

// MARK: - Service Protocol Definitions

protocol APIClientProtocol {
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod,
        parameters: [String: Any]?,
        headers: [String: String]?
    ) async throws -> T
}

protocol UserServiceProtocol {
    func getUserProfile() async throws -> UserProfile
    func updateUserProfile(name: String, email: String) async throws -> UserProfile
}

protocol AuthServiceProtocol {
    func signIn(email: String, password: String) async throws -> AuthToken
    func signOut() async throws
    func refreshToken() async throws -> AuthToken
    var isAuthenticated: Bool { get }
}

// MARK: - Service Implementations

class APIClient: APIClientProtocol {
    private let baseURL: URL
    
    init(baseURL: URL) {
        self.baseURL = baseURL
    }
    
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: Any]? = nil,
        headers: [String: String]? = nil
    ) async throws -> T {
        // Implementation...
        fatalError("Not implemented")
    }
}

class UserService: UserServiceProtocol {
    private let apiClient: APIClientProtocol
    
    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }
    
    func getUserProfile() async throws -> UserProfile {
        return try await apiClient.request(
            endpoint: "users/profile",
            method: .get,
            parameters: nil,
            headers: nil
        )
    }
    
    func updateUserProfile(name: String, email: String) async throws -> UserProfile {
        return try await apiClient.request(
            endpoint: "users/profile",
            method: .put,
            parameters: ["name": name, "email": email],
            headers: nil
        )
    }
}

class AuthService: AuthServiceProtocol {
    private let apiClient: APIClientProtocol
    private var token: AuthToken?
    
    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }
    
    var isAuthenticated: Bool {
        token != nil && !(token?.isExpired ?? true)
    }
    
    func signIn(email: String, password: String) async throws -> AuthToken {
        let token: AuthToken = try await apiClient.request(
            endpoint: "auth/signin",
            method: .post,
            parameters: ["email": email, "password": password],
            headers: nil
        )
        
        self.token = token
        return token
    }
    
    func signOut() async throws {
        try await apiClient.request(
            endpoint: "auth/signout",
            method: .post,
            parameters: nil,
            headers: nil
        ) as EmptyResponse
        
        token = nil
    }
    
    func refreshToken() async throws -> AuthToken {
        guard let currentToken = token else {
            throw AuthError.notAuthenticated
        }
        
        let token: AuthToken = try await apiClient.request(
            endpoint: "auth/refresh",
            method: .post,
            parameters: ["refreshToken": currentToken.refreshToken],
            headers: nil
        )
        
        self.token = token
        return token
    }
}

// MARK: - Models

struct AuthToken: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    
    var isExpired: Bool {
        Date() >= expiresAt
    }
}

struct EmptyResponse: Codable {}

enum AuthError: Error {
    case notAuthenticated
    case invalidCredentials
    case tokenExpired
}

// MARK: - Service Registration

func registerServices() {
    let baseURL = URL(string: "https://api.example.com")!
    
    // Create services
    let apiClient = APIClient(baseURL: baseURL)
    let userService = UserService(apiClient: apiClient)
    let authService = AuthService(apiClient: apiClient)
    
    // Register services
    let serviceLocator = ServiceLocator.shared
    serviceLocator.register(apiClient, for: APIClientProtocol.self)
    serviceLocator.register(userService, for: UserServiceProtocol.self)
    serviceLocator.register(authService, for: AuthServiceProtocol.self)
}

// MARK: - Service Usage

class ProfileViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var isLoading = false
    @Published var error: Error?
    
    private let userService: UserServiceProtocol
    
    init(userService: UserServiceProtocol? = nil) {
        // Use provided service or resolve from service locator
        self.userService = userService ?? ServiceLocator.shared.resolve(UserServiceProtocol.self)!
    }
    
    @MainActor
    func loadProfile() async {
        isLoading = true
        error = nil
        
        do {
            profile = try await userService.getUserProfile()
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
}
```

### 3.2 Property Injection

```swift
// MARK: - Property Injection

protocol Injectable {}

@propertyWrapper
struct Inject<T> {
    private var service: T
    
    init() {
        guard let resolvedService = ServiceLocator.shared.resolve(T.self) else {
            fatalError("Failed to resolve service of type \(T.self)")
        }
        
        self.service = resolvedService
    }
    
    var wrappedValue: T {
        get { return service }
        mutating set { service = newValue }
    }
}

// MARK: - Usage

class UserProfileViewModel: ObservableObject, Injectable {
    @Inject private var userService: UserServiceProtocol
    @Inject private var authService: AuthServiceProtocol
    
    @Published var profile: UserProfile?
    @Published var isLoading = false
    @Published var error: Error?
    
    @MainActor
    func loadProfile() async {
        guard authService.isAuthenticated else {
            error = AuthError.notAuthenticated
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            profile = try await userService.getUserProfile()
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
}
```

### 3.3 Factory Pattern

```swift
// MARK: - Factory Pattern

protocol ViewModelFactory {
    func makeProfileViewModel() -> ProfileViewModel
    func makeSettingsViewModel() -> SettingsViewModel
    func makeSearchViewModel() -> SearchViewModel
}

class DefaultViewModelFactory: ViewModelFactory {
    private let serviceLocator: ServiceLocator
    
    init(serviceLocator: ServiceLocator = .shared) {
        self.serviceLocator = serviceLocator
    }
    
    func makeProfileViewModel() -> ProfileViewModel {
        guard let userService = serviceLocator.resolve(UserServiceProtocol.self) else {
            fatalError("Failed to resolve UserService")
        }
        
        return ProfileViewModel(userService: userService)
    }
    
    func makeSettingsViewModel() -> SettingsViewModel {
        guard let userService = serviceLocator.resolve(UserServiceProtocol.self),
              let appSettings = serviceLocator.resolve(AppSettings.self) else {
            fatalError("Failed to resolve services for SettingsViewModel")
        }
        
        return SettingsViewModel(userService: userService, appSettings: appSettings)
    }
    
    func makeSearchViewModel() -> SearchViewModel {
        guard let searchService = serviceLocator.resolve(SearchService.self) else {
            fatalError("Failed to resolve SearchService")
        }
        
        return SearchViewModel(searchService: searchService)
    }
}

// MARK: - Usage with Factory

class AppCoordinator {
    private let viewModelFactory: ViewModelFactory
    
    init(viewModelFactory: ViewModelFactory = DefaultViewModelFactory()) {
        self.viewModelFactory = viewModelFactory
    }
    
    func makeProfileView() -> some View {
        let viewModel = viewModelFactory.makeProfileViewModel()
        return ProfileView(viewModel: viewModel)
    }
    
    func makeSettingsView() -> some View {
        let viewModel = viewModelFactory.makeSettingsViewModel()
        return SettingsView(viewModel: viewModel)
    }
    
    func makeSearchView() -> some View {
        let viewModel = viewModelFactory.makeSearchViewModel()
        return SearchView(viewModel: viewModel)
    }
}
```

### 3.4 Environment Values

```swift
// MARK: - Environment Values

// Define environment keys
private struct UserServiceKey: EnvironmentKey {
    static let defaultValue: UserServiceProtocol = MockUserService()
}

private struct AuthServiceKey: EnvironmentKey {
    static let defaultValue: AuthServiceProtocol = MockAuthService()
}

private struct APIClientKey: EnvironmentKey {
    static let defaultValue: APIClientProtocol = MockAPIClient()
}

// Extend EnvironmentValues
extension EnvironmentValues {
    var userService: UserServiceProtocol {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }
    
    var authService: AuthServiceProtocol {
        get { self[AuthServiceKey.self] }
        set { self[AuthServiceKey.self] = newValue }
    }
    
    var apiClient: APIClientProtocol {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }
}

// Mock implementations for default values
class MockUserService: UserServiceProtocol {
    func getUserProfile() async throws -> UserProfile {
        throw NSError(domain: "MockUserService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not implemented"])
    }
    
    func updateUserProfile(name: String, email: String) async throws -> UserProfile {
        throw NSError(domain: "MockUserService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not implemented"])
    }
}

class MockAuthService: AuthServiceProtocol {
    var isAuthenticated: Bool = false
    
    func signIn(email: String, password: String) async throws -> AuthToken {
        throw NSError(domain: "MockAuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not implemented"])
    }
    
    func signOut() async throws {
        throw NSError(domain: "MockAuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not implemented"])
    }
    
    func refreshToken() async throws -> AuthToken {
        throw NSError(domain: "MockAuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not implemented"])
    }
}

class MockAPIClient: APIClientProtocol {
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod,
        parameters: [String: Any]?,
        headers: [String: String]?
    ) async throws -> T {
        throw NSError(domain: "MockAPIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not implemented"])
    }
}

// MARK: - Usage with Environment

struct ProfileEnvironmentView: View {
    @Environment(\.userService) private var userService
    @Environment(\.authService) private var authService
    
    @StateObject private var viewModel = ProfileEnvironmentViewModel()
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
            } else if let profile = viewModel.profile {
                Text("Name: \(profile.name)")
                Text("Email: \(profile.email)")
                
                Button("Refresh") {
                    Task {
                        await viewModel.loadProfile()
                    }
                }
            } else if let error = viewModel.error {
                Text("Error: \(error.localizedDescription)")
                
                Button("Retry") {
                    Task {
                        await viewModel.loadProfile()
                    }
                }
            }
        }
        .onAppear {
            // Inject dependencies from environment
            viewModel.userService = userService
            viewModel.authService = authService
            
            Task {
                await viewModel.loadProfile()
            }
        }
    }
}

class ProfileEnvironmentViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var isLoading = false
    @Published var error: Error?
    
    var userService: UserServiceProtocol!
    var authService: AuthServiceProtocol!
    
    @MainActor
    func loadProfile() async {
        guard let userService = userService, let authService = authService else {
            error = NSError(domain: "ProfileViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Services not initialized"])
            return
        }
        
        guard authService.isAuthenticated else {
            error = AuthError.notAuthenticated
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            profile = try await userService.getUserProfile()
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
}

// Set up environment in app
struct MainApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.userService, UserService(apiClient: APIClient(baseURL: URL(string: "https://api.example.com")!)))
                .environment(\.authService, AuthService(apiClient: APIClient(baseURL: URL(string: "https://api.example.com")!)))
                .environment(\.apiClient, APIClient(baseURL: URL(string: "https://api.example.com")!))
        }
    }
}
```

### 3.5 Recommended Dependency Injection Approach for Mac Client

For the OpenHands Mac client, we recommend a hybrid approach to dependency injection:

1. **Service Locator Pattern** for global services:
   - Core services like API clients, Socket.IO manager, and authentication
   - Persistence managers and cache managers
   - Logging and analytics services

2. **Property Injection** for view models:
   - Use the `@Inject` property wrapper for cleaner dependency injection
   - Makes testing easier by allowing mock services to be injected

3. **Factory Pattern** for complex object creation:
   - ViewModelFactory for creating view models with proper dependencies
   - ServiceFactory for creating services with proper configuration

4. **Environment Values** for SwiftUI integration:
   - Use for services that need to be accessible throughout the view hierarchy
   - Particularly useful for theme, localization, and user preferences

This hybrid approach provides flexibility while maintaining clean architecture and testability. The Service Locator pattern gives us a central place to register and resolve dependencies, while property injection and factories provide a clean way to use those dependencies in our code.

## 4. Implementation Guidelines

### 4.1 Recommended Swift Features

1. **Swift Concurrency**:
   - Use `async/await` for asynchronous operations
   - Use `Task` for background work
   - Use `@MainActor` for UI updates

2. **Combine**:
   - Use for reactive programming and data binding
   - Use for event streams and real-time updates
   - Use for coordinating multiple asynchronous operations

3. **Property Wrappers**:
   - Use `@Published` for SwiftUI binding
   - Use custom property wrappers for persistence, validation, etc.

4. **Result Builders**:
   - Use for building complex UI hierarchies
   - Use for building complex query expressions

5. **Actors**:
   - Use for thread-safe state management
   - Use for isolating mutable state

### 4.2 Code Organization

1. **Module Structure**:
   - Core: Base protocols, extensions, and utilities
   - Services: API clients, Socket.IO, file system, etc.
   - Models: Data models and state
   - ViewModels: Business logic and state management
   - Views: UI components and screens
   - Coordinators: Navigation and flow control

2. **File Organization**:
   - Group related files together
   - Use extensions for protocol conformance
   - Keep files focused on a single responsibility

3. **Naming Conventions**:
   - Use clear, descriptive names
   - Use verb-noun pairs for actions (e.g., `loadProfile()`)
   - Use noun phrases for properties (e.g., `userProfile`)
   - Use protocol names that describe capabilities (e.g., `UserServiceProtocol`)

### 4.3 Testing Approach

1. **Unit Testing**:
   - Test services and view models
   - Use dependency injection for testability
   - Use mock objects for dependencies

2. **UI Testing**:
   - Test key user flows
   - Use accessibility identifiers for UI elements
   - Use test plans for different configurations

3. **Test Doubles**:
   - Use mocks for verifying interactions
   - Use stubs for providing test data
   - Use fakes for simulating complex behavior

This implementation guide provides a comprehensive approach to Swift implementation details for the Mac client, covering concurrency, property wrappers, and dependency injection patterns.