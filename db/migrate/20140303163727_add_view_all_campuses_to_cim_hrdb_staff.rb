class AddViewAllCampusesToCimHrdbStaff < ActiveRecord::Migration
  def self.up
    add_column :cim_hrdb_staff, :view_all_campuses, :boolean
  end

  def self.down
    remove_column :cim_hrdb_staff, :view_all_campuses
  end
end
