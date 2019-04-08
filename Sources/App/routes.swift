import Vapor
import Fluent

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    //  this register the routes for a specific model
    let acronymsController = AcronymsController()
    try router.register(collection: acronymsController)
    let usersController = UsersController()
    try router.register(collection: usersController)
    let categoriesController = CategoriesController()
    try router.register(collection: categoriesController)
    let websiteController = WebsiteController()
    try router.register(collection: websiteController)
}
