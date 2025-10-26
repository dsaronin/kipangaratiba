# --- kipanga_scheduler.rb ---
#
# Kipangaratiba:
# Copyright (c) 2025 David S Anderson, All Rights Reserved
#

require 'singleton'
require_relative 'environ' # Required for Environ.log_info, Environ.my_monitor_default
require_relative 'angalia_error' # Required for KipangaSchedulerError, KipangaSchedulerOperationError

# +++++++++++++++++++++++++++++++++++++++++++++++++
module Kipangaratiba              # Define the top-level module  
# +++++++++++++++++++++++++++++++++++++++++++++++++

class KipangaScheduler
  include Singleton

  def initialize
    verify_configuration # Perform configuration check on initialization
  end

  # ------------------------------------------------------------
  # verify_configuration -- Checks for critical 
  # Raises KipangaSchedulerError if configuration is incorrect.
  # ------------------------------------------------------------
  def verify_configuration
    Environ.log_info("KipangaScheduler: Verifying configuration.")
  end # verify_configuration

  #  ------------------------------------------------------------
  #  ------------------------------------------------------------

end  # Class KipangaScheduler

end  # module Kipangaratiba
