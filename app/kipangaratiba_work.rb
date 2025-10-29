# --- kipangaratiba_work.rb ---
# Kipangaratiba: A Remote Elder Monitoring Hub
# Copyright (c) 2025 David S Anderson, All Rights Reserved
#
# ------------------------------------------------------------
# class KipangaratibaWork -- top-level control for doing everything
# accessed either from the CLI controller or the WEB i/f controller
# ------------------------------------------------------------

  require_relative 'environ'
  require_relative 'kipangaratiba_error' # for KipangaratibaError classes
  require_relative 'kipanga_scheduler'  

# +++++++++++++++++++++++++++++++++++++++++++++++++
module Kipangaratiba # Define the top-level module
# +++++++++++++++++++++++++++++++++++++++++++++++++

class KipangaratibaWork

  APPNAME_VERSION = Environ.app_name + " v" + Environ.kipangaratiba_version

  # ------------------------------------------------------------
  # initialize -- creates a new KipangaratibaWork object; inits environ
  # ------------------------------------------------------------
  def initialize()
    @my_env = Environ.instance # @my_env not used; placeholder
  end

  # ------------------------------------------------------------
  # setup_work -- handles initializing kipangaratiba system
  # ------------------------------------------------------------
  def setup_work()
    Environ.log_info("KipangaratibaWork: " + APPNAME_VERSION + ": starting setup...")

    begin
      # Instantiate Singletons here. Their initialize methods will call verify_configuration.
      @my_scheduler = KipangaScheduler.instance
      @my_scheduler.reset_cron_table   # purge all cron entries

      @my_scheduler.load_schedule_from_yml(
        file_path: Environ::MEETING_INITIALIZATION_FILE,
        log_name: "meeting schedule",
        translator_method: :schedule_a_meeting
      )

      @my_scheduler.load_schedule_from_yml(
        file_path: Environ::ONEOFF_MEETING_INITIALIZATION_FILE,
        log_name: "oneoff schedule",
        translator_method: :schedule_a_one_off_meeting
      )

      @my_scheduler.load_schedule_from_yml(
        file_path: Environ::ONEOFF_PROCESS_INITIALIZATION_FILE,
        log_name: "cron procss schedule",
        translator_method: :schedule_cron_process
      )

      Environ.log_info("KipangaratibaWork: All device configurations successful")

      # RESCUE BLOCK =======================================================
    rescue MajorError => e
      Environ.put_and_log_error("KipangaratibaWork: Critical startup error: #{e.message}")
      # Re-raise error to top-level control; prevents application in a broken state
      raise
    rescue => e
      Environ.put_and_log_error("KipangaratibaWork: Unexpected error during setup: #{e.message}")
      raise # Re-raise any other unexpected errors
    end  # rescue block
      # END RESCUE BLOCK ====================================================

  end # setup_work

  # ------------------------------------------------------------
  # shutdown_work -- handles pre-termination stuff
  # ------------------------------------------------------------
  def shutdown_work()
    Environ.log_info("...ending")
  end

  # ------------------------------------------------------------
  # do_status -- displays then returns status
  # ------------------------------------------------------------
  def do_status
    sts = Environ.to_sts
    Environ.put_info ">>>>> status: " + sts
    return sts
  end

  # ------------------------------------------------------------
  # do_flags -- displays then returns flag states
  # args:
  #   list -- cli array, with cmd at top
  # ------------------------------------------------------------
  def do_flags(list)
    list.shift # pop first element, the "f" command
    if (Environ.flags.parse_flags(list))
      Environ.change_log_level(Environ.flags.flag_log_level)
    end

    sts = Environ.flags.to_s
    Environ.put_info ">>>>> flags: " + sts
    return sts
  end

  # ------------------------------------------------------------
  # do_help -- displays then returns help line
  # ------------------------------------------------------------
  def do_help
    sts = Environ.kipangaratiba_help + "\n" + Environ.flags.to_help
    Environ.put_info sts
    return sts
  end

  # ------------------------------------------------------------
  # do_version -- displays then returns kipangaratiba version
  # ------------------------------------------------------------
  def do_version
    Environ.put_info APPNAME_VERSION
    return APPNAME_VERSION
  end

  # ------------------------------------------------------------
  # do_options -- display any options
  # ------------------------------------------------------------
  def do_options
    sts = ">>>>> options "
    Environ.put_info sts
    return sts
  end

  # ------------------------------------------------------------
  # cli & webapp all eventually come in thru here
  # ------------------------------------------------------------

end # class KipangaratibaWork
end  # module Kipangaratiba

