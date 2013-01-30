
require "rvm/capistrano"
#set :rvm_ruby_string, ENV['GEM_HOME'].gsub(/.*\//,"") # Read from local system
set :rvm_ruby_string, "ruby-1.9.2-p290"
set :rvm_type, :user
before 'deploy', 'rvm:install_rvm'



set :application, "procurement"
set :scm, "git"
set :branch, "master"
set :repository, "git://github.com/ChrisTIGeorgia/e-procurement-site.git"
server "192.168.0.241", :app, :web, :db, :primary => true
set :user, "tigeorgia"
default_run_options[:pty] = true
set :use_sudo, true
set :deploy_to, "/var/data/procurement/app"

desc "Install Passenger"
  task :install_passenger do
    install_passenger_module
    config_passenger
  end

  desc "Install Passenger Module"
  task :install_passenger_module do
    sudo "gem install passenger --no-ri --no-rdoc"
    input = ''
    run "sudo passenger-install-apache2-module" do |ch,stream,out|
      next if out.chomp == input.chomp || out.chomp == ''
      print out
      ch.send_data(input = $stdin.gets) if out =~ /(Enter|ENTER)/
    end
  end

  desc "Configure Passenger"
  task :config_passenger do
    ruby_version = "ruby-1.9.2-p290@bootstrap_starter" 
    version = 'ERROR'#default
    #passenger (2.0.3, 1.0.5)
    run("gem list | grep passenger") do |ch, stream, data|
      version = data.sub(/passenger \(([^,]+).*/,"\\1").strip
    end

    puts "passenger version #{version} configured"

    passenger_config =<<-EOF
      LoadModule passenger_module ~/.rvm/gems/#{ruby_version}/gems/passenger-#{version}/ext/apache2/mod_passenger.so
      PassengerRoot ~/.rvm/gems/#{ruby_version}/gems/passenger-#{version}
      PassengerRuby ~/.rvm/wrappers/#{ruby_version}/ruby
    EOF

    put passenger_config, "src/passenger"
    sudo "mv src/passenger /etc/apache2/conf.d/passenger"
  end
