class EmailAddress < ActiveRecord::Base
  has_paper_trail :on => [:destroy],
                  :meta => { person_id: :person_id }

  belongs_to :person, inverse_of: :email_addresses, touch: true
  validates_presence_of :email, on: :create, message: "can't be blank"
  validates_format_of :email, with: /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i
  before_validation :set_primary, on: :create
  after_commit :ensure_only_one_primary
  after_destroy :set_new_primary
  validates_uniqueness_of :email, on: :create, message: "already taken"
  validates_uniqueness_of :email, on: :update, message: "already taken"
  strip_attributes :only => :email

  def to_s
    email
  end

  def merge(other)
    EmailAddress.transaction do
      if updated_at && other.primary? && other.updated_at && other.updated_at > updated_at
        person.email_addresses.collect {|e| e.update_attribute(:primary, false)}
        new_primary = person.email_addresses.detect {|e| e.email == other.email}
        new_primary.update_attribute(:primary, true) if new_primary
      end
      begin
        MergeAudit.create!(mergeable: self, merge_looser: other)
        other.reload
        other.destroy
      rescue ActiveRecord::RecordNotFound
        # ???
      end
    end
  end

  def is_unique?
    EmailAddress.where(email: email).blank?
  end

  def self.clean_emails
    count_deleted, count_updated = 0, 0;
    email_deleted, email_updated = {}, {};
    rejected_emails, duplicate_emails = {}, {};
    accepted_emails = [];
    dirty_emails = EmailAddress.where("email LIKE '% %'");
    dirty_emails.reverse.each do |dirty_email|
      valid_email = nil

      # Store raw email value
      raw_email_value = dirty_email.email
      # Fix unproperly written emails for "@ " and " @"
      dirty_email_value = raw_email_value.strip.gsub(/(\@\s)|(\ \@)/,'@')
      # Fix unproperly written emails for " .com"
      dirty_email_value = dirty_email_value.strip.gsub(' .com','.com')
      # Split email by spaces
      splitted_email = dirty_email_value.split(' ')

      splitted_email.each do |email|
        # Remove unnecessary characters
        clean_email = email.gsub(/\;|\<|\>|\,/,'').strip
        # Validate email address
        if valid_email.nil? && EmailAddress.new(email: clean_email).valid?
          valid_email = clean_email
          accepted_emails << clean_email
        elsif exist = EmailAddress.find_by_email(clean_email)
          # Check existing people
          # if exist.person_id != dirty_email.person_id
            duplicate_emails[clean_email] = "#{exist.person_id} - #{dirty_email.person_id}"
          # end
        else
          if valid_email.present?
            rejected_emails[clean_email] = 'ignored'
          else
            rejected_emails[clean_email] = 'invalid format'
          end
        end
      end

      if valid_email
        # Update email address
        dirty_email.email = valid_email;
        dirty_email.save!;
        email_updated["#{raw_email_value}"] = valid_email;
        count_updated += 1;
      else
        # Delete emaill address
        dirty_email.destroy;
        email_deleted["#{raw_email_value}"] = dirty_email_value;
        count_deleted += 1;
      end
    end

    # Print some report
    puts "---"
    puts "Email Address Cleaning Complete!"
    puts "---"
    puts "#{count_updated} email#{'s' if count_updated > 1} updated!"
    puts "#{email_updated.inspect}"
    puts "---"
    puts "#{count_deleted} email#{'s' if count_deleted > 1} deleted!"
    puts "#{email_deleted.inspect}"
    puts "---"
    puts "Accepted Emails"
    puts "#{accepted_emails.inspect}"
    puts "---"
    puts "Rejected Emails"
    puts "#{rejected_emails.inspect}"
    puts "---"
    puts "Duplicate Emails"
    puts "#{duplicate_emails.inspect}"
    puts "---"
  end

  protected

  def set_primary
    if person
      if !person.primary_email_address.frozen? && person.primary_email_address && person.primary_email_address.valid?
        self.primary = false
      else
        person.primary_email_address.try(:destroy)
        self.primary = true
      end
    else
      self.primary = true
    end
    true
  end

  def ensure_only_one_primary
    primary_emails = person.email_addresses.where(primary: true)
    if primary_emails.blank?
      person.email_addresses.last.update_column(:primary, true)
    elsif primary_emails.length > 1
      primary_emails[0..-2].map {|e| e.update_column(:primary, false)}
    end
  end

  def set_new_primary
    if self.primary?
      if person && person.email_addresses.present?
        person.email_addresses.first.update_attribute(:primary, true)
      end
    end
    true
  end

end
