# app/shell_worker.rb
#
# Kipangaratiba:
# Copyright (c) 2025 David S Anderson, All Rights Reserved
#

require 'sidekiq'
require_relative 'environ' # For logging
# -----------------------------


# +++++++++++++++++++++++++++++++++++++++++++++++++
module Kipangaratiba
# +++++++++++++++++++++++++++++++++++++++++++++++++
                
  class ShellWorker
    include Sidekiq::Worker

  # ------------------------------------------------------------
  # perform  -- expected method called BY the Sidekiq server process
  # activity_args: array of arguments to be passed to perform.
  #    by default, we are expecting the first item to be a command string
  #    to be run by the 'system' method
  # ------------------------------------------------------------
  def perform(*activity_args)
    
    if activity_args.empty?  # nop test ability
      Environ.log_info("ShellWorker: NOP activity performed")
    else   # cron-scheduled activity
      command_to_run = activity_args[0] # The command is the FIRST element
      Environ.log_info("ShellWorker: [invoked: #{command_to_run}]")
      system( command_to_run )
    end   # fi..else
  end

  end  # class
# +++++++++++++++++++++++++++++++++++++++++++++++++
end  # module
