require "#{File.dirname(__FILE__)}/spec_helper"

describe Freec do
  before do
    io = stub(:io)
    log = FreecLogger.new(STDOUT)
    log.level = Logger::FATAL
    @freec = Freec.new(io, log)
  end
  
  describe "parses body-less event" do

    before do
      @freec.instance_variable_set(:@response, EVENT)
      @freec.send :parse_response
    end
    
    it "should read unique id from response" do
      @freec.instance_variable_get(:@unique_id).should == '40117b0a-186e-11dd-bbcd-7b74b6b4d31e'
    end
    
    it "should parse variables from response" do
      @freec.call_vars[:channel_username].should == '1001'
      @freec.call_vars[:caller_context].should == 'default'
      @freec.call_vars[:variable_sip_user_agent].should == 'snom300/7.1.30'
    end    
  
    it "should make the value of the sip_from_user variable available as a method" do
      @freec.sip_from_user.should == '1001'
    end

    it "should make the value of the sip_to_user variable available as a method" do
      @freec.sip_to_user.should == '886'
    end

    it "should make the value of the channel_destination_number variable available as a method" do
      @freec.channel_destination_number.should == '886'
    end
  end

  describe "parses an event with a body" do
    before do
      @freec.instance_variable_set(:@response, EVENT_WITH_BODY)
      @freec.send :parse_response
    end
      
    it "should parse the variables from the event header" do
      @freec.call_vars[:event_name].should == 'DETECTED_SPEECH'
    end

  end
end