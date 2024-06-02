module Agents
  class GoogleCalendarEventCheckerAgent < Agent
    include FormConfigurable
    can_dry_run!
    no_bulk_receive!
    default_schedule 'every_1h'

    description do
      <<-MD
      The GoogleCalendarEventChecker Agent interacts with Google calendar's api.

      `debug` is used for verbose mode.

      `time_max` is needed to limit the result.

      `calendar_id` is the wanted id of the calendar you want to check.

      `service_acount_credentials` is needed for auth.

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
      MD
    end

    event_description <<-MD
      Events look like this:

         {
           "created": "2024-06-02T10:05:50.000+00:00",
           "creator": {
             "email": "XXXXXXXXXX@gmail.com"
           },
           "end": {
             "dateTime": "2024-06-02T14:00:00.000+02:00",
             "timeZone": "Europe/Paris"
           },
           "etag": "\"XXXXXXXXXXXXXXXX\"",
           "htmlLink": "https://www.google.com/calendar/event?eid=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
           "iCalUID": "XXXXXXXXXXXXXXXXXXXXXXXXXX@google.com",
           "id": "XXXXXXXXXXXXXXXXXXXXXXXXXX",
           "kind": "calendar#event",
           "organizer": {
             "displayName": "XXXXXXXXXXXXX",
             "email": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX@group.calendar.google.com",
             "self": true
           },
           "reminders": {
             "useDefault": true
           },
           "sequence": 0,
           "start": {
             "dateTime": "2024-06-02T13:00:00.000+02:00",
             "timeZone": "Europe/Paris"
           },
           "status": "confirmed",
           "summary": "test new event",
           "updated": "2024-06-02T10:05:50.005+00:00"
         }

    MD

    def default_options
      {
        'calendar_id' => '',
        'time_max' => '10',
        'service_acount_credentials' => '',
        'debug' => 'false',
        'expected_receive_period_in_days' => '31',
      }
    end

    form_configurable :calendar_id, type: :string
    form_configurable :time_max, type: :string
    form_configurable :service_acount_credentials, type: :string
    form_configurable :debug, type: :boolean
    form_configurable :expected_receive_period_in_days, type: :string
    def validate_options

      unless options['calendar_id'].present?
        errors.add(:base, "calendar_id is a required field")
      end

      unless options['service_acount_credentials'].present?
        errors.add(:base, "service_acount_credentials is a required field")
      end

      unless options['time_max'].present?
        errors.add(:base, "time_max is a required field")
      end

      if options.has_key?('debug') && boolify(options['debug']).nil?
        errors.add(:base, "if provided, debug must be true or false")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def check
      check_events
    end

    private

    def already_notified(id)
      memory['notified'].include?(id)
    end

    def clean_notified(response)
      current_event_ids = response.items.map(&:id)
      memory['notified'].reject! { |id| !current_event_ids.include?(id) }
      memory['notified'].uniq!
    end
    
    def check_events()
      calendar = Google::Apis::CalendarV3::CalendarService.new
      calendar.client_options.application_name = 'App Name'
      calendar.client_options.application_version = 'App Version'

      #deal with possible service account in huginn
      Tempfile.create(['service_acount_credentials_google_calendar', '.json']) do |file|
        file.write(interpolated['service_acount_credentials'])
        file.rewind
        ENV['GOOGLE_APPLICATION_CREDENTIALS'] = file.path
        scopes = [Google::Apis::CalendarV3::AUTH_CALENDAR]
        calendar.authorization = Google::Auth.get_application_default(scopes)
      end
      time_max = (Time.now + interpolated['time_max'].to_i * 24 * 60 * 60).iso8601
      begin
        response = calendar.list_events(interpolated['calendar_id'],
                                        max_results: 10,
                                        single_events: true,
                                        order_by: 'startTime',
                                        time_min: Time.now.iso8601,
                                        time_max: time_max)
    
        if response.items.empty?
          memory['notified'] = []
          if interpolated['debug'] == 'true'
            puts 'No upcoming events found'
          end
        else
          response.items.each do |event|
            memory['notified'] = [] if memory['notified'].nil?
            if event.id && !already_notified(event.id)
              if interpolated['debug'] == 'true'
                log "not already notified"
              end
              create_event payload: event.to_json
              memory['notified'] << event.id
            else
              if interpolated['debug'] == 'true'
                log "already notified"
              end
            end
          end
          clean_notified(response)
        end
      end
    end
  end
end
