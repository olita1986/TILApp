import Vapor
import Leaf
import Authentication
// 1
struct WebsiteController: RouteCollection {

    func boot(router: Router) throws {
        let authSessionRoutes =
            router.grouped(User.authSessionsMiddleware())
        authSessionRoutes.get(use: indexHandler)
        authSessionRoutes.get("acronyms", Acronym.parameter,
                              use: acronymHandler)
        authSessionRoutes.get("users", User.parameter, use: userHandler)
        authSessionRoutes.get("users", use: allUsersHandler)
        authSessionRoutes.get("categories", use: allCategoriesHandler)
        authSessionRoutes.get("categories", Category.parameter,
                              use: categoryHandler)
        authSessionRoutes.get("login", use: loginHandler)
        authSessionRoutes.post(LoginPostData.self, at: "login",
                               use: loginPostHandler)
        authSessionRoutes.post("logout", use: logoutHandler)
        // 1
        authSessionRoutes.get("register", use: registerHandler)
        // 2
        authSessionRoutes.post(RegisterData.self, at: "register",
                               use: registerPostHandler)
        let protectedRoutes = authSessionRoutes
            .grouped(RedirectMiddleware<User>(path: "/login"))
        protectedRoutes.get("acronyms", "create",
                            use: createAcronymHandler)
        protectedRoutes.post(Acronym.self, at: "acronyms",
                             "create", use: createAcronymPostHandler)
        protectedRoutes.get("acronyms", Acronym.parameter, "edit",
                            use: editAcronymHandler)
        protectedRoutes.post("acronyms", Acronym.parameter, "edit",
                             use: editAcronymPostHandler)
        protectedRoutes.post("acronyms", Acronym.parameter, "delete",
                             use: deleteAcronymHandler)
    }

    func indexHandler(_ req: Request) throws -> Future<View> {
        // 1
        return Acronym.query(on: req)
            .all()
            .flatMap(to: View.self) { acronyms in
                let userLoggedIn = try req.isAuthenticated(User.self)
                let showCookieMessage =
                    req.http.cookies["cookies-accepted"] == nil
                let context = IndexContext(
                    title: "Home page",
                    acronyms: acronyms,
                    userLoggedIn: userLoggedIn,
                    showCookieMessage: showCookieMessage)
                return try req.view().render("index", context)
            }
    }

    // 1
    func acronymHandler(_ req: Request) throws -> Future<View> {
        // 2
        return try req.parameters.next(Acronym.self)
            .flatMap(to: View.self) { acronym in
                // 3
                return acronym.user
                    .get(on: req)
                    .flatMap(to: View.self) { user in
                        // 4
                        let context = AcronymContext(
                            title: acronym.short,
                            acronym: acronym,
                            user: user)
                        return try req.view().render("acronym", context)
                }
        }
    }

    // 1
    func userHandler(_ req: Request) throws -> Future<View> {
        // 2
        return try req.parameters.next(User.self)
            .flatMap(to: View.self) { user in
                // 3
                return try user.acronyms
                    .query(on: req)
                    .all()
                    .flatMap(to: View.self) { acronyms in
                        // 4
                        let context = UserContext(
                            title: user.name,
                            user: user,
                            acronyms: acronyms)
                        return try req.view().render("user", context)
                }
        }
    }

    // 1
    func allUsersHandler(_ req: Request) throws -> Future<View> {
        // 2
        return User.query(on: req)
            .all()
            .flatMap(to: View.self) { users in
                // 3
                let context = AllUsersContext(
                    title: "All Users",
                    users: users)
                return try req.view().render("allUsers", context)
        }
    }

    func allCategoriesHandler(_ req: Request) throws
        -> Future<View> {
            // 1
            let categories = Category.query(on: req).all()
            let context = AllCategoriesContext(categories: categories)
            // 2
            return try req.view().render("allCategories", context)
    }

    func categoryHandler(_ req: Request) throws -> Future<View> {
        // 1
        return try req.parameters.next(Category.self)
            .flatMap(to: View.self) { category in
                // 2
                let acronyms = try category.acronyms.query(on: req).all()
                // 3
                let context = CategoryContext(
                    title: category.name,
                    category: category,
                    acronyms: acronyms)
                // 4
                return try req.view().render("category", context)
        }
    }

    func createAcronymHandler(_ req: Request) throws
        -> Future<View> {
            // 1
            let context = CreateAcronymContext(
                users: User.query(on: req).all())
            // 2
            return try req.view().render("createAcronym", context)
    }

    // 1
    func createAcronymPostHandler(
        _ req: Request,
        acronym: Acronym
        ) throws -> Future<Response> {
        // 2
        return acronym.save(on: req)
            .map(to: Response.self) { acronym in
                // 3
                guard let id = acronym.id else {
                    throw Abort(.internalServerError)
                }
                // 4
                return req.redirect(to: "/acronyms/\(id)")
        }
    }

    func editAcronymHandler(_ req: Request) throws -> Future<View> {
        // 1
        return try req.parameters.next(Acronym.self)
            .flatMap(to: View.self) { acronym in
                // 2
                let context = EditAcronymContext(
                    acronym: acronym,
                    users: User.query(on: req).all())
                // 3
                return try req.view().render("createAcronym", context)
        }
    }

