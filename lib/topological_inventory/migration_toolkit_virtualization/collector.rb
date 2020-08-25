require "topological_inventory/migration_toolkit_virtualization/logging"
require "topological_inventory/providers/common/collector"
require "topological_inventory/migration_toolkit_virtualization/connection_manager"
require "topological_inventory/migration_toolkit_virtualization/parser"
require "topological_inventory/migration_toolkit_virtualization/iterator"

module TopologicalInventory::MigrationToolkitVirtualization
  class Collector < TopologicalInventory::Providers::Common::Collector
    include Logging

    require "topological_inventory/migration_toolkit_virtualization/collector/service_catalog"
    include TopologicalInventory::MigrationToolkitVirtualization::Collector::ServiceCatalog

    def initialize(source, tower_hostname, tower_user, tower_passwd, metrics,
                   poll_time: 60, standalone_mode: true)
      super(source, :poll_time => poll_time, :standalone_mode => standalone_mode)

      self.connection_manager = TopologicalInventory::MigrationToolkitVirtualization::ConnectionManager.new(source)
      self.tower_hostname     = tower_hostname
      self.tower_user         = tower_user
      self.tower_passwd       = tower_passwd
      self.metrics            = metrics
    end

    def collect!
      until finished?
        ensure_collector_threads

        collector_threads.each_value do |thread|
          thread.join
        end

        standalone_mode ? sleep(poll_time) : stop
      end
    end

    private

    attr_accessor :connection_manager, :tower_hostname, :tower_user, :tower_passwd,
                  :metrics

    def endpoint_types
      %w[service_catalog]
    end

    def service_catalog_entity_types
      %w[service_inventories
         service_offerings
         service_instances
         service_offering_nodes
         service_instance_nodes
         service_credentials
         service_credential_types]
    end

    # Connection to endpoint (for each entity type the same)
    def connection_for_entity_type(_entity_type)
      connection_manager.connect(:base_url => tower_hostname, :username => tower_user, :password => tower_passwd)
    end

    # Thread's main for collecting one entity type's data
    def collector_thread(connection, entity_type)
      refresh_state_uuid, refresh_state_started_at, refresh_state_part_collected_at = SecureRandom.uuid, Time.now.utc, nil

      logger.collecting(:start, source, entity_type, refresh_state_uuid)
      parser = TopologicalInventory::MigrationToolkitVirtualization::Parser.new(tower_url: tower_hostname)

      cnt, sweep_scope, total_parts = 0, Set.new, 0
      # each on migration_toolkit_virtualization_client's enumeration makes pagination requests by itself
      send("get_#{entity_type}", connection).each do |entity|
        refresh_state_part_collected_at = Time.now.utc
        cnt += 1

        parser.send("parse_#{entity_type.singularize}", entity)

        if cnt >= limits[entity_type]
          total_parts += 1
          refresh_state_part_uuid = SecureRandom.uuid
          save_inventory(parser.collections.values, inventory_name, schema_name, refresh_state_uuid, refresh_state_part_uuid, refresh_state_part_collected_at)
          sweep_scope.merge(parser.collections.values.map(&:name))
          # re-init
          parser = TopologicalInventory::MigrationToolkitVirtualization::Parser.new(tower_url: tower_hostname)
          cnt = 0
        end
      end

      if parser.collections.values.present?
        total_parts += 1
        refresh_state_part_uuid = SecureRandom.uuid
        save_inventory(parser.collections.values, inventory_name, schema_name, refresh_state_uuid, refresh_state_part_uuid, refresh_state_part_collected_at)
        sweep_scope.merge(parser.collections.values.map(&:name))
      end
      logger.collecting(:finish, source, entity_type, refresh_state_uuid, total_parts)

      # Sweeping inactive records
      sweep_scope = sweep_scope.to_a
      logger.sweeping(:start, source, sweep_scope, refresh_state_uuid)
      sweep_inventory(inventory_name, schema_name, refresh_state_uuid, total_parts, sweep_scope, refresh_state_started_at)
      logger.sweeping(:finish, source, sweep_scope, refresh_state_uuid)
    rescue => e
      metrics.record_error
      logger.collecting_error(source, entity_type, refresh_state_uuid, e)
    end

    def inventory_name
      "MigrationToolkitVirtualization"
    end
  end
end
