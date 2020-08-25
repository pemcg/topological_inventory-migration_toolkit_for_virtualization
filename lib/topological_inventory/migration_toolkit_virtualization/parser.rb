require "topological_inventory/migration_toolkit_virtualization/operations/core/migration_toolkit_virtualization_client"

module TopologicalInventory::MigrationToolkitVirtualization
  class Parser < TopologicalInventory::Providers::Common::Collector::Parser
    require "topological_inventory/migration_toolkit_virtualization/parser/service_credential"
    require "topological_inventory/migration_toolkit_virtualization/parser/service_instance"
    require "topological_inventory/migration_toolkit_virtualization/parser/service_instance_node"
    require "topological_inventory/migration_toolkit_virtualization/parser/service_inventory"
    require "topological_inventory/migration_toolkit_virtualization/parser/service_plan"
    require "topological_inventory/migration_toolkit_virtualization/parser/service_offering"
    require "topological_inventory/migration_toolkit_virtualization/parser/service_offering_node"
    require "topological_inventory/migration_toolkit_virtualization/parser/service_credential_type"

    include TopologicalInventory::MigrationToolkitVirtualization::Parser::ServiceInstance
    include TopologicalInventory::MigrationToolkitVirtualization::Parser::ServiceInstanceNode
    include TopologicalInventory::MigrationToolkitVirtualization::Parser::ServiceInventory
    include TopologicalInventory::MigrationToolkitVirtualization::Parser::ServicePlan
    include TopologicalInventory::MigrationToolkitVirtualization::Parser::ServiceOffering
    include TopologicalInventory::MigrationToolkitVirtualization::Parser::ServiceOfferingNode
    include TopologicalInventory::MigrationToolkitVirtualization::Parser::ServiceCredential
    include TopologicalInventory::MigrationToolkitVirtualization::Parser::ServiceCredentialType

    def initialize(tower_url:)
      super()
      self.tower_url = tower_client_class.tower_url(tower_url)
    end

    def parse_base_item(entity)
      props = { :resource_timestamp => resource_timestamp }
      props[:name]              = entity.name    if entity.respond_to?(:name)
      props[:source_created_at] = entity.created if entity.respond_to?(:created)
      props
    end

    protected

    attr_accessor :tower_url

    def tower_client_class
      TopologicalInventory::MigrationToolkitVirtualization::Operations::Core::MigrationToolkitVirtualizationClient
    end
  end
end
