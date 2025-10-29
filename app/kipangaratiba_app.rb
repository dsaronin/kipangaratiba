#!/usr/bin/env ruby
# Kipangaratiba: user-space cron-like scheduler
# Copyright (c) 2025 David S Anderson, All Rights Reserved
#
# ------------------------------------------------------------
# kipangaratiba_app.rb  -- starting point for sinatra web app
# Assumes KipangaratibaWork and Environ are loaded via config.ru and available globally
# through the KIPANGARATIBA constant.
# ------------------------------------------------------------

require 'sinatra'
require 'haml'
require_relative 'tag_helpers'
require 'sinatra/form_helpers' # Useful forms on the home or status page
require 'rack-flash' # displaying success/error messages to the user
require 'yaml'       # FUTURE: use by Environ for configuration loading
require 'thread'     # Mutex
require_relative 'kipangaratiba_error' # Required for KipangaratibaError, LivestreamForceStopError

# +++++++++++++++++++++++++++++++++++++++++++++++++
module Kipangaratiba # Kipangaratiba Namespace
# +++++++++++++++++++++++++++++++++++++++++++++++++

class KipangaratibaApp < Sinatra::Application
  helpers Sinatra::AssetHelpers # Explicitly include your AssetHelpers

  enable :sessions
  use Rack::Flash

  set :root, File.dirname(__FILE__)
  set :views, File.join(File.dirname(__FILE__), 'views') # Explicitly set views directory
  
 # Disable show_exceptions in development to ensure 'error do' block is hit
 # set :show_exceptions, false # used for testing

  # MUTEX SYNCED VALUES =======================================================
  # =============================================================================

  # ------------------------------------------------------------
  # Web Server Routes
  # ------------------------------------------------------------

  # ------------------------------------------------------------
  # GET /
  # Home Page
  # Displays the main caregiver control panel with action buttons.
  # @is_livestream true when we want the index.haml javascript to be
  # engaged displaying the livestream within the img field.
  # ------------------------------------------------------------
  get '/' do
    haml :index
  end # get /

  get '/disclaimers' do
    haml :disclaimers
  end

  get '/about' do
    haml :about
  end

  # ------------------------------------------------------------
  # GET /status
  # View System Status (Developer/Debug)
  # Displays current system status information for debugging/monitoring.
  # ------------------------------------------------------------
  get '/status' do
    @status_info = KIPANGARATIBA.do_status 
    flash[:error] = @status_info
    redirect '/'
  end # get /status

   # ------------------------------------------------------------
   # GET /testnop
   # Queues two test jobs: one immediate, one scheduled.
   # ------------------------------------------------------------
   get '/testnop' do
     # Call the class methods on the scheduler
     KIPANGARATIBA.my_scheduler.schedule_nop_activity
     KIPANGARATIBA.my_scheduler.schedule_nop_script
     KIPANGARATIBA.my_scheduler.schedule_job_in(
       60, # 1 minute
       "bash ~/bin/nop_test.sh 'Interval NOP job (1-min)'"
     )
 
     # 'schedule_job_at' 5 min ago; should ignore
     target_time_at = Time.now - (5 * 60) # 5 min ago
     KIPANGARATIBA.my_scheduler.schedule_job_at(
       target_time_at,
       "bash ~/bin/nop_test.sh 'NOP job for a past time'"
     ) 
 
     # 'schedule_job_at' (runs in 120 seconds)
     target_time_at = Time.now + (2 * 60) # 2 minutes
     KIPANGARATIBA.my_scheduler.schedule_job_at(
       target_time_at,
       "bash ~/bin/nop_test.sh 'non-cron scheduled NOP job (2-min)'"
     ) 
     flash[:notice] = "TESTNOP: Scheduled 4 NOP jobs"
     redirect '/'
   end # get /testnop
  # ------------------------------------------------------------
  # Error Handling
  # ------------------------------------------------------------

  # ------------------------------------------------------------
  # Generic error handler for 404 Not Found pages.
  # ------------------------------------------------------------
  not_found do
    status 404
    haml :err_404
  end

  # ------------------------------------------------------------
  # Generic error handler for 500 Internal Server Errors.
  # ------------------------------------------------------------
  error do
    status 500
    @error_message = env['sinatra.error'].message
    Environ.log_error "Internal Server Error: #{@error_message}"
    haml :err_500
  end
  # ------------------------------------------------------------
    # TEMPORARY ROUTE TO FORCE 500 ERROR
  # ------------------------------------------------------------
    get '/force_500' do
      raise "This is a forced 500 error for testing purposes!"
    end
    # END TEMPORARY ROUTE
  # ------------------------------------------------------------


end # class KipangaratibaApp

end  # module Kipangaratiba
