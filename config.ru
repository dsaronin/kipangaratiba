# config.ru

require 'sinatra'
require_relative './app/kipangaratiba_app'
require_relative './app/kipangaratiba_work'
# --------------------------------------------------
# *** TEMPLATE USAGE substitution replacements ***
# kipangaratiba -> application name: angalia, majozi, etc
# KIPANGARATIBA -> ditto, but all caps
# Kipangaratiba -> overall module name for project
# Kipangaratiba -> primary class name for project
# KipangaratibaWork -> work class name for project
# --------------------------------------------------

# --------------------------------------------------
# info -- outputs info msg to STDERR
# simple STDERR msg output similar to warn, abort
# --------------------------------------------------
  ANSI_RESET   = "\u001b[0m"
  GREEN_BOLD    = "\u001b[1;32m"
  def info(message)
    msg ="INFO: #{message}"
    $stderr.puts GREEN_BOLD + msg + ANSI_RESET
  end
# --------------------------------------------------

configure do
  ENV['SINATRA_ENV'] ||= "development"
  ENV['RACK_ENV']    ||= "development"
  ENV['DEBUG_ENV']    ||= true.to_s  # true if DEBUG mode

  info  "KIPANGARATIBA PREREQUISITES (troubleshooting check first) bundle install; chkpackage.sh; .bashrc last lines for rvm"
  info  "KIPANGARATIBA ENV=Sinatra: #{ENV['SINATRA_ENV']}, Rack: #{ ENV['RACK_ENV']}, Debug: #{ENV['DEBUG_ENV']}, SKIP: #{ENV['SKIP_HUB_VPN']}, VPN: #{ENV['VPN_TUNNEL_ENV']}"
  info  "Config.ru Initializing Kipangaratiba application..."

# --------------------------------------------------
  # Check system dependencies only in the "development" environment
  # If pkgcheck.sh returns a non-zero exit status (failure), abort startup.
  if ENV['SINATRA_ENV'] == "development"
    unless system("./pkgcheck.sh")
      warn "ERROR: Required system packages are missing or not found in PATH."
      warn "Please review the output of ./pkgcheck.sh for details on missing dependencies."
      abort "Aborting application startup due to missing system dependencies."
    end
  end

# --------------------------------------------------
# system environment confirmed; start application
# --------------------------------------------------
  Kipangaratiba = Kipangaratiba::KipangaratibaWork.new 
  Kipangaratiba.setup_work()    # initialization of everything

  PUBLIC_DIR = File.join(File.dirname(__FILE__), 'public')

  set :public_folder, PUBLIC_DIR
  set :root, File.dirname(__FILE__)
  set :haml, { escape_html: false }
  set :session_secret, ENV['TEMPLATE_APP_NAME_TOKEN'] 

  Kipangaratiba::Environ.log_info  "Config: PUBLIC_DIR: #{PUBLIC_DIR}"
  Kipangaratiba::Environ.log_warn  "Config: #{Kipangaratiba.do_version} ... initialization completed."
  
  # outputs name, version number

end  # configure

run Kipangaratiba::Kipangaratiba


# notes for execution
# thin -R config.ru -a 0.0.0.0 -p 8090 start
#
# http://localhost:8090/
# curl http://localhost:8090/ -H "My-header: my data"

