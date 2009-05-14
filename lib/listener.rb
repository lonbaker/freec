require 'gserver'
require 'freec_logger'

class Listener < GServer  
  def initialize(host, port, application_class_name) #:nodoc:
    @application_class_name = application_class_name
    @logger = FreecLogger.new(['development', 'test'].include?(ENVIRONMENT) ? STDOUT : @@log_file)
    super(port, host, (1.0/0.0))
    self.audit = true
    connect_to_database
  end
        
  def serve(io) #:nodoc:
    app = Kernel.const_get(@application_class_name).new(io, @logger)
    app.handle_call
  rescue StandardError => e
    @logger.error e.message
    e.backtrace.each {|trace_line| @logger.error(trace_line)}    
  end

private
  
  def connect_to_database
    return unless @@config['database'] && @@config['database'][ENVIRONMENT]
    require 'active_record'
    ActiveRecord::Base.establish_connection(@@config['database'][ENVIRONMENT])
  end  
  
end