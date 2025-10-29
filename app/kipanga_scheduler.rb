# --- kipanga_scheduler.rb ---
#
# Kipangaratiba:
# Copyright (c) 2025 David S Anderson, All Rights Reserved
#

require 'singleton'
require 'yaml'
require 'time'
require_relative 'environ' # Required for Environ.log_info, Environ.my_monitor_default

# --- Additions for Sidekiq ---
require 'sidekiq'
require 'sidekiq-cron'
# -----------------------------


# +++++++++++++++++++++++++++++++++++++++++++++++++
module Kipangaratiba              # Define the top-level module  
# +++++++++++++++++++++++++++++++++++++++++++++++++

class KipangaScheduler
  include Singleton

  # --- Private Class Constant for Day Mapping ---
  DAY_OF_WEEK_MAP = {
    'sunday'    => 0,
    'monday'    => 1,
    'tuesday'   => 2,
    'wednesday' => 3,
    'thursday'  => 4,
    'friday'    => 5,
    'saturday'  => 6
  }.freeze
  
  private_constant :DAY_OF_WEEK_MAP
  # ------------------------------------------------------------

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
      info = Sidekiq.redis_pool.with { |conn| conn.info }
      Environ.log_info("KipangaScheduler: Redis connection verified. Version: #{info['redis_version']}")
    rescue => e
      Environ.log_error("KipangaScheduler: FAILED to connect to Redis: #{e.message}")
      raise # Re-raise to halt startup
    end
  end # verify_configuration

  # ============================================================
  # --- PUBLIC SCHEDULING INTERFACE ---
  # ============================================================

  # ------------------------------------------------------------
  # reset_cron_table -- purges cron table
  # ------------------------------------------------------------
  def reset_cron_table
    Sidekiq::Cron::Job.destroy_all!
    Environ.log_info("KipangaScheduler: PURGING ALL previous cron jobs")
  end

  def reset_sidekiq_queues
    Sidekiq::DeadSet.new.clear
    Sidekiq::RetrySet.new.clear
    Sidekiq::ScheduledSet.new.clear
    Sidekiq::Queue.all.each(&:clear)
    Environ.log_info("KipangaScheduler: PURGING ALL sidekiq queues")
  end

  # ------------------------------------------------------------
  # NOTE: all parameters for scheduling follow same format
  # *args [Array] -- Arguments to pass to ShellWorker.perform
  # *args empty: immediate nop (writes to log)
  # args[0]: command-string for system() call
  # ------------------------------------------------------------
  # schedule_job_now  -- queues background job for immediate execution
  # ------------------------------------------------------------
  def schedule_job_now(*args)
    Environ.log_info("KipangaScheduler: Scheduling job now: #{args.inspect}")
    ShellWorker.perform_async(*args)
  end

  # ------------------------------------------------------------
  #schedule_job_in  -- schedules background job for execution after a time interval
  # interval [Integer, Float]  -- wait time interval in seconds
  # ------------------------------------------------------------
  def schedule_job_in(interval, *args)
    Environ.log_info("KipangaScheduler: Scheduling job after #{interval}-sec: #{args.inspect}")
    ShellWorker.perform_in(interval, *args)
  end

  # ------------------------------------------------------------
  # schedule_job_at  --  schedules background job to run at specific 'time'
  # time [Time] -- specific time at which to run the job
  # ------------------------------------------------------------
  def schedule_job_at(time, *args)
    Environ.log_info("KipangaScheduler: Scheduling job for #{time}: #{args.inspect}")
    ShellWorker.perform_at(time, *args)
  end

  # ------------------------------------------------------------
  # schedule_cron_job -- schedules/updates a recurring background job rule
  # options_hash [Hash] 
  #    name: <string>
  #    cron:  <string>
  #    class:  <string>
  #    args:  <activity-args array>
  # ------------------------------------------------------------
  def schedule_cron_job(options_hash)
    Environ.log_info("KipangaScheduler: schedules/updates cron: #{options_hash[:name]}")
    Sidekiq::Cron::Job.create(options_hash)
  end

  #  ------------------------------------------------------------
  #  schedule_nop_activity -- queues a nop activity to verify sidekiq
  #  ------------------------------------------------------------
  def schedule_nop_activity
    Environ.log_info("KipangaScheduler: [TEST] Queuing NOP job...")
    schedule_job_now()
  end

  #  ------------------------------------------------------------
  #  schedule_nop_script --  schedules an empty script for execution
  #  ------------------------------------------------------------
  def schedule_nop_script   

    # Calculate the target time to be 3 min from now
    target_time = Time.now + (3 * 60) # 3 minutes from now
    
    # Format the time as a 5-field cron string: "Min Hour Day Month DayOfWeek"
    # This will run once at the specified time.
    cron_string = target_time.strftime("%M %H %d %m %w")
    Environ.log_info("KipangaScheduler: NOP script scheduled for: #{cron_string}...")

    options_hash = {
      name: "NOP Script Test",
      cron: cron_string,
      class: 'Kipangaratiba::ShellWorker' ,
      args: ["bash ~/bin/nop_test.sh 'Scheduled cron (3 min)' "]  # <-- activity_args passed to ShellWorker#perform
    }
    schedule_cron_job(options_hash) # Calls wrapper   )
  end

  # ------------------------------------------------------------
  # --- BUSINESS LOGIC METHODS (Loading Schedule) ---
  # ------------------------------------------------------------

  #  ------------------------------------------------------------
  #  schedule_a_meeting -- translates a meeting hash into a cron job
  #  meeting_hash [Hash] -- a single meeting definition from YAML
  #  ------------------------------------------------------------
  def schedule_a_meeting(meeting_hash)
    # Get meeting details
    meeting_name = meeting_hash['meeting']
    week_day_str = meeting_hash['week_day']&.downcase
    start_time   = meeting_hash['start_time']
    stop_time    = meeting_hash['stop_time'] # Will be nil if not present

    # Translate day_of_week, with default
    day_of_week = DAY_OF_WEEK_MAP[week_day_str]
    day_name_for_job = ''

    if day_of_week.nil?
      Environ.log_warn("KipangaScheduler: Invalid day '#{week_day_str}'. Defaulting to Monday.")
      day_of_week = DAY_OF_WEEK_MAP['monday'] # Default to 1
      day_name_for_job = 'Monday'
    else
      day_name_for_job = week_day_str.capitalize
    end

    # Create the START Job ---
    _build_and_schedule(
      meeting_name,
      'Start',
      start_time,
      day_of_week,
      day_name_for_job
    )

    # Create the STOP Job ---
    _build_and_schedule(
      meeting_name,
      'Stop',
      stop_time,
      day_of_week,
      day_name_for_job
    )
  end # schedule_a_meeting


  #  ------------------------------------------------------------
  #  schedule_a_one_off_meeting -- schedules a single one-off job
  #  meeting_hash [Hash] -- a single one-off meeting from YAML
  #  ------------------------------------------------------------
  def schedule_a_one_off_meeting(meeting_hash)
    meeting_name = meeting_hash['meeting']
    meeting_date = meeting_hash['meeting_date']
    start_time   = meeting_hash['start_time']
    stop_time    = meeting_hash['stop_time']

    # Schedule START Job ---
    _build_and_schedule_one_off(
      meeting_name,
      'Start',
      meeting_date,
      start_time
    )

    # Schedule STOP Job ---
    _build_and_schedule_one_off(
      meeting_name,
      'Stop',
      meeting_date,
      stop_time
    )
  end

  #  ------------------------------------------------------------
  #  schedule_cron_process -- schedules a single generic cron job
  #  process_hash [Hash] -- a single process definition from YAML
  #  ------------------------------------------------------------
  def schedule_cron_process(process_hash)
    # Get process details
    job_name = process_hash['name']
    cron_str = process_hash['cron']
    command  = process_hash['command']

    # Check for required fields
    if [job_name, cron_str, command].any? { |v| v.nil? || v.empty? }
      Environ.log_warn("KipangaScheduler: Invalid process job (missing name, cron, or command). Skipping.")
      return
    end

    # Build options hash for the generic wrapper
    options_hash = {
      name:  job_name,
      cron:  cron_str,
      class: 'Kipangaratiba::ShellWorker',
      args:  [command] # Pass the command as the argument
    }

    # Call the generic wrapper
    schedule_cron_job(options_hash)
  end

  #  ------------------------------------------------------------
  #  INSTANCE LEVEL METHODS
  #  ------------------------------------------------------------

  #  ------------------------------------------------------------
  #  load_meeting_schedule_from_yml -- loads schedule from yml; 
  #  optionally resets cron
  #  Expected to be first in the series of loads
  #  file_path [String] -- path to the YAML schedule file
  #  resetcron [Boolean] -- if true, deletes all old cron jobs first
  #  ------------------------------------------------------------
  def load_meeting_schedule_from_yml(file_path, resetcron: true)
    if resetcron
      Sidekiq::Cron::Job.destroy_all!
      Environ.log_info("KipangaScheduler: Cleared all old cron jobs.")
    end

    # Load the schedule
    Environ.log_info("KipangaScheduler: Loading schedule from #{file_path}...")
    begin
      schedule_data = YAML.load_file(file_path)
      schedule_data.each do |meeting_hash|
        KipangaScheduler.schedule_a_meeting(meeting_hash)
      end
    rescue => e
      Environ.log_error("KipangaScheduler: FAILED to load schedule: #{e.message}")
    end

  end

  #  ------------------------------------------------------------
  #  load_oneoff_schedule_from_yml -- loads one-off meetings
  #  file_path [String] -- path to the YAML schedule file
  #  ------------------------------------------------------------
  def load_oneoff_schedule_from_yml(file_path)
    Environ.log_info("KipangaScheduler: Loading one-off schedule: #{file_path}...")
    begin
      schedule_data = YAML.load_file(file_path)
      schedule_data.each do |meeting_hash|
        KipangaScheduler.schedule_a_one_off_meeting(meeting_hash) 
      end
    rescue => e
      Environ.log_error("KipangaScheduler: FAILED to load one-off schedule: #{e.message}")
    end
  end

  #  ------------------------------------------------------------
  #  load_oneoff_processes_from_yml -- loads generic cron processes
  #  file_path [String] -- path to the YAML schedule file
  #  ------------------------------------------------------------
  def load_oneoff_processes_from_yml(file_path)
    Environ.log_info("KipangaScheduler: Loading process schedule: #{file_path}...")
    begin
      schedule_data = YAML.load_file(file_path)
      schedule_data.each do |process_hash|
        KipangaScheduler.schedule_cron_process(process_hash)
      end
    rescue => e
      Environ.log_error("KipangaScheduler: FAILED to load process schedule: #{e.message}")
    end
  end

  #  ------------------------------------------------------------
  #  ------------------------------------------------------------

  #  ------------------------------------------------------------
  #  load_schedule_from_yml -- Generic YAML loader and item processor
  #  file_path [String] -- path to the YAML file
  #  log_name [String] -- friendly name for logging
  #  translator_method [Symbol] -- instance method to call for each item
  #  ------------------------------------------------------------
  def load_schedule_from_yml(file_path:, log_name:, translator_method:)
    Environ.log_info("KipangaScheduler: Loading #{log_name}: #{file_path}...")
    
    unless File.exist?(file_path)
      Environ.log_warn("KipangaScheduler: File not found, skipping: #{file_path}")
      return
    end
    
    begin
      schedule_data = YAML.load_file(file_path)
      
      # Ensure data is an array; do nothing if file is empty
      unless schedule_data.is_a?(Array)
        Environ.log_info("KipangaScheduler: No items to load from #{file_path}.")
        return
      end

      schedule_data.each do |item_hash|
        # Use 'send' to call the translator method by its symbol name
        send(translator_method, item_hash)
      end
    rescue => e
      Environ.log_error("KipangaScheduler: FAILED to load #{log_name}: #{e.message}")
    end
  end

  #  ------------------------------------------------------------
  #  ------------------------------------------------------------

