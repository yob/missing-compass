# missing compass

Poll compass for messages and events, and email plain text versions to myself.

https://www.compass.education/ is a school admin system, used by many schools
in Australia to manage communication with parents. It has a parent app and
parent options for receiving notices (about excursions, etc) are:

* push notifications to the app
* emails with a subject, but you have to click a link to read the message on their website

These don't really work for me. The messages get removed from the compass
website and app and often can't be found when needed. I also use my inbox for
triaging, so I'd prefer to get the full message there where I can read it
without the app.

## Setup

The original script was in ruby, but I've started porting to golang for better
portability. The current state is we kickoff the script in ruby, but it shells
out to the golang binary for compass API calls.

Start by building the binary:

```
$ cd cli
$ go build -o ../compass-cli .
```

## Usage

There are two commands. Each fetches different data, and emails anything new to
the requested recipient.

Emailing new events (excursions, etc):
```
./auto/with-ruby ./compass --compass-host <hostname> --compass-user <user> --compass-pass <pass> --gmail-user <user> --gmail-pass <pass> --to <email1> --to <email2> email-new-events
```

Emailing new messages and news:
```
./auto/with-ruby ./compass --compass-host <hostname> --compass-user <user> --compass-pass <pass> --gmail-user <user> --gmail-pass <pass> --to <email1> --to <email2> email-news
```
