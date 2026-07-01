require "thor"

module Noop::Backup
  class CLI < Thor
    def self.exit_on_failure? = true

    desc "backup", "Create and store a new backup"
    def backup
      puts "hola!"
    end
  end
end
