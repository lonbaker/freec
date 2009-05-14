require 'gserver'
require 'rubygems'
require 'uri'

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
      if last_event_dtmf? && respond_to?(:on_dtmf)
        callback(:on_dtmf, call_vars[:dtmf_digit])
      elsif waiting_for_this_response? || execute_completed?
        reset_wait_for if waiting_for_this_response?
        reload_application_code
        break if !callback(:step) || disconnect_notice?
      end      
      read_response
      parse_response
    end
    hangup
    callback(:on_hangup)
    send_and_read('exit')
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
    (channel_execute_complete? || channel_destroyed_after_bridge? || disconnect_notice?) &&
    call_vars[:unique_id] == @unique_id
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
    send_and_read('myevents')
    parse_response    
  end
      
  def waiting_for_this_response?
    @waiting_for_key && @waiting_for_value && call_vars[@waiting_for_key] == @waiting_for_value
  end
  
  def last_event_dtmf?
    call_vars[:content_type] == 'text/event-plain' && call_vars[:event_name] == 'DTMF' && call_vars[:unique_id] == @unique_id
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
    read_event
  end
  
  def read_response_info
    @response = ''
    begin
      line = @io.gets.to_s
      @response += line
    end until @response[-2..-1] == "\n\n"    
  end
  
  def read_event
    header_length = @response.sub(/^Content-Length: ([0-9]+)$.*/m, '\1').to_i
    return if header_length == 0
    event = ''
    begin
      line = @io.gets.to_s
      event += line.to_s
    end until event.length == header_length
    @response += event        
  end
        
  def parse_response
    hash = {}
    if @response =~ /^Content-Length.*^Content-Length/m
      @event_body = @response.sub(/.*\n\n.*\n\n(.*)/m, '\1').strip 
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
    log.debug "Received:"
    log.debug "Session ID\tContent-type\tApplication\tEvent name"
    log.debug "#{object_id}\t#{call_vars[:content_type]}\t#{call_vars[:application]}\t#{call_vars[:event_name]}"
    @response = ''
  end
  
end