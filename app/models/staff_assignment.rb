class StaffAssignment < ActiveRecord::Base
  belongs_to :campus
  belongs_to :ministry_role
  belongs_to :person
end
