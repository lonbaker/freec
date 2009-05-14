require "#{File.dirname(__FILE__)}/spec_helper"

describe Freec do

  before do
    @io = stub(:io)
    log = FreecLogger.new(STDOUT)
    log.level = Logger::FATAL
    @freec = Freec.new(@io, log)
  end

  describe "call initialization" do

    it "sends 'connect' command to Freeswitch" do
      @freec.should_receive(:send_data).with("connect")
      @freec.should_receive(:send_data)
      @io.should_receive(:gets).twice.and_return(EVENT)
      @freec.send :call_initialization
    end
    
    it "subscribes to events" do
      @freec.should_receive(:send_data)
      @freec.should_receive(:send_data).with('myevents')
      @io.should_receive(:gets).twice.and_return(EVENT)
      @freec.send :call_initialization
    end
    
  end

  describe "response reader" do

    it "should recognize the response buffer is not a complete response if it doesn't end with two new lines and it's not an event with body" do
      @freec.instance_variable_set(:@response, 'hey')
      @freec.send(:response_complete?).should be_false
    end
  
    it "should recognize the response as complete if its data ends with two new line characters" do
      @freec.instance_variable_set(:@response, EVENT)
      @freec.send(:response_complete?).should be_true
    end
  
    it "should recognize the response as complete if it is a complete event with body" do
      @freec.instance_variable_set(:@response, EVENT_WITH_BODY)
      @freec.send(:response_complete?).should be_true
    end
  
    it "should make the body of the response available as a public method - side-effect of response_complete? call.." do
      @freec.instance_variable_set(:@response, EVENT_WITH_BODY)
      @freec.send(:response_complete?).should be_true
      @freec.event_body.should =~ /<\/interpretation>$/
    end
  
  
    it "should recognize last event was DTMF to call the on_dtmf callback" do
      dtmf_event = "Event-Name: DTMF\nDTMF-Digit: 1\n#{EVENT}".sub('command/reply', 'text/event-plain')
      @freec.instance_variable_set(:@response, dtmf_event)
      @freec.send(:parse_response)
      @freec.send(:last_event_dtmf?).should be_true
    end
  
    it "should recognize an event as a non-DTMF one" do
      @freec.instance_variable_set(:@response, EVENT)
      @freec.send(:parse_response)
      @freec.send(:last_event_dtmf?).should be_false
    end
  
    it "should recognize that app execution has been completed for the last run app" do
      @freec.instance_variable_set(:@last_app_executed, 'set')
      set_executed_event = "Event-Name: CHANNEL_EXECUTE_COMPLETE\n\n#{EVENT}".sub('command/reply', 'text/event-plain')
      @freec.instance_variable_set(:@response, set_executed_event)
      @freec.send(:parse_response)      

      @freec.send(:execute_completed?).should be_true
      @freec.instance_variable_get(:@last_app_executed).should be_nil
    end
  
    it "should recognize that app execution has been completed but not for the last run one" do
      @freec.instance_variable_set(:@last_app_executed, 'different')
      set_executed_event = "Event-Name: CHANNEL_EXECUTE_COMPLETE\n\n#{EVENT}".sub('command/reply', 'text/event-plain')
      @freec.instance_variable_set(:@response, set_executed_event)
      @freec.send(:parse_response)      

      @freec.send(:execute_completed?).should be_false
      @freec.instance_variable_get(:@last_app_executed).should == 'different'
    end
  
    it "should hangup the call, send exit command to Freeswitch and disconnect from it when step callback returns nil" do
      execute_completed_event = "Event-Name: CHANNEL_EXECUTE_COMPLETE\n\n#{EVENT}".sub('command/reply', 'text/event-plain')
      @freec.should_receive(:send_data).with("connect")
      @freec.should_receive(:send_data).with("myevents")      
      @io.should_receive(:gets).and_return(execute_completed_event, execute_completed_event, "bye\n\n")
      @freec.instance_variable_set(:@last_app_executed, 'set')
      @freec.should_receive(:step).and_return(nil)
      @freec.should_receive(:execute_app).with('hangup')
      @freec.should_receive(:on_hangup)
      @freec.should_receive(:send_data).with("exit")      
      @freec.handle_call
    end

    it "should exit when Freeswitch disconnects (e.g. caller hangs up)" do
      disconnect_event = EVENT.sub('command/reply', 'text/disconnect-notice')
      @freec.should_receive(:send_data).with("connect")
      @freec.should_receive(:send_data).with("myevents")      
      @io.should_receive(:gets).and_return(EVENT, disconnect_event)
      @freec.instance_variable_set(:@last_app_executed, 'set')
      @freec.should_receive(:step).and_return(true)
      @freec.should_receive(:execute_app).with('hangup')
      @freec.should_receive(:on_hangup)
      @freec.should_receive(:send_data).with("exit")      
      @freec.handle_call
    end
  
  end
  
  describe "callback exception handling" do
  
    it "should catch and log any exception occurred in a callback" do
      @freec.should_receive(:callback_name).and_raise(RuntimeError)
      @freec.log.should_receive(:error).with('RuntimeError')
      @freec.log.should_receive(:error).at_least(1).times #backtrace
      lambda { @freec.send(:callback, :callback_name) }.should_not raise_error(Exception)
    end
  
  end
  
  describe "custom waiting conditions" do
    
    it "should return true from waiting_for_this_response? when the conditions for the response are met" do
      @freec.wait_for(:content_type, 'command/reply')
      @freec.instance_variable_set(:@response, EVENT)
      @freec.send(:parse_response)
      @freec.send(:waiting_for_this_response?).should be_true
    end
  
    it "should return false from waiting_for_this_response? when the conditions for the response are not met" do
      @freec.wait_for(:content_type, 'text/event-plain')
      @freec.instance_variable_set(:@response, EVENT)
      @freec.send(:parse_response)
      @freec.send(:waiting_for_this_response?).should be_false
    end
  
    it "should reset the waiting conditions after they have been met" do      
      @freec.wait_for(:content_type, 'command/reply')
      @freec.should_receive(:send_data).with("connect")
      @freec.should_receive(:send_data).with("myevents")      
      @io.should_receive(:gets).and_return(EVENT, EVENT, "bye\n\n")
      @freec.instance_variable_set(:@last_app_executed, 'set')
      @freec.should_receive(:step).and_return(nil)
      @freec.should_receive(:execute_app).with('hangup')
      @freec.should_receive(:on_hangup)
      @freec.should_receive(:send_data).with("exit")      
      @freec.handle_call
      @freec.send(:waiting_for_this_response?).should be_nil
    end
  
  end

end