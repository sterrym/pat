class AddInternAndTeamleaderOptionsToEventGroups < ActiveRecord::Migration
  def self.up
    add_column :event_groups, :has_interns, :boolean, :default => true
    add_column :event_groups, :has_team_leaders, :boolean, :default => false
  end

  def self.down
    remove_column :event_groups, :has_interns
    remove_column :event_groups, :has_team_leaders
  end
end
