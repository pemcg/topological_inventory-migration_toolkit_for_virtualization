require "topological_inventory/migration_toolkit_virtualization/logging"
require "topological_inventory/migration_toolkit_virtualization/connection"
require "topological_inventory/migration_toolkit_virtualization/operations/core/sources_api_client"
require "topological_inventory/migration_toolkit_virtualization/operations/core/topology_api_client"

module TopologicalInventory
  module MigrationToolkitVirtualization
    module Operations
      module Core
        class MigrationToolkitVirtualizationClient
          include Logging
          include Core::TopologyApiClient

          attr_accessor :connection_manager

          def initialize(source_id, task_id, identity = nil)
            self.identity   = identity
            self.source_id  = source_id
            self.task_id    = task_id

            self.connection_manager = TopologicalInventory::MigrationToolkitVirtualization::Connection.new
          end

          # Format of order params (Input for Catalog - created by Collector, Output is produced by catalog - input of this worker)
          #
          # @example:
          #
          # * Input (ServicePlan.create_json_schema field)(created by lib/topological_inventory/migration_toolkit_virtualization/parser/service_plan.rb)
          #     {"schema":
          #       {"fields":[
          #         {"name":"providerControlParameters", ... },
          #         {"name":"NAMESPACE", "type":"text", ...},
          #         {"name":"MEMORY_LIMIT","type":"text","default":"512Mi","isRequired":true,...},
          #         {"name":"POSTGRESQL_USER",type":"text",...},
          #         ...
          #        ]
          #       },
          #      "defaultValues":{"NAMESPACE":"openshift","MEMORY_LIMIT":"512Mi","POSTGRESQL_USER":"","VOLUME_CAPACITY":"...}
          #     }
          #
          # * Output (== @param **order_params**):
          #
          #     { "NAMESPACE":"openshift",
          #       "MEMORY_LIMIT":"512Mi",
          #       "POSTGRESQL_USER":"",
          #       "providerControlParameters":{"namespace":"default"},
          #       ...
          #     }"
          def order_service(job_type, job_template_id, order_params)
            job_template = if job_type == 'workflow_job_template'
                             migration_toolkit_virtualization.api.workflow_job_templates.find(job_template_id)
                           else
                             migration_toolkit_virtualization.api.job_templates.find(job_template_id)
                           end

            job = job_template.launch(job_values(order_params))

            # This means that api_client:job_template.launch() called job.find(nil), which returns list of jobs
            # => status error was returned, but api_client doesn't return errors
            raise ::MigrationToolkitVirtualizationClient::ResourceNotFoundError, "Job not found" if job.respond_to?(:count)

            job
          end

          def self.job_status_to_task_status(job_status)
            case job_status
            when 'error', 'failed' then 'error'
            else 'ok'
            end
          end

          def job_status_to_task_status(job_status)
            self.class.job_status_to_task_status(job_status)
          end

          # Ansible Tower's URL to Job/Workflow
          def self.job_external_url(job, tower_base_url)
            path = job.type == 'workflow_job' ? 'workflows' : 'jobs/playbook'
            File.join(tower_url(tower_base_url), "/#/#{path}", job.id.to_s)
          end

          def job_external_url(job)
            tower_host = [default_endpoint.scheme, default_endpoint.host].join('://')
            self.class.job_external_url(job, tower_host)
          end

          def self.tower_url(hostname)
            if hostname.to_s.index('http').nil?
              File.join('https://', hostname)
            else
              hostname
            end
          end

          private

          attr_accessor :identity, :task_id, :source_id

          def job_values(order_parameters)
            if order_parameters["service_parameters"].blank?
              {}
            else
              { :extra_vars => order_parameters["service_parameters"] }
            end
          end

          def sources_api
            @sources_api ||= Core::SourcesApiClient.new(identity)
          end

          def default_endpoint
            @default_endpoint ||= sources_api.fetch_default_endpoint(source_id)
          end

          def authentication
            @authentication ||= sources_api.fetch_authentication(source_id, default_endpoint)
          end

          def verify_ssl_mode
            default_endpoint.verify_ssl ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
          end

          def migration_toolkit_virtualization
            @migration_toolkit_virtualization ||= connection_manager.connect(
              default_endpoint.host, authentication.username, authentication.password, :verify_ssl => verify_ssl_mode
            )
          end
        end
      end
    end
  end
end
