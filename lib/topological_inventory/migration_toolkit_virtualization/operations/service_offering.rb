require "topological_inventory-api-client"
require "topological_inventory/migration_toolkit_virtualization/operations/core/migration_toolkit_virtualization_client"
require "topological_inventory/migration_toolkit_virtualization/operations/core/service_order_mixin"
require "topological_inventory/migration_toolkit_virtualization/operations/core/topology_api_client"
require "topological_inventory/migration_toolkit_virtualization/operations/applied_inventories/parser"

module TopologicalInventory
  module MigrationToolkitVirtualization
    module Operations
      class ServiceOffering
        include Logging
        include Core::TopologyApiClient
        include Core::ServiceOrderMixin

        attr_accessor :params, :identity

        def initialize(params = {}, identity = nil)
          @params   = params
          @identity = identity
        end

        def applied_inventories
          task_id, service_offering_id, service_params = params.values_at("task_id", "service_offering_id", "service_parameters")
          service_params ||= {}

          update_task(task_id, :state => "running", :status => "ok")

          service_offering = topology_api_client.show_service_offering(service_offering_id.to_s)
          prompted_inventory_id = service_params['prompted_inventory_id']

          parser = init_parser(identity, service_offering, prompted_inventory_id)
          inventories = if parser.is_workflow_template?(service_offering)
                          parser.load_workflow_template_inventories
                        else
                          [ parser.load_job_template_inventory ].compact
                        end

          update_task(task_id, :state => "completed", :status => "ok", :context => { :applied_inventories => inventories.map(&:id) })
        rescue StandardError => err
          logger.error("[Task #{task_id}] AppliedInventories error: #{err}\n#{err.backtrace.join("\n")}")
          update_task(task_id, :state => "completed", :status => "error", :context => { :error => err.to_s })
        end

        private

        def init_parser(identity, service_offering, prompted_inventory_id)
          TopologicalInventory::MigrationToolkitVirtualization::Operations::AppliedInventories::Parser.new(identity, service_offering, prompted_inventory_id)
        end
      end
    end
  end
end
