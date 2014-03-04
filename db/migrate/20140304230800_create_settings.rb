class CreateSettings < ActiveRecord::Migration
  def self.up
    create_table :settings do |t|
      t.string :name
      t.text :value

      t.timestamps
    end
    Setting.create! :name => "footer", "value" => %|
<b>General Inquiries:</b>pat.help@powertochange.org<br/>
<br/>
Online help can be found <a href="http://resources.campusforchrist.org/index.php/Project_Application_Tool">here</a>.
|
  end

  def self.down
    drop_table :settings
  end
end
