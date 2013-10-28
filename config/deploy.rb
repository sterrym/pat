set :application, 'pat'
set :use_sudo, false
set :keep_releases, '2'
after "deploy:update", "deploy:cleanup" 
#after "deploy:update_code", "after_update_code" 

set :user, 'deploy'
set :repository, "git://github.com/PowerToChange/pat.git"
set :scm, "git"
set :deploy_via, :remote_cache

task :production do
  role :app, 'pat.powertochange.org'
  role :db, 'pat.powertochange.org'
  set :branch, 'master'
  set :deploy_to, "/var/www/pat.powertochange.org"
end

task :staging do
  role :app, 'elk.campusforchrist.org'
  role :db, 'elk.campusforchrist.org'
  set :branch, 'staging'
  set :deploy_to, '/var/www/elk.campusforchrist.org'
end

desc "Add linked files after deploy and set permissions"
task :after_update_code, :roles => :app do
  run <<-CMD
    ln -s #{shared_path}/config/database.yml #{release_path}/config/database.yml &&
    mkdir -p -m 770 #{shared_path}/tmp/{cache,sessions,sockets,pids} &&
    mkdir -p -m 770 #{release_path}/tmp/cache &&
    ln -s #{shared_path}/public/attachments #{release_path}/public/attachments &&
    ln -s #{shared_path}/public/event_groups #{release_path}/public/event_groups &&
    ln -s #{shared_path}/public/resources #{release_path}/public/resources
  CMD

  run "cd #{release_path} && git submodule init"
  run "cd #{release_path} && git submodule update"
end

namespace :deploy do
  task :restart do
    run "cd #{current_path}/tmp && touch restart.txt"
  end

  task :update_code, :except => { :no_release => true } do
    #on_rollback { run "rm -rf #{release_path}; true" }
    strategy.deploy!
    finalize_update
  end
end

namespace :db do
  task :pull do
    rake = fetch(:rake, "rake")
    rails_env = fetch(:rails_env, "production")
    out = capture "bash --login -c 'cd #{current_path}; rake RAILS_ENV=#{rails_env} db:dump #{"remotedb=#{ENV['remotedb']}" if ENV['remotedb']}'"
    puts "output: #{out}"
    out =~ /Dumping (.*) to (.*)/
    remote_db = $1
    remote_file = $2

    db_config = YAML::load(File.open("config/database.yml"))
    user = db_config[rails_env]['username']
    password = db_config[rails_env]['password']
    host = db_config[rails_env]['host'] || 'localhost'
    local_db = ENV['db'] ? ENV['db'] : db_config[rails_env]['database']
    get remote_file, File.basename(remote_file)

    puts "This will recreate your #{local_db} database.  Are you sure? (y/n)"
    if STDIN.gets.chomp.downcase == 'y'
      run_locally "cat #{File.basename(remote_file)} | mysql --user #{user} #{"-p#{password}" if password} --host #{host} #{local_db}"
    end
  end
end
