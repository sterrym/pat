namespace :db do

  desc 'Dumps the entire database to an sql file.'
  task :dump => :environment do

    db_config = Rails.configuration.database_configuration
    user = db_config[Rails.env]['username']
    password = db_config[Rails.env]['password']
    host = db_config[Rails.env]['host']
    database = ENV['db'].present? ? ENV['db'] : db_config[Rails.env]['database']

    File.mkdir(Rails.root.join("tmp")) unless File.directory?(Rails.root.join("tmp"))
    filename = Rails.root.join("tmp/dump-#{database}-#{Time.now.strftime('%Y-%m-%d')}.sql")
    puts "Dumping #{database} to #{filename}"

    command = 'mysqldump'
    command += ' --extended-insert'
    command += ' --skip-lock-tables'
    command += ' --skip-add-locks'
    command += ' --disable-keys'
    command += ' --default-character-set=utf8'
    command += " -u #{user}"
    command += " -h #{host}" unless host.blank?
    command += " -p#{password}" unless password.blank?
    command += " #{database}"
    command += " > #{filename}"

    sh command
  end
end
