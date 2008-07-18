ENV['target'] ||= 'prod'

puts "target = '#{ENV['target']}'"
puts

role :app, "ministryapp.com"
role :web, "ministryapp.com"
role :db,  "ministryapp.com", :primary => true

ssh_options[:port] = 40022
set :user, "andrew"

set :application, "Project Application Tool"

if ENV['target'] == 'dev'
  set :repository,  "https://svn.ministryapp.com/pat/trunk"
  set :deploy_to, "/var/www/dev.pat.ministryapp.com"
  RAILS_ENV = 'development'
elsif ENV['target'] == 'demo'
  set :repository,  "https://svn.ministryapp.com/pat/trunk"
  set :deploy_to, "/var/www/demo.pat.ministryapp.com"
  RAILS_ENV = 'production'
elsif ENV['target'] == 'prod'
  set :repository,  "https://svn.ministryapp.com/pat/trunk"
  set :deploy_to, "/var/www/pat.ministryapp.com"
  RAILS_ENV = 'production'
end

# If you aren't using Subversion to manage your source code, specify
# your SCM below:
# set :scm, :subversion

desc "Restart the web server"
deploy.task :restart, :roles => :app do
  # sudo "/opt/lsws/bin/lswsctrl restart"
  run "touch #{current_path}/tmp/restart.txt"
end

deploy.task :before_migrate do
  run "cd #{current_path}; RAILS_ENV=#{RAILS_ENV} rake db:setup:pat"
end

unless ENV['target'] == 'demo'
  deploy.task :after_symlink do
    run "cp #{File.join(deploy_to, 'database.yml')} #{File.join(current_path, 'config', 'database.yml')}"
  end
end