private

    #  ------------------------------------------------------------
    #  ------------------------------------------------------------
    #  PRIVATE CLASS METHODS
    #  ------------------------------------------------------------
    #  ------------------------------------------------------------
    #  _build_and_schedule -- helper to build and schedule a single job
    #  (Skips if time_str is nil or empty)
    #  meeting_name [String] -- name of the meeting
    #  job_type [String] -- 'Start' or 'Stop'
    #  time_str [String] -- 'HH:MM'
    #  day_of_week [Integer] -- 0-6
    #  day_name [String] -- 'Monday'
    #  ------------------------------------------------------------
    def _build_and_schedule(meeting_name, job_type, time_str, day_of_week, day_name)
      
      # Check if the time is provided before proceeding
      if time_str && !time_str.to_s.empty?
        # Parse time
        hour, min = time_str.to_s.split(':').map(&:to_i)
        
        # Build cron string
        cron_string = "#{min} #{hour} * * #{day_of_week}"
        
        # Build command string based on type
        command_string = ""

        if job_type == 'Start'
          # START_SCRIPT_TEMPLATE requires string formatting
          command_string = sprintf(
            Environ::START_SCRIPT_TEMPLATE,
            meeting_name: meeting_name
          )
        else # 'Stop'
          # STOP_SCRIPT_TEMPLATE is a static string
          command_string = Environ::STOP_SCRIPT_TEMPLATE
        end   # fi..else start/stop check

        # Build job name
        job_name = "#{meeting_name} (#{job_type} - #{day_name})"
        
        # Build options hash
        options_hash = {
          name:  job_name,
          cron:  cron_string,
          class: 'Kipangaratiba::ShellWorker',
          args:  [command_string]
        }
        
        # Call the generic wrapper
        schedule_cron_job(options_hash)

      else  # missing/empty time_str; gracefully ignore & log it
        # Log that we are intentionally skipping this job
        Environ.log_info("KipangaScheduler: No '#{job_type}' time for '#{meeting_name}'. Skipping.")
      end  # fi..else.. missing time_str

    end   # def _build_and_schedule

    #  ------------------------------------------------------------
    #  _build_and_schedule_one_off -- helper to schedule a one-off job
    #  (Skips if time_str is nil or empty)
    #  meeting_name [String] -- name of the meeting
    #  job_type [String] -- 'Start' or 'Stop'
    #  date_str [String] -- 'YYYY-MM-DD'
    #  time_str [String] -- 'HH:MM'
    #  ------------------------------------------------------------
    def _build_and_schedule_one_off(meeting_name, job_type, date_str, time_str)
      
      # Check if all required components are present
      if time_str && !time_str.to_s.empty? && date_str && !date_str.to_s.empty?
        begin
          # Combine date and time, then parse
          datetime_str = "#{date_str} #{time_str}"
          datetime_obj = Time.parse(datetime_str)

          # Build command string based on type
          command_string = ""
          if job_type == 'Start'
            command_string = sprintf(
              Environ::START_SCRIPT_TEMPLATE,
              meeting_name: meeting_name
            )
          else # 'Stop'
            command_string = Environ::STOP_SCRIPT_TEMPLATE
          end

          # Schedule the job
          schedule_job_at(datetime_obj, command_string)
        
        rescue => e
          Environ.log_error("KipangaScheduler: Failed to schedule one-off #{job_type} for '#{meeting_name}': #{e.message}")
        end
      else
        # Log that we are intentionally skipping this job
        Environ.log_info("KipangaScheduler: No one-off '#{job_type}' time/date for '#{meeting_name}'. Skipping.")
      end
    end

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
  #  ------------------------------------------------------------
  #  ------------------------------------------------------------


end  # Class KipangaScheduler

end  # module Kipangaratiba

