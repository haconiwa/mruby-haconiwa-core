module Haconiwa
  class Base
    attr_accessor :name,
                  :init_command,
                  :container_pid_file,
                  :filesystem,
                  :cgroup,
                  :namespace,
                  :capabilities,
                  :attached_capabilities

    def self.define(&b)
      base = new
      b.call(base)
      base
    end

    def initialize
      @filesystem = Filesystem.new
      @cgroup = CGroup.new
      @namespace = Namespace.new
      @capabilities = Capabilities.new
      @attached_capabilities = nil
      @name = "haconiwa-#{Time.now.to_i}"
      @init_command = "/bin/bash" # FIXME: maybe /sbin/init is better
      @container_pid_file = nil
      @pid = nil
    end

    # aliases
    def chroot_to(dest)
      self.filesystem.chroot = dest
    end

    def add_mount_point(point, options)
      self.namespace.unshare "mount"
      self.filesystem.mount_points << MountPoint.new(point, options)
    end

    def mount_independent_procfs
      self.namespace.unshare "mount"
      self.filesystem.mount_independent_procfs = true
    end

    def start(*init_command)
      self.container_pid_file ||= default_container_pid_file
      LinuxRunner.new(self).run(init_command)
    end
    alias run start

    # XXX: not yet
    def attach(*run_command)
      self.container_pid_file ||= default_container_pid_file
      LinuxRunner.new(self).attach(run_command)
    end

    def default_container_pid_file
      "/var/run/haconiwa-#{@name}.pid"
    end
  end

  class CGroup
    def initialize
      @groups = {}
    end
    attr_reader :groups

    def [](key)
      @groups[key]
    end

    def []=(key, value)
      @groups[key] = value
    end

    def to_dirs
      groups.keys.map{|k| k.split('.').first }.uniq
    end
    alias dirs to_dirs
  end

  class Capabilities
    def initialize
      @blacklist = []
      @whitelist = []
    end

    def allow(*keys)
      if keys.first == :all
        @whitelist.clear
      else
        @whitelist.concat(keys)
      end
    end

    def whitelist_ids
      @whitelist.map{|n| ::Capability.from_name(n) }
    end

    def blacklist_ids
      @blacklist.map{|n| ::Capability.from_name(n) }
    end

    def drop(*keys)
      @blacklist.concat(keys)
    end

    def acts_as_whitelist?
      ! @whitelist.empty?
    end
  end

  class Namespace
    NS_MAPPINGS = {
      "ipc"    => ::Namespace::CLONE_NEWIPC,
      "net"    => ::Namespace::CLONE_NEWNET,
      "mount"  => ::Namespace::CLONE_NEWNS,
      "pid"    => ::Namespace::CLONE_NEWPID,
      "user"   => ::Namespace::CLONE_NEWUSER,
      "uts"    => ::Namespace::CLONE_NEWUTS,
    }

    def initialize
      @use_ns = []
      @netns_name = nil
    end

    def unshare(ns)
      flag = case ns
             when String, Symbol
               NS_MAPPINGS[ns.to_s]
             when Integer
               ns
             end
      if flag == ::Namespace::CLONE_NEWPID
        @use_pid_ns = true
      else
        @use_ns << flag
      end
    end
    attr_reader :use_pid_ns

    def use_netns(name)
      @netns_name = name
    end

    def use_ns_all
      @use_ns.uniq + (@use_pid_ns ? [::Namespace::CLONE_NEWPID] : [])
    end

    def to_ns_flag
      @use_ns.inject(0x00000000) { |dst, flag|
        dst |= flag
      }
    end
  end

  class Filesystem
    def initialize
      @mount_points = []
      @mount_independent_procfs = false
    end
    attr_accessor :chroot, :mount_points,
                  :mount_independent_procfs
  end

  class MountPoint
    def initialize(point, options)
      @src = point
      @dest = options.delete(:to)
      @readonly = options.delete(:readonly)
      @fs = options.delete(:fs)
      @options = options
    end
    attr_accessor :src, :dest, :fs
  end

  def self.define(&b)
    Base.define(&b)
  end
end
