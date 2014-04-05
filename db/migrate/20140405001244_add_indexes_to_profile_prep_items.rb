class AddIndexesToProfilePrepItems < ActiveRecord::Migration
  def self.up
    add_index :profile_prep_items, :prep_item_id
    add_index :profile_prep_items, :profile_id
    add_index :profile_prep_items, [ :prep_item_id, :profile_id ]
  end

  def self.down
    remove_index :profile_prep_items, :prep_item_id
    remove_index :profile_prep_items, :profile_id
    remove_index :profile_prep_items, [ :prep_item_id, :profile_id ]
  end
end
