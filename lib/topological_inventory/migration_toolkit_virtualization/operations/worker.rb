require "manageiq-messaging"
require "topological_inventory/migration_toolkit_virtualization/logging"
require "topological_inventory/migration_toolkit_virtualization/operations/processor"
require "topological_inventory/migration_toolkit_virtualization/operations/source"

module TopologicalInventory
  module MigrationToolkitVirtualization
    module Operations
      class Worker
        include Logging

        def initialize(messaging_client_opts = {})
          self.messaging_client_opts = default_messaging_opts.merge(messaging_client_opts)
        end

        def run
          # Open a connection to the messaging service
          client = ManageIQ::Messaging::Client.open(messaging_client_opts)

          logger.info("Topological Inventory MigrationToolkitVirtualization Operations worker started...")
          client.subscribe_topic(queue_opts) do |message|
            log_with(message.payload&.fetch_path('request_context','x-rh-insights-request-id')) do
              model, method = message.message.to_s.split(".")
              logger.info("Received message #{model}##{method}, #{message.payload}")
              process_message(message)
            end
          end
        rescue => err
          logger.error("#{err.cause}\n#{err.backtrace.join("\n")}")
        ensure
          client&.close
        end

        private

        attr_accessor :messaging_client_opts

        def process_message(message)
          Processor.process!(message)
        rescue StandardError => err
          model, method = message.message.to_s.split(".")
          task_id = message.payload&.fetch_path('params','task_id')
          logger.error("#{model}##{method}: Task(id: #{task_id}) #{err.cause}\n#{err}\n#{err.backtrace.join("\n")}")
          raise
        ensure
          message.ack
        end

        def queue_name
          "platform.topological-inventory.operations-ansible-tower"
        end

        def queue_opts
          {
            :auto_ack    => false,
            :max_bytes   => 50_000,
            :service     => queue_name,
            :persist_ref => "topological-inventory-operations-ansible-tower"
          }
        end

        def default_messaging_opts
          {
            :protocol   => :Kafka,
            :client_ref => "topological-inventory-operations-ansible-tower",
            :group_ref  => "topological-inventory-operations-ansible-tower"
          }
        end
      end
    end
  end
end
