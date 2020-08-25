require "topological_inventory/migration_toolkit_virtualization/logging"
require "topological_inventory/providers/common/operations/source"
require "topological_inventory/migration_toolkit_virtualization/connection"

module TopologicalInventory
  module MigrationToolkitVirtualization
    module Operations
      class Source < TopologicalInventory::Providers::Common::Operations::Source
        include Logging

        private

        def connection_check
          connection = ::TopologicalInventory::MigrationToolkitVirtualization::Connection.new
          connection = connection.connect(full_hostname(endpoint), authentication.username, authentication.password)
          connection.api.version

          [STATUS_AVAILABLE, nil]
        rescue => e
          logger.availability_check("Failed to connect to Source id:#{source_id} - #{e.message}", :error)
          [STATUS_UNAVAILABLE, e.message]
        end

        def full_hostname(endpoint)
          endpoint.host.tap { |host| host << ":#{endpoint.port}" if endpoint.port }
        end
      end
    end
  end
end
