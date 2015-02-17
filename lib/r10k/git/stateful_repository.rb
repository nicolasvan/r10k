require 'r10k/git/thin_repository'
require 'forwardable'

# Manage how Git repositories are created and set to specific refs
class R10K::Git::StatefulRepository

  # @!attribute [r] repo
  #   @api private
  attr_reader :repo

  extend Forwardable
  def_delegators :@repo, :head

  # Create a new shallow git working directory
  #
  # @param ref     [String] The git ref to check out
  # @param remote  [String] The git remote to use for the repo
  # @param basedir [String] The path containing the Git repo
  # @param dirname [String] The directory name of the Git repo
  def initialize(ref, remote, basedir, dirname)
    @ref = ref
    @remote = remote

    @repo = R10K::Git::ThinRepository.new(basedir, dirname)
    @cache = R10K::Git::Cache.generate(remote)
  end

  def sync
    @cache.sync

    sha = @cache.resolve(@ref)

    case status
    when :absent
      @repo.clone(@remote, {:ref => sha})
    when :mismatched
      @repo.path.rmtree
      @repo.clone(@remote, {:ref => sha})
    when :outdated
      @repo.fetch
      @repo.checkout(sha)
    end
  end

  def status
    if !@repo.exist?
      :absent
    elsif !@repo.git_dir.exist?
      :mismatched
    elsif !(@repo.origin == @remote)
      :mismatched
    elsif !(@repo.head == @cache.resolve(@ref))
      :outdated
    else
      :insync
    end
  end
end
