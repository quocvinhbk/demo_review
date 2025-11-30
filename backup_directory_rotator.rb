#!/usr/bin/env ruby

# frozen_string_literal: true

require 'pry-byebug'
require 'fileutils'

require_relative 'app_logger'

class BackupDirectoryRotator
  def self.call
    new.call
  end

  def call
    AppLogger.call('@@@@@ Start Rotation')
    dirs = Dir.glob(File.join(backup_path, 'output_*'))
              .select { |path| output_directory?(path) }
    sorted_desc = dirs.sort
    remove_dirs = sorted_desc.drop(number_of_directory_to_keep)
    remove_dirs.each do |dir|
      FileUtils.rm_rf(dir)
      AppLogger.call("Delete directory #{dir}")
    end
    AppLogger.call('@@@@@ Done Rotation')
  end

  private

  def backup_path
    backup_output_path = ENV.fetch('BACKUP_OUTPUT_PATH', File.join(File.dirname(Dir.pwd), 'backups'))
    core_directory = ENV.fetch('CORE_DIRECTORY', File.basename(Dir.pwd))
    base_backup_path = File.join(backup_output_path, core_directory)
    FileUtils.mkdir_p(base_backup_path)
    @backup_path ||= base_backup_path
  end

  def number_of_directory_to_keep
    @number_of_directory_to_keep ||= ENV.fetch('NUMBER_OF_DIRECTORY_TO_KEEP', 15).to_i
  end

  def output_directory?(path)
    File.directory?(path) && File.basename(path) =~ /\Aoutput_\d{8}\z/
  end
end

BackupDirectoryRotator.call
