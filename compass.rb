require 'net/http'
require 'json'
require 'time'

class NewsItemAttachment

  attr_reader :id, :is_image, :name, :originalFileName, :sourceOrganisationId, :url

  def initialize(data)
    @id = data.fetch("assetId", 0)
    @is_image = data.fetch("isImage", false)
    @name = data.fetch("name", "")
    @originalFileName = data.fetch("originalFileName", "")
    @sourceOrganisationId = data.fetch("sourceOrganisationId", nil)
    @url = data.fetch("url", nil)
  end
end

class NewsItem
  attr_reader :attachments, :content, :content_html, :id, :post_date
  attr_reader :priority, :title, :uploader, :user_image_url

  def initialize(data)
    @id = data.fetch("newsItemId", 0)
    @attachments = data.fetch("attachments", []).map { |item|
      NewsItemAttachment.new(item)
    }
    @content = data.fetch("content", "")
    @content_html = data.fetch("contentHtml", "")
    @post_date = parse_time(data.fetch("postDateUtc", ""))
    @priority = data.fetch("priority", false)
    @title = data.fetch("title", "")
    @uploader = data.fetch("uploader", "")
    @user_image_url = data.fetch("userImageUrl", "")
  end

  def eql?(other)
    other.is_a?(NewsItem) && @id == other.id
  end

  private

  def parse_time(str)
    Time.iso8601(str)
  end
end

class CompassClient
  USER_AGENT = "iOS/12_1_2 type/iPhone CompassEducation/4.5.3"
  PATH_AUTH = "/services/admin.svc/AuthenticateUserCredentials"
  PATH_NEWSFEED = "/services/mobile.svc/GetNewsFeed?sessionstate=readonly"
  PATH_GET_MESSAGES = "/services/mobile.svc/GetMessages?sessionstate=readonly"
  PATH_PST_CYCLES = "/services/mobile.svc/GetPstCycles?sessionstate=readonly"
  PATH_CHECK_PARENT_DETAILS = "/services/mobile.svc/CheckParentDetails?sessionstate=readonly"
  PATH_GET_PERSONAL_DETAILS = "/services/mobile.svc/GetPersonalDetails?sessionstate=readonly"
  PATH_DOWNLOAD_FILE = "/services/FileDownload/FileRequestHandler"

  def initialize(hostname, username, password)
    @hostname = hostname
    @cookie = generate_cookie(username, password)
  end

  def check_parent_details
    response = post(
      path: PATH_CHECK_PARENT_DETAILS,
      headers: {"Cookie" => @cookie},
    )
    JSON.parse(response.body)
  end

  def download_file(file_id: )
    response = get(
      path: "#{PATH_DOWNLOAD_FILE}?FileDownloadType=1&file=#{file_id}",
      headers: {"Cookie" => @cookie},
    )
    puts response.body
  end

  def get_messages
    response = post(
      path: PATH_GET_MESSAGES,
      headers: {"Cookie" => @cookie},
    )
    data = JSON.parse(response.body)
    data.fetch("d")
  end

  def get_news_feed
    response = post(
      path: PATH_NEWSFEED,
      headers: {"Cookie" => @cookie},
    )
    data = JSON.parse(response.body)
    data.fetch("d",{}).fetch("data", []).map { |item|
      NewsItem.new(item)
    }.sort_by(&:post_date)
  end

  def get_personal_details
    response = post(
      path: PATH_GET_PERSONAL_DETAILS,
      headers: {"Cookie" => @cookie},
    )
    JSON.parse(response.body)
  end

  # this seems to be parent teacher interview slots
  def get_pst_cycles
    response = post(
      path: PATH_PST_CYCLES,
      headers: {"Cookie" => @cookie},
    )
    JSON.parse(response.body)
  end

  private

  def generate_cookie(username, password)
    response = post(
      path: PATH_AUTH,
      headers: {"Content-Type" => "application/json"},
      body: JSON.dump({username: username, password: password, sessionstate: "readonly"})
    )
    session_id = response["Set-Cookie"][/ASP.NET_SessionId=[a-f0-9\-]+/]
    raise "login failed" if session_id.nil?
    session_id
  end

  def get(path:, headers: {})
    headers["User-Agent"] = USER_AGENT

    request = Net::HTTP::Get.new(path, headers)

    response = Net::HTTP.start(@hostname, 443, use_ssl: true) do |http|
      http.request(request)
    end

    if response.code.to_i == 200
      response
    else
      raise "GET #{path} failed (#{response.code})"
    end
  end

  def post(path:, headers: {}, body: nil )
    headers["User-Agent"] = USER_AGENT

    request = Net::HTTP::Post.new(path, headers)
    request.body = body if body

    response = Net::HTTP.start(@hostname, 443, use_ssl: true) do |http|
      http.request(request)
    end

    if response.code.to_i == 200
      response
    else
      raise "POST #{path} failed (#{response.code})"
    end
  end
end

if __FILE__ == $0
  hostname, username, password = *ARGV
  if hostname.nil? || username.nil? || password.nil?
    $stderr.puts "USAGE: ruby compass.rb <school hostname> <username> <password>"
    exit(1)
  end
  client = CompassClient.new(hostname, username, password)
  client.get_news_feed.each do |item|
    puts "#{item.post_date} #{item.title}"
  end
end
