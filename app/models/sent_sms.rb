class SentSms < ActiveRecord::Base
  belongs_to :received_sms
  @queue = :sms
  serialize :reports
  default_value_for :sent_via, 'twilio'
  
  after_create :queue_sms
  
  private
    def queue_sms
      async(:send_sms)
    end
  
    def send_sms
      case sent_via 
      when 'moonshado'
        self.moonshado_claimcheck = SMS.deliver(recipient, message).first #  + ' Txt HELP for help STOP to quit'
      when 'twilio'
        sms = Twilio::SMS.create :to => recipient, :body => 'test', :from => '85005'
      else
        raise "Not sure how to send this sms: sent_via = #{sent_via}"
      end
      save
    
      # Log count sent through this carrier (just for fun)
      if received_sms
        carrier = SmsCarrier.find_or_create_by_moonshado_name(received_sms.carrier) 
        carrier.increment!(:sent_sms)
      end
    end
  
end
