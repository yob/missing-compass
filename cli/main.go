package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/ioutil"
	"net/http"
	"net/http/cookiejar"
	"net/url"
	"os"
	"strings"

	"github.com/urfave/cli/v2"
)

const (
	path_auth                  = "/services/admin.svc/AuthenticateUserCredentials"
	path_get_events_for_parent = "/Services/Events.svc/GetForParent"
	path_get_messages          = "/services/mobile.svc/GetMessages?sessionstate=readonly"
	path_get_personal_details  = "/services/mobile.svc/GetPersonalDetails?sessionstate=readonly"
	path_newsfeed              = "/services/mobile.svc/GetNewsFeed?sessionstate=readonly"
	path_download_file         = "/services/FileDownload/FileRequestHandler"
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

type getEventsForParentParams struct {
	UserId string `json:"userId"`
	Limit  int64  `json:"limit"`
	Page   int64  `json:"page"`
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

func (client *compassClient) get_events_for_parent(user_id string) (string, error) {
	headers := map[string]string{"Content-Type": "application/json"}
	params := getEventsForParentParams{
		UserId: user_id,
		Limit:  20,
		Page:   1,
	}
	body, err := json.Marshal(params)
	if err != nil {
		fmt.Printf("login: error building body: %s\n", err)
		return "", err
	}
	res, err := client.postWithBody(path_get_events_for_parent, headers, string(body))

	if err != nil {
		fmt.Printf("login: error making http request: %s\n", err)
		return "", err
	}
	return res, nil
}

func (client *compassClient) get_messages() (string, error) {
	headers := map[string]string{}
	res, err := client.post(path_get_messages, headers)

	if err != nil {
		fmt.Printf("login: error making http request: %s\n", err)
		return "", err
	}
	return res, nil
}

func (client *compassClient) get_personal_details() (string, error) {
	headers := map[string]string{}
	res, err := client.post(path_get_personal_details, headers)

	if err != nil {
		fmt.Printf("login: error making http request: %s\n", err)
		return "", err
	}
	return res, nil
}

func (client *compassClient) newsfeed() (string, error) {
	headers := map[string]string{}
	res, err := client.post(path_newsfeed, headers)

	if err != nil {
		fmt.Printf("login: error making http request: %s\n", err)
		return "", err
	}
	return res, nil
}

func (client *compassClient) download_file(fileId string) ([]byte, error) {
	path := fmt.Sprintf("%s?FileDownloadType=1&file=%s", path_download_file, fileId)
	res, err := client.get(path)

	if err != nil {
		fmt.Printf("login: error making http request: %s\n", err)
		return []byte{}, err
	}
	return res, nil
}

func (client *compassClient) get(path string) ([]byte, error) {
	httpClient := &http.Client{Jar: client.cookieJar}
	requestURL := fmt.Sprintf("https://%s%s", client.hostname, path)
	req, err := http.NewRequest(http.MethodGet, requestURL, nil)
	if err != nil {
		fmt.Printf("client: could not create request: %s\n", err)
		return []byte{}, err
	}
	req.Header.Set("User-Agent", "Go API/v1")

	res, err := httpClient.Do(req)
	if err != nil {
		fmt.Printf("client: error making http request: %s\n", err)
		return []byte{}, err
	}

	resBody, err := ioutil.ReadAll(res.Body)
	if err != nil {
		fmt.Printf("client: could not read response body: %s\n", err)
		return []byte{}, err
	}
	return resBody, nil
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
		{
			Name:  "get-messages",
			Usage: "return JSON messages",
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
				resfeed, err := client.get_messages()
				if err != nil {
					return err
				}
				fmt.Println(resfeed)
				return nil
			},
		},
		{
			Name:  "get-personal-details",
			Usage: "return JSON data on thecurrent user",
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
				resfeed, err := client.get_personal_details()
				if err != nil {
					return err
				}
				fmt.Println(resfeed)
				return nil
			},
		},
		{
			Name:  "get-events-for-parent",
			Usage: "JSON data with events that a parent can see",
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
				&cli.StringFlag{
					Name:     "user-id",
					Usage:    "the id of a user",
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
				data, err := client.get_events_for_parent(ctx.String("user-id"))
				if err != nil {
					return err
				}
				fmt.Println(data)
				return nil
			},
		},
		{
			Name:  "download-file",
			Usage: "downloads a single file",
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
				&cli.StringFlag{
					Name:     "file-id",
					Usage:    "the id of a file",
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
				data, err := client.download_file(ctx.String("file-id"))
				if err != nil {
					return err
				}
				io.Copy(os.Stdout, bytes.NewReader(data))
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
