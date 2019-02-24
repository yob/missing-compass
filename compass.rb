require 'net/http'
require 'json'

class CompassJSON
  def self.parse(data)
    if data.is_a?(String) || data.is_a?(Integer)
      data
    elsif data.is_a?(Array)
      data.map { |item| CompassJSON.parse(item) }
    elsif data.is_a?(Hash)
      if data.size == 1 && data.key?("d") # root of a response
        data.fetch("d")
      elsif data.fetch("__type","").starts_with?("GenericMobileResponse:")
        GenericMobileResponse.new(data.fetch("data"))
      elsif data.fetch("__type","").starts_with?("NewsItem:")
        NewsItem.new(data.fetch("data"))
      else
        CompassJSON.parse(data)
      end
    else
      raise "Not sure what to do with: #{data.inspect}"
    end
  end
end

class GenericMobileResponse
  attr_reader :data

  def initialize(data)
    @data = data
  end

  def eql?(other)
    @data.hash == other.data.hash
  end
end

class NewsItem
  attr_reader :attachments, :content, :content_html, :id, :post_date, :post_date_utc
  attr_reader :priority, :title, :uploader, :user_image_url

  def initialize(data)
    @id = data.fetch("newsItemId", 0)
    @attachments = data.fetch("attachments", [])
    @content = data.fetch("content", "")
    @content_html = data.fetch("contentHtml", "")
    @post_date = data.fetch("", "postDate")
    @post_date_utc = data.fetch("postDateUtc", "")
    @priority = data.fetch("priority", false)
    @title = data.fetch("title", "")
    @uploader = data.fetch("uploader", "")
    @user_image_url = data.fetch("userImageUrl", "")
  end

  def eql?(other)
    other.is_a?(NewsItem) && @id == other.id
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
    CompassJSON.parse(JSON.parse(response.body))
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
    CompassJSON.parse(JSON.parse(response.body))
  end

  def get_news_feed
    response = post(
      path: PATH_NEWSFEED,
      headers: {"Cookie" => @cookie},
    )
    CompassJSON.parse(JSON.parse(response.body))
  end

  def get_personal_details
    response = post(
      path: PATH_GET_PERSONAL_DETAILS,
      headers: {"Cookie" => @cookie},
    )
    CompassJSON.parse(JSON.parse(response.body))
  end

  # this seems to be parent teacher interview slots
  def get_pst_cycles
    response = post(
      path: PATH_PST_CYCLES,
      headers: {"Cookie" => @cookie},
    )
    CompassJSON.parse(JSON.parse(response.body))
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
  puts client.get_news_feed.inspect
end
