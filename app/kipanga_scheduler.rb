# --- kipanga_scheduler.rb ---
#
# Kipangaratiba:
# Copyright (c) 2025 David S Anderson, All Rights Reserved
#

require 'singleton'
require_relative 'environ' # Required for Environ.log_info, Environ.my_monitor_default
require_relative 'kipangaratiba_error' # Required for KipangaSchedulerError, KipangaSchedulerOperationError

# --- Additions for Sidekiq ---
require 'sidekiq'
require 'sidekiq-cron'
# -----------------------------


# +++++++++++++++++++++++++++++++++++++++++++++++++
module Kipangaratiba              # Define the top-level module  
# +++++++++++++++++++++++++++++++++++++++++++++++++

class KipangaScheduler
  include Singleton

  def initialize
    setup_sidekiq_config # Configure Redis connection first
    verify_configuration # Perform configuration check on initialization
  end

  # ------------------------------------------------------------
  # verify_configuration -- Checks for critical 
  # Raises KipangaSchedulerError if configuration is incorrect.
  # ------------------------------------------------------------
  def verify_configuration
    Environ.log_info("KipangaScheduler: Verifying configuration.")
    begin
      info = Sidekiq.Sidekiq.redis_pool.with { |conn| conn.info }
      Environ.log_info("KipangaScheduler: Redis connection verified. Version: #{info['redis_version']}")
    rescue => e
      Environ.log_error("KipangaScheduler: FAILED to connect to Redis: #{e.message}")
      raise # Re-raise to halt startup
    end
  end # verify_configuration

  #  ------------------------------------------------------------
  #  ------------------------------------------------------------
private

  # ------------------------------------------------------------
  # setup_sidekiq_config -- Configures Sidekiq client and server
  # Connects Sidekiq to the local Redis instance.
  # ------------------------------------------------------------
  def setup_sidekiq_config
    Sidekiq.configure_server do |config|
      config.redis = { url: 'redis://localhost:6379/0' }
      Environ.log_info("KipangaScheduler: Sidekiq server configured for Redis.")
    end

    Sidekiq.configure_client do |config|
      config.redis = { url: 'redis://localhost:6379/0' } 
      Environ.log_info("KipangaScheduler: Sidekiq client configured for Redis.")
    end
  end # setup_sidekiq_config


end  # Class KipangaScheduler

end  # module Kipangaratiba

