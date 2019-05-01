use serde_derive::Deserialize;
use clap::{App, SubCommand};


#[derive(Deserialize, Debug)]
struct User {
    login: String,
    id: u32,
}


fn run() -> Result<(), reqwest::Error> {
    let request_url = format!("https://api.github.com/repos/{owner}/{repo}/stargazers",
                              owner = "yob",
                              repo = "pdf-reader");
    println!("url: {}", request_url);

    let client = reqwest::Client::new();
    let mut response = client.get(&request_url).send()?;


    println!("server: {:?}", response.headers().get("server").unwrap());
    let users: Vec<User> = response.json()?;
    println!("users: {:?}", users);
    Ok(())
}

fn main() {
    let matches = App::new("compass")
        .subcommand(SubCommand::with_name("email-news"))
        .get_matches();

    match matches.subcommand_name() {
        Some("email-news") => run(),
        _ => { println!("oops"); Ok(()) }
    }.ok();
}
