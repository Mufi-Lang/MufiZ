use rocket::{launch, routes, get, Rocket, Build};
use rocket_dyn_templates::{Template, context};


#[get("/")]
async fn index() -> Template {
    let context: std::collections::HashMap<&str, &str> = std::collections::HashMap::new();
    Template::render("index", &context)
}

#[launch]
async fn rocket() -> Rocket<Build> {
    rocket::build()
    .attach(Template::fairing())
    .mount("/", routes![index])
}
