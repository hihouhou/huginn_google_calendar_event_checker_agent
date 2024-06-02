require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::GoogleCalendarEventCheckerAgent do
  before(:each) do
    @valid_options = Agents::GoogleCalendarEventCheckerAgent.new.default_options
    @checker = Agents::GoogleCalendarEventCheckerAgent.new(:name => "GoogleCalendarEventCheckerAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
