class ManageIQ::Providers::Redhat::InfraManager::Vm
  module RemoteConsole
    def console_supported?(type)
      %w(SPICE VNC).include?(type.upcase)
    end

    def remote_display
      provider_object.attributes[:display]
    end

    def validate_remote_console_acquire_ticket(protocol, options = {})
      raise(MiqException::RemoteConsoleNotSupportedError,
            "#{protocol} protocol not enabled for this vm") unless protocol.to_sym == :html5

      raise(MiqException::RemoteConsoleNotSupportedError,
            "#{protocol} remote console requires the vm to be registered with a management system.") if ext_management_system.nil?

      options[:check_if_running] = true unless options.key?(:check_if_running)
      raise(MiqException::RemoteConsoleNotSupportedError,
            "#{protocol} remote console requires the vm to be running.") if options[:check_if_running] && state != "on"
    end

    def remote_console_acquire_ticket(userid, console_type)
      # FIXME: a temporary work-around for #8151 (provider_object being an Array)
      provider = provider_object.kind_of?(Array) ? provider_object.first : provider_object

      validate_remote_console_acquire_ticket(console_type)

      parsed_ticket = Nokogiri::XML(provider.ticket)
      display = provider.attributes[:display]

      SystemConsole.where(:vm_id => id).each(&:destroy)
      # TODO: non-blocking SSL support in the proxy
      SystemConsole.create!(
        :user       => User.find_by(:userid => userid),
        :vm_id      => id,
        :host_name  => display[:address],
        :port       => display[:secure_port] || display[:port],
        :ssl        => display[:secure_port].present?,
        :protocol   => display[:type],
        :secret     => parsed_ticket.xpath('action/ticket/value')[0].text,
        :url_secret => SecureRandom.hex
      ).connection_params
    end

    def remote_console_acquire_ticket_queue(protocol, userid)
      task_opts = {
        :action => "acquiring Vm #{name} #{protocol.to_s.upcase} remote console ticket for user #{userid}",
        :userid => userid
      }

      queue_opts = {
        :class_name  => self.class.name,
        :instance_id => id,
        :method_name => 'remote_console_acquire_ticket',
        :priority    => MiqQueue::HIGH_PRIORITY,
        :role        => 'ems_operations',
        :zone        => my_zone,
        :args        => [userid, protocol]
      }

      MiqTask.generic_action_with_callback(task_opts, queue_opts)
    end
  end
end
