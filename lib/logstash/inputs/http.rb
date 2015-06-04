# encoding: utf-8
require "logstash/inputs/base"
require "logstash/namespace"
require "stud/interval"
require "socket"
require "net/http"
require "uri"
require "digest/md5"
class LogStash::Inputs::Http < LogStash::Inputs::Base
  class Interrupted < StandardError; end
  config_name "http"
  default :codec, "plain"
  # The url to listen on.
  config :url, :validate => :string, :required => true
  # refresh interval
  config :interval, :validate => :number, :default => 5
  def initialize(*args)
    super(*args)
  end # def initialize

  public
  def register
     @host = Socket.gethostname
	 @logger.info("HTTP PLUGIN LOADED")
  end # def register
  def run(queue)
   #get current log size for using as start position
   uri = URI(@url)
   http = Net::HTTP.start(uri.host, uri.port) 
   response = http.request_head(@url)	
   $file_size = (response['Content-Length']).to_i   
   #get 1024 hash current file
   http = Net::HTTP.new(uri.host, uri.port)
	headers = { 
     'Range' => "bytes=0-1024"
    }
   response_hash = http.get(uri.path, headers)
   current_hash = Digest::MD5.hexdigest(response_hash.body)  
   ###begin tail cycle###
   Stud.interval(@interval) do   
   #get temp 1024 hash   
    http = Net::HTTP.new(uri.host, uri.port)
	headers = { 
     'Range' => "bytes=0-1024"
    }
    response_hash = http.get(uri.path, headers)		
    temp_hash = Digest::MD5.hexdigest(response_hash.body)
	if current_hash == temp_hash
     #same file    
	 #@logger.error("++SAME FILE++")	 
     http = Net::HTTP.new(uri.host, uri.port)
	 headers = { 
      'Range' => "bytes=#{$file_size}-"
     }		
	 response = http.get(uri.path, headers)
	 if (200..226) === (response.code).to_i
	 #@logger.error("++SAME FILE 200++")	 
	  $file_size += (response['Content-Length']).to_i			
	  (response.body).slice!"\r\n"
	  messages = response.body	 
	  #@logger.error("++MESSAGE++", :messages => messages)	  
	  messages.each_line do |message| 
	   message.slice!"\r"
	   message.slice!"\n"
	   event = LogStash::Event.new("message" => message, "host" => @host)
       decorate(event)
       queue << event
	  end # end do
	 else
	  #@logger.error("++SAME FILE NOT 200++")
	 end #end if code 
     else
	   #new file	   		   
	   $file_size = 0
       #uri = URI(@url)
       http = Net::HTTP.start(uri.host, uri.port) 
       response = http.get(uri.path)
	   if (200..226) === (response.code).to_i	
		#@logger.error("++NEW FILE 200++")	   
        $file_size = (response['Content-Length']).to_i
		(response.body).slice!"\r\n"
		messages = response.body	 
		#@logger.error("++MESSAGE++", :messages => messages)	  
		messages.each_line do |message| 
		 message.slice!"\r"
		 message.slice!"\n"
		 event = LogStash::Event.new("message" => message, "host" => @host)
		 decorate(event)
		 queue << event
		end # end do
        #get 1024 hash
        http = Net::HTTP.new(uri.host, uri.port)
	    headers = { 
         'Range' => "bytes=0-1024"
        }
        response = http.get(uri.path, headers)
        current_hash = Digest::MD5.hexdigest(response.body)
	  else
	   #@logger.error("++NEW FILE NOT 200++")
	  end #end if code
	 end #end if hash  
    end # loop  
  end #end run
 end #class
