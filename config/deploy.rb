puts ENV['target']

role :app, "ministryapp.com"
role :web, "ministryapp.com"
role :db,  "ministryapp.com", :primary => true

ssh_options[:port] = 40022
set :user, "andrew"

set :application, "Project Application Tool"

if ENV['target'] == 'dev'
  set :repository,  "https://svn.ministryapp.com/pat/trunk"
  set :deploy_to, "/var/www/dev.pat.ministryapp.com"
else
  set :repository,  "https://svn.ministryapp.com/pat/trunk"
  set :deploy_to, "/var/www/pat.ministryapp.com"
end

# If you aren't using Subversion to manage your source code, specify
# your SCM below:
# set :scm, :subversion

desc "Restart the web server"
deploy.task :restart, :roles => :app do
  # sudo "/opt/lsws/bin/lswsctrl restart"
  run "touch #{current_path}/tmp/restart.txt"
end