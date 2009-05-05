require "#{File.dirname(__FILE__)}/spec_helper"


describe "Freec parses body-less event" do

  before do
    class FreecForEventSpec < Freec
      def post_init
        log.level = Logger::FATAL 
        @response = EVENT
        parse_response
      end
    end
    @freec = FreecForEventSpec.new('')
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

describe "Freec parses an event with a body" do
  before do
    class FreecForEventSpec < Freec
      def post_init
        log.level = Logger::FATAL 
        @response = EVENT_WITH_BODY
        parse_response
      end
    end
    @freec = FreecForEventSpec.new('')
  end
    
  it "should parse the variables from the event header" do
    @freec.call_vars[:event_name].should == 'DETECTED_SPEECH'
  end

end