class CreateStaffAssignments < ActiveRecord::Migration
  def self.up
    create_table :staff_assignments do |t|
      t.integer :person_id
      t.integer :campus_id
      t.integer :ministry_role_id

      t.timestamps
    end
  end

  def self.down
    drop_table :staff_assignments
  end
end
