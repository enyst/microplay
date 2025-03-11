import Foundation

print("Hello, Swift on Linux!")

// Demonstrate some Swift features
let numbers = [1, 2, 3, 4, 5]
let doubled = numbers.map { $0 * 2 }
print("Doubled numbers: \(doubled)")

// Demonstrate string manipulation
let greeting = "Hello"
let name = "World"
let fullGreeting = "\(greeting), \(name)!"
print(fullGreeting)

// Demonstrate date handling
let now = Date()
let formatter = DateFormatter()
formatter.dateStyle = .full
formatter.timeStyle = .medium
print("Current date and time: \(formatter.string(from: now))")

// Demonstrate error handling
enum SimpleError: Error {
    case somethingWentWrong
}

func mayThrow() throws -> String {
    let shouldThrow = false
    if shouldThrow {
        throw SimpleError.somethingWentWrong
    }
    return "Success!"
}

do {
    let result = try mayThrow()
    print("Result: \(result)")
} catch {
    print("Error: \(error)")
}

print("Swift on Linux is working correctly!")