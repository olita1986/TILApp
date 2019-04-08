import Vapor
import Crypto
// 1
struct UsersController: RouteCollection {
    // 2
    func boot(router: Router) throws {
        let usersRoute = router.grouped("api", "users")
        usersRoute.get(use: getAllHandler)
        usersRoute.get(User.parameter, use: getHandler)
        usersRoute.get(
            User.parameter, "acronyms",
            use: getAcronymsHandler)
        // 1
        let basicAuthMiddleware =
            User.basicAuthMiddleware(using: BCryptDigest())
        let basicAuthGroup = usersRoute.grouped(basicAuthMiddleware)
        // 2
        basicAuthGroup.post("login", use: loginHandler)
        let tokenAuthMiddleware = User.tokenAuthMiddleware()
        let guardAuthMiddleware = User.guardAuthMiddleware()
        let tokenAuthGroup = usersRoute.grouped(
            tokenAuthMiddleware,
            guardAuthMiddleware)
        tokenAuthGroup.post(User.self, use: createHandler)

        // API Version 2 Routes
        // 1
        let usersV2Route = router.grouped("api", "v2", "users")
        // 2
        usersV2Route.get(User.parameter, use: getV2Handler)
    }
    // 5
    func createHandler(
        _ req: Request,
        user: User
        ) throws -> Future<User.Public> {
        user.password = try BCrypt.hash(user.password)
        return user.save(on: req).convertToPublic()
    }

    // 1
    func getAllHandler(_ req: Request) throws -> Future<[User.Public]> {
        // 2
        return User.query(on: req).decode(data: User.Public.self).all()
    }
    // 3
    func getHandler(_ req: Request) throws -> Future<User.Public> {
        // 4
        return try req.parameters.next(User.self).convertToPublic()
    }

    // 1
    func getV2Handler(_ req: Request) throws
        -> Future<User.PublicV2> {
            // 2
            return try req.parameters.next(User.self).convertToPublicV2()
    }

    // 1
    func getAcronymsHandler(_ req: Request)
        throws -> Future<[Acronym]> {
            // 2
            return try req
                .parameters.next(User.self)
                .flatMap(to: [Acronym].self) { user in
                    // 3
                    try user.acronyms.query(on: req).all()
            }
    }

    // 1
    func loginHandler(_ req: Request) throws -> Future<Token> {
        // 2
        let user = try req.requireAuthenticated(User.self)
        // 3
        let token = try Token.generate(for: user)
        // 4
        return token.save(on: req)
    }
}
