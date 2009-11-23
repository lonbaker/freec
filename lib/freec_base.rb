require 'gserver'
require 'rubygems'
require 'uri'
require 'crack'

require 'tools'
require "freeswitch_applications"
require "call_variables"

class Freec
  include FreeswitchApplications
  include CallVariables

  attr_reader :call_vars, :event_body, :log

  def initialize(io, log) #:nodoc:
    @call_vars ||= {}
    @last_app_executed = 'initial_step'
    @io = io    
    @log = log
  end

  def handle_call #:nodoc:
    call_initialization    
    loop do
      subscribe_to_new_channel_events
      if last_event_dtmf? && respond_to?(:on_dtmf)
        callback(:on_dtmf, call_vars[:dtmf_digit])
      elsif waiting_for_this_response? 
        reset_wait_for if waiting_for_this_response?
      elsif execute_completed?
        reload_application_code
        break if disconnect_notice? || !callback(:step)
      end      
      read_response
      parse_response
    end
    callback(:on_hangup)
    hangup unless @io.closed?
    send_and_read('exit') unless @io.closed?
  end

  def wait_for(key, value)
    @waiting_for_key = key && key.to_sym
    @waiting_for_value = value
  end

  def reset_wait_for
    wait_for(nil, nil)
    true 
  end  

  def execute_completed?
    channel_execute_complete? || channel_destroyed_after_bridge? || disconnect_notice?
  end

  private

  def call_initialization
    connect_to_freeswitch
    subscribe_to_events
  end

  def channel_execute_complete?
    return true if @last_app_executed == 'initial_step'
    complete =  call_vars[:content_type] == 'text/event-plain' && 
    call_vars[:event_name] == 'CHANNEL_EXECUTE_COMPLETE' &&
    @last_app_executed == call_vars[:application]
    @last_app_executed = nil if complete
    complete
  end

  def channel_destroyed_after_bridge?
    call_vars[:application] == 'bridge' && call_vars[:event_name] == 'CHANNEL_DESTROY'
  end

  def disconnect_notice?
    call_vars[:content_type] == 'text/disconnect-notice'
  end

  def callback(callback_name, *args)
    send(callback_name, *args) if respond_to?(callback_name)
  rescue StandardError => e
    log.error e.message
    e.backtrace.each {|trace_line| log.error(trace_line)}    
  end

  def reload_application_code
    return unless ENVIRONMENT == 'development'
    load($0)
    lib_dir = "#{ROOT}/lib"
    return unless File.exist?(lib_dir)
    Dir.open(lib_dir).each do |file|      
      full_file_name = File.join(lib_dir, file)
      next unless File.file?(full_file_name)
      load(full_file_name)
    end
  end

  def connect_to_freeswitch
    send_and_read('connect')
    parse_response
  end

  def subscribe_to_events
    send_and_read('events plain all')
    parse_response    
    send_and_read("filter Unique-ID #{@unique_id}") 
    parse_response    
  end

  def subscribe_to_new_channel_events
    return unless call_vars[:event_name] == 'CHANNEL_BRIDGE'
    send_and_read("filter Unique-ID #{call_vars[:other_leg_unique_id]}")
  end

  def waiting_for_this_response?
    @waiting_for_key && @waiting_for_value && call_vars[@waiting_for_key] == @waiting_for_value
  end

  def last_event_dtmf?
    call_vars[:content_type] == 'text/event-plain' && call_vars[:event_name] == 'DTMF'
  end

  def api_response?
    call_vars[:content_type] == 'api/response'
  end

  def send_data(data)
    log.debug "Sending: #{data}"
    @io.write("#{data}\n\n") unless disconnect_notice?
  end

  def send_and_read(data)
    send_data(data)
    read_response
  end

  def read_response
    return if disconnect_notice?
    read_response_info
    read_event_header
    read_event_body
  end

  def read_response_info
    @response = ''
    begin
      line = @io.gets.to_s
      @response += line
    end until @response[-2..-1] == "\n\n"    
  end

  def read_event_header
    header_length = @response.sub(/.*^Content-Length: ([0-9]+)$.*/m, '\1').to_i
    return if header_length == 0
    header = ''
    if @response =~ /^Content-Type: api\/response/m
      begin
        line = @io.read(header_length).to_s
        header += line.to_s
      end until header.length == header_length
    else
      begin
        line = @io.gets.to_s
        header += line.to_s
      end until header[-2..-1] == "\n\n"
    end
    @response += header        
  end

  def read_event_body
    body_length = @response.sub(/^Content-Length.*^Content-Length: ([0-9]+)$.*/m, '\1').to_i
    return if body_length == 0
    body = ''
    begin
      line = @io.read(body_length).to_s
      body += line.to_s
    end until body.length == body_length
    @response += body    
  end

  def parse_response
    hash = {}
    if @response =~ /^Content-Length.*^Content-Length/m
      @event_body = @response.sub(/.*\n\n.*\n\n(.*)/m, '\1').strip 
    elsif @response =~ /^Content-Type: api\/response/m
      @event_body = Crack::XML.parse(@response.sub(/.*\n\n(.*)/m, '\1').strip )
    else
      @event_body = nil
    end
    @response.split("\n").each do |line|
      k,v = line.split(/\s*:\s*/)
      hash[k.strip.gsub('-', '_').downcase.to_sym] = URI.unescape(v).strip if k && v
    end    
    call_vars.merge!(hash)
    @unique_id ||= call_vars[:unique_id]
    raise call_vars[:reply_text] if call_vars[:reply_text] =~ /^-ERR/
    log.debug "\n\tUnique ID: #{call_vars[:unique_id]}\n\tContent-type: #{call_vars[:content_type]}\n\tEvent name: #{call_vars[:event_name]}"
    @response = ''
  end

end