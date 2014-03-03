class Staff < ActiveRecord::Base
  load_mappings
  belongs_to :person
  delegate :staff_campuses, :to => :person
  delegate :staff_assignments, :to => :person

  def email
    person.email
  end

  def last_login
    person.try(:user).try(:last_login)
  end

  def gcx
    person.try(:user).try(:guid).present?
  end

  def login
    person.try(:user).try(:username)
  end

  def add_campus(campus, role = nil)
    role ||= StaffRole.find_by_name("Staff")
    params = { :campus_id => campus.id, :ministry_role_id => role.id }
    mi = person.staff_assignments.find(:first, :conditions => params)
    unless mi
      mi = person.staff_assignments.build params
      mi.save!
    end
  end

  def campuses_list
    self.view_all_campuses ? 'All' : self.staff_campuses.collect(&:short_desc).join(", ")
  end
end
