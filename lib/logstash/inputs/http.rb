# encoding: utf-8
require "logstash/inputs/base"
require "logstash/namespace"
require "stud/interval"
require "socket"
require "net/http"
require "uri"
require "pathname"
class LogStash::Inputs::HttpFile < LogStash::Inputs::Base
  class Interrupted < StandardError; end
  config_name "http_file"
  default :codec, "plain"

  # The url to listen on.
  config :url, :validate => :string, :required => true
  # refresh interval
  config :interval, :validate => :number, :default => 5
  #start position 
  config :start_position, :validate => [ "beginning", "end"], :default => "end"

  def initialize(*args)
    super(*args)
  end # def initialize

  public
  def register
    @host = Socket.gethostname
    @logger.info("HTTP PLUGIN LOADED")
  end

  def run(queue)
    uri = URI(@url.gsub(/\/?([^?\/]*)$/,"/"))
    pattern = (@url.match(/\/?([^?\/]*)$/)[1]).gsub(/(\*(?!$))/,'.*?').gsub(/\*$/,'.*')
    http = Net::HTTP.new(uri.host, uri.port)        
    response = http.get(uri.path)
    files = (response.body).scan(/<A HREF="\/([a-zA-Z0-9\._\-\s]*(?!\/))">/).flatten
    file_position = {}
    files.each do |file|
      if file.match(/#{pattern}$/) 
        if @start_position == "beginning"
          file_position[file] = 0
        else
          uri = URI(@url.gsub(/\/?([^?\/]*)$/,'') << '/' << file)	
          begin
            http = Net::HTTP.start(uri.host, uri.port)
            response = http.request_head(uri.path)             
            file_position[file] = (response['Content-Length']).to_i
          rescue Errno::ECONNREFUSED
            @logger.error("Error: Connection refused")
            sleep @interval
            retry
          end #end exception
        end #end if position
      end #end if match
    end#end each
    Stud.interval(@interval) do
      file_position.each do | file, position |
        begin
          uri = URI(@url.gsub(/\/?([^?\/]*)$/,'') << '/' << file)
          http = Net::HTTP.start(uri.host, uri.port)
          response = http.request_head(uri.path)
          new_position = (response['Content-Length']).to_i
          next if new_position == position # file not modified
          file_position[file] = 0 if new_position < position # file truncated => log rotation
          http = Net::HTTP.new(uri.host, uri.port)
          headers = { 'Range' => "bytes=#{position}-" }
          response = http.get(uri.path, headers)
          if (200..226) === (response.code).to_i
            position += (response['Content-Length']).to_i
            file_position[file] = position
            messages = (response.body).lstrip
            messages.each_line do | message |
            message = message.chomp
              if message != ''
                event = LogStash::Event.new("message" => message, "host" => @host)
                decorate(event)
                queue << event
              end #end if empty message
            end # end do
          end #end if code
        rescue Errno::ECONNREFUSED
          @logger.error("Error: Connection refused")
          next
        end #end exception               
      end#end each
    end#end loop
  end #end run
end #class
