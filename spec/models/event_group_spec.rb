require File.dirname(__FILE__) + '/../spec_helper'

describe EventGroup, "testing" do
  fixtures :event_groups

  it "should pass a tautology test" do
    puts EventGroup.find(:all).inspect
    true
  end
end
