# frozen_string_literal: true

module Discourse
  VERSION_REGEXP = /\A\d+\.\d+\.\d+(\.beta\d+)?\z/ unless defined? ::Discourse::VERSION_REGEXP

  VERSION_COMPATIBILITY_FILENAME = ".discourse-compatibility"

  # work around reloader
  unless defined? ::Discourse::VERSION
    module VERSION #:nodoc:
      MAJOR = 2
      MINOR = 5
      TINY  = 5
      PRE   = nil

      STRING = [MAJOR, MINOR, TINY, PRE].compact.join('.')
    end
  end

  def self.has_needed_version?(current, needed)
    Gem::Version.new(current) >= Gem::Version.new(needed)
  end

  # lookup an external resource (theme/plugin)'s best compatible version
  # compatible resource files are YAML, in the format:
  # `discourse_version: plugin/theme git reference.` For example:
  #  2.5.0.beta6: c4a6c17
  #  2.5.0.beta4: d1d2d3f
  #  2.5.0.beta2: bbffee
  #  2.4.4.beta6: some-other-branch-ref
  #  2.4.2.beta1: v1-tag
  def self.find_compatible_resource(version_list)

    return unless version_list

    version_list = YAML.load(version_list).sort_by { |version, pin| Gem::Version.new(version) }.reverse

    # If plugin compat version is listed as less than current Discourse version, take the version/hash listed before.
    checkout_version = nil
    version_list.each do |core_compat, target|
      if Gem::Version.new(core_compat) == Gem::Version.new(::Discourse::VERSION::STRING) # Exact version match - return it
        checkout_version = target
        break
      elsif Gem::Version.new(core_compat) < Gem::Version.new(::Discourse::VERSION::STRING) # Core is on a higher version than listed, use a later version
        break
      end
      checkout_version = target
    end

    checkout_version
  end

  # Find a compatible resource from a git repo
  def self.find_compatible_git_resource(path)
    return unless File.directory?("#{path}/.git")
    compat_resource, std_error, s = Open3.capture3("git -C '#{path}' show HEAD@{upstream}:#{Discourse::VERSION_COMPATIBILITY_FILENAME}")
    Discourse.find_compatible_resource(compat_resource) if s.success?
  end
end
