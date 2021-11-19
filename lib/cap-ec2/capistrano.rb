require 'capistrano/configuration'
require 'aws-sdk'
require 'colorize'
require 'terminal-table'
require 'yaml'
require 'net/ssh/proxy/command'
require 'deep_merge'
require_relative 'utils'
require_relative 'ec2-handler'
require_relative 'status-table'

# Load extra tasks
load File.expand_path("../tasks/ec2.rake", __FILE__)

module Capistrano
  module DSL
    module Ec2

      def ec2_handler
        @ec2_handler ||= CapEC2::EC2Handler.new
      end

      def ec2_role(name, options={})
        ec2_handler.get_servers_for_role(name).each do |server|
          env.role(name, CapEC2::Utils.contact_point(server),
                   options_with_instance_id(options, server))
        end
      end

      def ec2_ssm_role(name, options={})
        ec2_handler.get_servers_for_role(name).each do |server|
          env.role(name, CapEC2::Utils.contact_point(server),
                   options_with_ssm(options, server))
        end
      end

      def env
        Configuration.env
      end

      private

      def options_with_instance_id(options, server)
        options.merge({aws_instance_id: server.instance_id})
      end

      def options_with_ssm(options, server)
        options_with_instance_id(options, server).deep_merge!({
          ssh_options: {
            forward_agent: true,
            auth_methods: %w[publickey],
            proxy: Net::SSH::Proxy::Command::new("aws ssm start-session --target #{server.instance_id} --document-name AWS-StartSSHSession --parameters 'portNumber=%p'")
          }
        })
      end

    end
  end
end

self.extend Capistrano::DSL::Ec2

Capistrano::Configuration::Server.send(:include, CapEC2::Utils::Server)
