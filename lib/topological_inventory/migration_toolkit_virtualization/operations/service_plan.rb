require "topological_inventory-api-client"
require "topological_inventory/migration_toolkit_virtualization/operations/core/migration_toolkit_virtualization_client"
require "topological_inventory/migration_toolkit_virtualization/operations/core/service_order_mixin"
require "topological_inventory/migration_toolkit_virtualization/operations/core/topology_api_client"

module TopologicalInventory
  module MigrationToolkitVirtualization
    module Operations
      class ServicePlan
        include Logging
        include Core::TopologyApiClient
        include Core::ServiceOrderMixin

        attr_accessor :params, :identity

        def initialize(params = {}, identity = nil)
          @params   = params
          @identity = identity
        end
      end
    end
  end
end
