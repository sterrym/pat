class ChangeCimHrdbCampusesToTakeNulls < ActiveRecord::Migration
  def self.up
    change_column :cim_hrdb_campus, :accountgroup_id, :integer, :default => 0, :null => true
    change_column :cim_hrdb_campus, :region_id, :integer, :default => 0, :null => true
    change_column :cim_hrdb_campus, :campus_website, :string, :default => "", :null => true
    change_column :cim_hrdb_campus, :campus_facebookgroup, :string, :null => true
    change_column :cim_hrdb_campus, :campus_gcxnamespace, :string, :null => true
    Campus.connection.execute("ALTER TABLE cim_hrdb_campus DROP FOREIGN KEY FK_campus_region")
  end

  def self.down
    change_column :cim_hrdb_campus, :accountgroup_id, :integer, :default => 0, :null => true
    change_column :cim_hrdb_campus, :region_id, :integer, :default => 0, :null => true
    change_column :cim_hrdb_campus, :campus_website, :string, :default => "", :null => true
    change_column :cim_hrdb_campus, :campus_facebookgroup, :string, :null => true
    change_column :cim_hrdb_campus, :campus_gcxnamespace, :string, :null => true
  end
end
