import XCTest
import Combine
@testable import OpenHandsClient

final class APIServiceTests: XCTestCase {
    var cancellables = Set<AnyCancellable>()
    
    func testGetRequest() {
        // Create mock settings
        let settings = BackendSettings(backendHost: "localhost", backendPort: 8000)
        
        // Create a mock URL session
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        
        // Create API service with mock session
        let apiService = APIService(settings: settings, session: session)
        
        // Set up mock response
        let testData = """
        {
            "id": "test-id",
            "name": "test-name"
        }
        """.data(using: .utf8)!
        
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else {
                throw URLError(.badURL)
            }
            
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            
            return (response, testData)
        }
        
        // Set up expectations
        let getExpectation = expectation(description: "GET request completed")
        
        // Define a test model
        struct TestModel: Codable, Equatable {
            let id: String
            let name: String
        }
        
        // Perform GET request
        apiService.get(endpoint: "test")
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("GET request failed: \(error.localizedDescription)")
                    }
                },
                receiveValue: { (model: TestModel) in
                    XCTAssertEqual(model.id, "test-id")
                    XCTAssertEqual(model.name, "test-name")
                    getExpectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        // Wait for expectations
        wait(for: [getExpectation], timeout: 1.0)
    }
    
    func testPostRequest() {
        // Create mock settings
        let settings = BackendSettings(backendHost: "localhost", backendPort: 8000)
        
        // Create a mock URL session
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        
        // Create API service with mock session
        let apiService = APIService(settings: settings, session: session)
        
        // Set up mock response
        let testData = """
        {
            "id": "test-id",
            "success": true
        }
        """.data(using: .utf8)!
        
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else {
                throw URLError(.badURL)
            }
            
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            
            return (response, testData)
        }
        
        // Set up expectations
        let postExpectation = expectation(description: "POST request completed")
        
        // Define test models
        struct TestRequestModel: Codable {
            let name: String
            let value: Int
        }
        
        struct TestResponseModel: Codable, Equatable {
            let id: String
            let success: Bool
        }
        
        // Create request body
        let requestBody = TestRequestModel(name: "test", value: 42)
        
        // Perform POST request
        apiService.post(endpoint: "test", body: requestBody)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("POST request failed: \(error.localizedDescription)")
                    }
                },
                receiveValue: { (model: TestResponseModel) in
                    XCTAssertEqual(model.id, "test-id")
                    XCTAssertTrue(model.success)
                    postExpectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        // Wait for expectations
        wait(for: [postExpectation], timeout: 1.0)
    }
}

// Mock URL protocol for testing
class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    override func stopLoading() {}
}