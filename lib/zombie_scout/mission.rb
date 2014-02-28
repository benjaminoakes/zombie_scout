require 'zombie_scout/ruby_project'
require 'zombie_scout/parser'
require 'zombie_scout/method_call_finder'
require 'zombie_scout/flog_scorer'

module ZombieScout
  class Mission
    attr_reader :defined_method_count

    def initialize(globs)
      @ruby_project = RubyProject.new(*globs)
    end

    def scout
      zombies.map { |zombie|
        { location: zombie.location,
          name: zombie.name,
          flog_score: flog_score(zombie.location)
        }
      }
    end

    def sources
      @sources ||= @ruby_project.ruby_sources
    end

    private

    def flog_score(zombie_location)
      ZombieScout::FlogScorer.new(zombie_location).score
    end

    def zombies
      return @zombies unless @zombies.nil?

      scout!
      @zombies ||= @defined_methods.select { |method|
        might_be_dead?(method)
      }
    end

    def scout!
      @defined_methods, @called_methods = [], []

      sources.each do |ruby_source|
        parser = ZombieScout::Parser.new(ruby_source)
        @defined_methods.concat(parser.defined_methods)
        @called_methods.concat(parser.called_methods)
      end

      @defined_method_count = @defined_methods.size

      @called_methods.uniq!
      @defined_methods.reject! do |method|
        @called_methods.include?(method.name)
      end
    end

    def might_be_dead?(method)
      @method_call_counter ||= MethodCallFinder.new(@ruby_project)
      @method_call_counter.count_calls(method.name) < 2
    end
  end
end
