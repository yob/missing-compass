package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/ioutil"
	"net/http"
	"net/http/cookiejar"
	"net/url"
	"os"
	"strings"

	"github.com/urfave/cli/v2"
)

const (
	path_auth     = "/services/admin.svc/AuthenticateUserCredentials"
	path_newsfeed = "/services/mobile.svc/GetNewsFeed?sessionstate=readonly"
)

type compassClient struct {
	username  string
	password  string
	hostname  string
	cookieJar http.CookieJar
}

type loginCredentials struct {
	SessionState string `json:"sessionstate"`
	Username     string `json:"username"`
	Password     string `json:"password"`
}

func newCompassClient(username string, password string, hostname string) compassClient {
	jar, _ := cookiejar.New(nil)
	return compassClient{
		username:  username,
		password:  password,
		hostname:  hostname,
		cookieJar: jar,
	}
}

func (client *compassClient) login() (bool, error) {
	headers := map[string]string{"Content-Type": "application/json"}
	credentials := loginCredentials{
		SessionState: "readonly",
		Username:     client.username,
		Password:     client.password,
	}
	body, err := json.Marshal(credentials)
	if err != nil {
		fmt.Printf("login: error building body: %s\n", err)
		return false, err
	}
	_, err = client.postWithBody(path_auth, headers, string(body))

	if err != nil {
		fmt.Printf("login: error making http request: %s\n", err)
		return false, err
	}
	url, err := url.Parse(fmt.Sprintf("https://%s", client.hostname))
	if err != nil {
		fmt.Printf("login: error parsing url: %s\n", err)
		return false, err
	}
	for _, cookie := range client.cookieJar.Cookies(url) {
		if cookie.Name == "ASP.NET_SessionId" {
			return true, nil
		}
	}
	return false, nil
}

func (client *compassClient) newsfeed() (string, error) {
	headers := map[string]string{}
	res, err := client.post(path_newsfeed, headers)

	if err != nil {
		fmt.Printf("login: error making http request: %s\n", err)
		return "", err
	}
	logf("res: %+v\n", res)
	return res, nil
}

func (client *compassClient) postWithBody(path string, headers map[string]string, body string) (string, error) {
	httpClient := &http.Client{Jar: client.cookieJar}
	requestURL := fmt.Sprintf("https://%s%s", client.hostname, path)
	req, err := http.NewRequest(http.MethodPost, requestURL, strings.NewReader(body))
	if err != nil {
		fmt.Printf("client: could not create request: %s\n", err)
		return "", err
	}
	for header, value := range headers {
		req.Header.Add(header, value)
	}
	req.Header.Set("User-Agent", "Go API/v1")

	res, err := httpClient.Do(req)
	if err != nil {
		fmt.Printf("client: error making http request: %s\n", err)
		return "", err
	}

	resBody, err := ioutil.ReadAll(res.Body)
	if err != nil {
		fmt.Printf("client: could not read response body: %s\n", err)
		return "", err
	}
	return string(resBody), nil
}

func (client *compassClient) post(path string, headers map[string]string) (string, error) {
	httpClient := &http.Client{Jar: client.cookieJar}
	requestURL := fmt.Sprintf("https://%s%s", client.hostname, path)
	req, err := http.NewRequest(http.MethodPost, requestURL, nil)
	if err != nil {
		fmt.Printf("client: could not create request: %s\n", err)
		return "", err
	}
	for header, value := range headers {
		req.Header.Add(header, value)
	}
	req.Header.Set("User-Agent", "Go API/v1")

	res, err := httpClient.Do(req)
	if err != nil {
		fmt.Printf("client: error making http request: %s\n", err)
		return "", err
	}

	resBody, err := ioutil.ReadAll(res.Body)
	if err != nil {
		fmt.Printf("client: could not read response body: %s\n", err)
		return "", err
	}
	return string(resBody), nil
}

func logf(msg string, args ...interface{}) {
	_, err := fmt.Fprintf(os.Stderr, msg+"\n", args...)

	if err != nil {
		panic("failed to write to stderr: " + err.Error())
	}
}

func main() {
	app := cli.NewApp()

	app.Name = "compass-cli"
	app.Usage = "Fetch data from the compass API, printed to stdout as JSON"
	app.Version = "dev"

	app.Commands = []*cli.Command{
		{
			Name:  "news-feed",
			Usage: "return JSON news feed",
			Flags: []cli.Flag{
				&cli.StringFlag{
					Name:     "username",
					Usage:    "compass username",
					Required: true,
				},
				&cli.StringFlag{
					Name:     "password",
					Usage:    "compass password",
					Required: true,
				},
				&cli.StringFlag{
					Name:     "hostname",
					Usage:    "the compass school hostname (eg. coburg-north-ps-vic.compass.education)",
					Required: true,
				},
			},
			Action: func(ctx *cli.Context) error {
				client := newCompassClient(ctx.String("username"), ctx.String("password"), ctx.String("hostname"))
				res, _ := client.login()
				if !res {
					// second time, to bust through cloudflare
					res, _ = client.login()
				}

				if !res {
					return errors.New("Login failed")
				}
				resfeed, err := client.newsfeed()
				if err != nil {
					return err
				}
				fmt.Println(resfeed)
				return nil
			},
		},
	}

	err := app.Run(os.Args)
	if err != nil {
		logf("%+v", err)
		os.Exit(1)
	}
}
