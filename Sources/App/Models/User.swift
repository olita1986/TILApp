import Foundation
import Vapor
import FluentPostgreSQL
import Authentication

final class User: Codable {
    var id: UUID?
    var name: String
    var username: String
    var password: String
    var email: String
    var twitterURL: String?
    init(name: String, username: String, password: String, email: String, twitterURL: String?) {
        self.name = name
        self.username = username
        self.password = password
        self.email = email
        self.twitterURL = twitterURL
    }

    final class Public: Codable {
        var id: UUID?
        var name: String
        var username: String
        init(id: UUID?, name: String, username: String) {
            self.id = id
            self.name = name
            self.username = username
        }
    }

    final class PublicV2: Codable {
        var id: UUID?
        var name: String
        var username: String
        var twitterURL: String?
        init(id: UUID?,
             name: String,
             username: String,
             twitterURL: String? = nil) {
            self.id = id
            self.name = name
            self.username = username
            self.twitterURL = twitterURL
        }
    }
}

extension User: PostgreSQLUUIDModel {}
extension User: Content {}
extension User: Migration {
    static func prepare(on connection: PostgreSQLConnection)
        -> Future<Void> {
            return Database.create(self, on: connection) { builder in
                // 2
                builder.field(for: \.id, isIdentifier: true)
                builder.field(for: \.name)
                builder.field(for: \.username)
                builder.field(for: \.password)
                builder.field(for: \.email)
                // this tells the database that username should be unique
                builder.unique(on: \.username)
                builder.unique(on: \.email)
            }
    }
}
extension User: Parameter {}
extension User.Public: Content {}

extension User {
    // this adds parent-children relation with acronyms
    var acronyms: Children<User, Acronym> {
        // 2
        return children(\.userID)
    }
}

extension User {
    // 1
    func convertToPublic() -> User.Public {
        // 2
        return User.Public(id: id, name: name, username: username)
    }

    func convertToPublicV2() -> User.PublicV2 {
        return User.PublicV2(
            id: id,
            name: name,
            username: username,
            twitterURL: twitterURL)
    }
}

// 1
extension Future where T: User {
    // 2
    func convertToPublic() -> Future<User.Public> {
        // 3
        return self.map(to: User.Public.self) { user in
            // 4
            return user.convertToPublic()
        }
    }

    func convertToPublicV2() -> Future<User.PublicV2> {
        return self.map(to: User.PublicV2.self) { user in
            return user.convertToPublicV2()
        }
    }
}

// 1
extension User: BasicAuthenticatable {
    // 2
    static let usernameKey: UsernameKey = \User.username
    // 3
    static let passwordKey: PasswordKey = \User.password
}

// 1
extension User: TokenAuthenticatable {
    // 2
    typealias TokenType = Token
}

// 1
struct AdminUser: Migration {
    // 2
    typealias Database = PostgreSQLDatabase
    // 3
    static func prepare(on connection: PostgreSQLConnection)
        -> Future<Void> {
            // 4
            let password = try? BCrypt.hash("password")
            guard let hashedPassword = password else {
                fatalError("Failed to create admin user")
            }
            // 5
            let user = User(
                name: "Admin",
                username: "admin",
                password: hashedPassword,
                email: "admin@localhost.local",
                twitterURL: nil)
            // 6
            return user.save(on: connection).transform(to: ())
    }
    // 7
    static func revert(on connection: PostgreSQLConnection)
        -> Future<Void> {
            return .done(on: connection)
    }
}

// 1
extension User: PasswordAuthenticatable {}
// 2
extension User: SessionAuthenticatable {}

extension User.PublicV2: Content {}
