require "openssl"
require "migration_toolkit_virtualization_client"

module TopologicalInventory::MigrationToolkitVirtualization
  class Connection
    include Logging

    def connect(base_url, username, password, verify_ssl: ::OpenSSL::SSL::VERIFY_NONE, open_timeout: 10)
      MigrationToolkitVirtualizationClient.logger = self.logger
      MigrationToolkitVirtualizationClient::Connection.new(
        :base_url   => api_url(base_url),
        :username   => username,
        :password   => password,
        :verify_ssl => verify_ssl,
        :request    => {:open_timeout => open_timeout}
      )
    end

    def api_url(base_url)
      base_url = "https://#{base_url}" unless base_url =~ %r{\Ahttps?:\/\/} # HACK: URI can't properly parse a URL with no scheme
      uri      = URI(base_url)
      uri.path = default_api_path if uri.path.blank?
      uri.to_s
    end

    private

    def default_api_path
      "/api/v2".freeze
    end
  end
end
