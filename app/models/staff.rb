class Staff < ActiveRecord::Base
  load_mappings
  belongs_to :person

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
end
