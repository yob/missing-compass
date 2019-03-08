require 'net/http'
require 'json'
require 'time'
require 'base64'

class NewsItemAttachment

  attr_reader :data

  def initialize(data)
    @data = data
  end

  def id
    @data.fetch("assetId", 0)
  end

  def is_image
    @data.fetch("isImage", false)
  end

  def name
    @data.fetch("name", "")
  end

  def original_file_name
    @data.fetch("originalFileName", "")
  end

  def source_organisation_id
    @data.fetch("sourceOrganisationId", nil)
  end

  def url
    @data.fetch("url", nil)
  end

  def bytes
    if @data.key?("bytes_base64")
      Base64.decode64(@data.fetch("bytes_base64"))
    end
  end

  def add_bytes(bytes)
    @data["bytes_base64"] = Base64.encode64(bytes.to_s)
  end
end

class NewsItemAttachmentRepository
  def initialize(dir)
    raise ArgumentError, "#{dir} is not a directory" unless File.directory?(dir)
    @dir = File.expand_path(dir)
  end

  def exists?(attachment)
    File.file?(build_path(attachment))
  end

  def save(attachment)
    return true if exists?(attachment)

    File.open(build_path(attachment), "wb") do |io|
      io.write(JSON.pretty_generate(attachment.data))
    end
  end

  private

  def build_path(attachment)
    File.join(@dir, "attachment-#{attachment.id}.json")
  end

end

class NewsItem

  attr_reader :data

  def initialize(data)
    @data = data
  end

  def id
    @data.fetch("newsItemId", 0)
  end

  def attachments
    @data.fetch("attachments", []).map { |item|
      NewsItemAttachment.new(item)
    }
  end

  def content
    @data.fetch("content", "")
  end

  def content_html
    @data.fetch("contentHtml", "")
  end

  def post_date
    parse_time(@data.fetch("postDateUtc", ""))
  end

  def priority
    @data.fetch("priority", false)
  end

  def title
    @data.fetch("title", "")
  end

  def uploader
    @data.fetch("uploader", "")
  end

  def user_image_url
    @data.fetch("userImageUrl", "")
  end

  def eql?(other)
    other.is_a?(NewsItem) && @id == other.id
  end

  private

  def parse_time(str)
    Time.iso8601(str)
  end
end

class NewsItemRepository
  def initialize(dir)
    raise ArgumentError, "#{dir} is not a directory" unless File.directory?(dir)
    @dir = File.expand_path(dir)
  end

  def exists?(news_item)
    File.file?(build_path(news_item))
  end

  def save(news_item)
    if !exists?(news_item)
      File.open(build_path(news_item), "wb") do |io|
        io.write(JSON.pretty_generate(news_item.data))
      end
    else
      false
    end
  end

  def find(id)
    path = File.join(@dir, "news-item-#{id}.json")
    if File.file?(path)
      NewsItem.new(JSON.parse(File.read(path)))
    end
  end

  def all
    Dir.glob("#{@dir}/news-item-*.json").map do |path|
      NewsItem.new(JSON.parse(File.read(path)))
    end
  end

  private

  def build_path(news_item)
    File.join(@dir, "news-item-#{news_item.id}.json")
  end
end

class Message

  attr_reader :data

  def initialize(data)
    @data = data
  end

  def id
    @data.fetch("id", 0)
  end

  def archived
    @data.fetch("archived", false)
  end

  def content_html
    @data.fetch("contentHtml", "")
  end

  def eql?(other)
    other.is_a?(Message) && @id == other.id
  end

  def date
    parse_time(@data.fetch("date", ""))
  end

  def news_item_id
    @data.fetch("parameters", {}).fetch("newsItemId", nil)
  end

  def sender_name
    @data.fetch("sender", {}).fetch("reportName","")
  end

  def sender_id
    @data.fetch("sender", {}).fetch("userId","")
  end

  private

  def parse_time(str)
    Time.iso8601(str)
  end
end

class MessageRepository
  def initialize(dir)
    raise ArgumentError, "#{dir} is not a directory" unless File.directory?(dir)
    @dir = File.expand_path(dir)
  end

  def exists?(msg)
    File.file?(build_path(msg))
  end

  def save(msg)
    if !exists?(msg)
      File.open(build_path(msg), "wb") do |io|
        io.write(JSON.pretty_generate(msg.data))
      end
    else
      false
    end
  end

  def find(id)
    path = File.join(@dir, "message-#{id}.json")
    if File.file?(path)
      Message.new(JSON.parse(File.read(path)))
    end
  end

  private

  def build_path(msg)
    File.join(@dir, "message-#{msg.id}.json")
  end
end

class CompassEmail
  attr_reader :to, :from, :subject, :body, :attachments

  def initialize(to:, from:, subject:, body:, attachments: [])
    @to, @from, @subject, @body, @attachments = to, from, subject, body, attachments
  end

  def self.from_message(to, from, message, news_item, attachments)
    new(
      to: to,
      from: from,
      subject: message.content_html,
      body: news_item.content,
      attachments: attachments
    )
  end

  def self.from_news_item(to, from, news_item, attachments)
    new(
      to: to,
      from: from,
      subject: news_item.title,
      body: news_item.content,
      attachments: attachments
    )
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
    response.body
  end

  def get_messages
    response = post(
      path: PATH_GET_MESSAGES,
      headers: {"Cookie" => @cookie},
    )
    data = JSON.parse(response.body)
    data.fetch("d",{}).fetch("data", []).map { |item|
      Message.new(item)
    }.sort_by(&:date)
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
      raise "POST #{path} failed (#{response.code}) (#{response.body})"
    end
  end
end

if __FILE__ == $0
  hostname, username, password = *ARGV
  if hostname.nil? || username.nil? || password.nil?
    $stderr.puts "USAGE: ruby compass.rb <school hostname> <username> <password>"
    exit(1)
  end
  dbpath = File.join(File.expand_path(File.dirname(__FILE__)), "db")
  news_item_repo = NewsItemRepository.new(dbpath)
  message_repo = MessageRepository.new(dbpath)
  attachment_repo = NewsItemAttachmentRepository.new(dbpath)
  client = CompassClient.new(hostname, username, password)
  new_messages = []
  new_news_items = []

  client.get_messages.each do |msg|
    unless message_repo.exists?(msg)
      message_repo.save(msg)
      new_messages << message_repo.find(msg.id)
    end
  end
  client.get_news_feed.each do |item|
    unless news_item_repo.exists?(item)
      news_item_repo.save(item)
      item.attachments.each do |attachment|
        attachment.add_bytes(
          client.download_file(file_id: attachment.id)
        )
        attachment_repo.save(attachment)
      end
      new_news_items << news_item_repo.find(item.id)
    end
  end

  new_messages.each do |msg|
    related_news_item = news_item_repo.find(msg.news_item_id)
    email = CompassEmail.from_message(["james@yob.id.au"], "james@rainbowbooks.com.au", msg, related_news_item, related_news_item.attachments)
    puts "New Message | #{email.to} | #{email.from} | #{email.subject} | #{email.body} | #{email.attachments.size} attachments"
  end

  new_news_items.each do |item|
    email = CompassEmail.from_news_item(["james@yob.id.au"], "james@rainbowbooks.com.au", item, item.attachments)
    puts "New news Item | #{email.to} | #{email.from} | #{email.subject} | #{email.body} | #{email.attachments.size} attachments"
  end
end
