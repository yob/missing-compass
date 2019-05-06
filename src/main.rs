#[macro_use]
extern crate serde_json;

use serde_derive::{Deserialize};
use clap::{App, Arg, SubCommand};


#[derive(Deserialize, Debug)]
struct User {
    login: String,
    id: u32,
}

#[derive(Deserialize, Debug)]
struct CompassClient {
    hostname: String,
    cookie: String,
}

fn build_client(hostname: String, username: String, password: String) -> Result<CompassClient, reqwest::Error> {
    let request_url = format!("https://{hostname}/services/admin.svc/AuthenticateUserCredentials",
                              hostname = hostname);

    let body = json!({
        "username": username,
        "password": password,
        "sessionstate": "readonly"
    });

    let client = reqwest::Client::new();
    let response = client.post(&request_url).header("Content-Type", "application/json").body(body.to_string()).send()?;

    //println!("status: {:?}", response.status());
    //println!("body: {:?}", response.text()?);
    //println!("cookie: {:?}", response.headers().get("set-cookie").unwrap());

    let session_cookie = response.cookies().find(|x| x.name() == String::from("ASP.NET_SessionId") ).unwrap();
    Ok(CompassClient {
        hostname: hostname,
        cookie: format!("{}={}", session_cookie.name().to_string(), session_cookie.value().to_string()),
    })
}

impl CompassClient {
    fn get_personal_details(&self) -> Result<String, reqwest::Error> {
        let request_url = format!("https://{hostname}/services/mobile.svc/GetPersonalDetails?sessionstate=readonly",
                              hostname = self.hostname);
        let client = reqwest::Client::new();
        let mut response = client.post(&request_url).header("Cookie", self.cookie.clone()).body(String::from("")).send()?;

        Ok(response.text()?)
    }
}


fn run(hostname: String, username: String, password: String) -> Result<(), reqwest::Error> {
    let client = build_client(
        hostname,
        username,
        password,
        ).unwrap();
    let details = client.get_personal_details().unwrap();
    println!("details: {:?}", details);
    Ok(())
}

fn main() {
    let matches = App::new("compass")
        .subcommand(SubCommand::with_name("email-news"))
        .arg(Arg::with_name("compass-host")
	     .short("h")
	     .long("compass-host")
	     .value_name("HOST")
	     .help("The compass hostname for your school")
	     .takes_value(true)
             .required(true))
        .arg(Arg::with_name("compass-user")
	     .short("u")
	     .long("compass-user")
	     .value_name("USERNAME")
	     .help("Your compass username")
	     .takes_value(true)
             .required(true))
        .arg(Arg::with_name("compass-pass")
	     .short("p")
	     .long("compass-pass")
	     .value_name("PASSWORD")
	     .help("Your compass password")
	     .takes_value(true)
             .required(true))
        .get_matches();

    let hostname = matches.value_of("compass-host").unwrap();
    let username = matches.value_of("compass-user").unwrap();
    let password = matches.value_of("compass-pass").unwrap();

    match matches.subcommand_name() {
        Some("email-news") => run(hostname.to_string(), username.to_string(), password.to_string()),
        _ => { println!("oops"); Ok(()) }
    }.ok();
}