    func editAcronymPostHandler(_ req: Request) throws
        -> Future<Response> {
            // 1
            return try flatMap(
                to: Response.self,
                req.parameters.next(Acronym.self),
                req.content.decode(Acronym.self)
            ) { acronym, data in
                // 2
                acronym.short = data.short
                acronym.long = data.long
                acronym.userID = data.userID
                // 3
                guard let id = acronym.id else {
                    throw Abort(.internalServerError)
                }
                let redirect = req.redirect(to: "/acronyms/\(id)")
                // 4
                return acronym.save(on: req).transform(to: redirect)
            }
    }

    func deleteAcronymHandler(_ req: Request) throws
        -> Future<Response> {
            return try req.parameters.next(Acronym.self).delete(on: req)
                .transform(to: req.redirect(to: "/"))
    }

    // 1
    func loginHandler(_ req: Request) throws -> Future<View> {
        let context: LoginContext
        // 2
        if req.query[Bool.self, at: "error"] != nil {
            context = LoginContext(loginError: true)
        } else {
            context = LoginContext()
        }
        // 3
        return try req.view().render("login", context)
    }

    // 1
    func loginPostHandler(
        _ req: Request,
        userData: LoginPostData
        ) throws -> Future<Response> {
        // 2
        return User.authenticate(
            username: userData.username,
            password: userData.password,
            using: BCryptDigest(),
            on: req).map(to: Response.self) { user in
                // 3
                guard let user = user else {
                    return req.redirect(to: "/login?error")
                }
                // 4
                try req.authenticateSession(user)
                // 5
                return req.redirect(to: "/")
        }

    }

    // 1
    func logoutHandler(_ req: Request) throws -> Response {
        // 2
        try req.unauthenticateSession(User.self)
        // 3
        return req.redirect(to: "/")
    }

    func registerHandler(_ req: Request) throws -> Future<View> {
        let context: RegisterContext
        if let message = req.query[String.self, at: "message"] {
            context = RegisterContext(message: message)
        } else {
            context = RegisterContext()
        }
        return try req.view().render("register", context)
    }

    // 1
    func registerPostHandler(
        _ req: Request,
        data: RegisterData
        ) throws -> Future<Response> {
        do {
            try data.validate()
        } catch (let error) {
            let redirect: String
            if let error = error as? ValidationError,
                let message = error.reason.addingPercentEncoding(
                    withAllowedCharacters: .urlQueryAllowed) {
                redirect = "/register?message=\(message)"
            } else {
                redirect = "/register?message=Unknown+error"
            }
            return req.future(req.redirect(to: redirect))
        }
        var twitterURL: String?
        if let twitter = data.twitterURL,
            !twitter.isEmpty {
            twitterURL = twitter
        }
        let password = try BCrypt.hash(data.password)
        // 3
        let user = User(
            name: data.name,
            username: data.username,
            password: password,
            email: data.emailAddress,
            twitterURL: twitterURL)
        // 4
        return user.save(on: req).map(to: Response.self) { user in
            // 5
            try req.authenticateSession(user)
            // 6
            return req.redirect(to: "/")
        }
    }
}

struct IndexContext: Encodable {
    let title: String
    let acronyms: [Acronym]
    let userLoggedIn: Bool
    let showCookieMessage: Bool
}

struct AcronymContext: Encodable {
    let title: String
    let acronym: Acronym
    let user: User
}

struct UserContext: Encodable {
    let title: String
    let user: User
    let acronyms: [Acronym]
}

struct AllUsersContext: Encodable {
    let title: String
    let users: [User]
}

struct AllCategoriesContext: Encodable {
    // 1
    let title = "All Categories"
    // 2
    let categories: Future<[Category]>
}

struct CategoryContext: Encodable {
    // 1
    let title: String
    // 2
    let category: Category
    // 3
    let acronyms: Future<[Acronym]>
}

struct CreateAcronymContext: Encodable {
    let title = "Create An Acronym"
    let users: Future<[User]>
}

struct EditAcronymContext: Encodable {
    let title = "Edit Acronym"
    let acronym: Acronym
    let users: Future<[User]>
    let editing = true
}

struct LoginContext: Encodable {
    let title = "Log In"
    let loginError: Bool
    init(loginError: Bool = false) {
        self.loginError = loginError
    }
}

struct LoginPostData: Content {
    let username: String
    let password: String
}

struct RegisterContext: Encodable {
    let title = "Register"
    let message: String?
    init(message: String? = nil) {
        self.message = message
    }
}

struct RegisterData: Content {
    let name: String
    let username: String
    let password: String
    let confirmPassword: String
    let emailAddress: String
    let twitterURL: String?
}

// 1
extension RegisterData: Validatable, Reflectable {
    // 2
    static func validations() throws
        -> Validations<RegisterData> {
            // 3
            var validations = Validations(RegisterData.self)
            // 4
            try validations.add(\.name, .ascii)
            // 5
            try validations.add(\.username,
                                // 6
                .alphanumeric && .count(3...))
            try validations.add(\.password, .count(8...))
            try validations.add(\.emailAddress, .email)

            validations.add("passwords match") { model in
                // 2
                guard model.password == model.confirmPassword else {
                    // 3
                    throw BasicValidationError("passwords don’t match")
                }
            }
            return validations
    }
}
