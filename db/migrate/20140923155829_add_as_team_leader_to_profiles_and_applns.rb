class AddAsTeamLeaderToProfilesAndApplns < ActiveRecord::Migration
  def self.up
    add_column :applns, :as_team_leader, :boolean, :default => false
    add_column :profiles, :as_team_leader, :boolean, :default => false
  end

  def self.down
    remove_column :applns, :as_team_leader
    remove_column :profiles, :as_team_leader
  end
end
