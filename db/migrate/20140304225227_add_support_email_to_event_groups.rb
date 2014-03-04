class AddSupportEmailToEventGroups < ActiveRecord::Migration
  def self.up
    add_column :event_groups, :support_email, :string
  end

  def self.down
    remove_column :event_groups, :support_email
  end
end
