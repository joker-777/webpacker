require "rails/railtie"

require "webpacker/helper"
require "webpacker/dev_server_proxy"

class Webpacker::Engine < ::Rails::Engine
  # Allows Webpacker config values to be set via Rails env config files
  config.webpacker = ActiveSupport::OrderedOptions.new

  initializer "webpacker.proxy" do |app|
    if (Webpacker.config.dev_server.present? rescue nil)
      app.middleware.insert_before 0,
        Rails::VERSION::MAJOR >= 5 ?
          Webpacker::DevServerProxy : "Webpacker::DevServerProxy", ssl_verify_none: true
    end
  end

  initializer "webpacker.helper" do
    ActiveSupport.on_load :action_controller do
      ActionController::Base.helper Webpacker::Helper
    end

    ActiveSupport.on_load :action_view do
      include Webpacker::Helper
    end
  end

  initializer "webpacker.logger" do
    config.after_initialize do
      if ::Rails.logger.respond_to?(:tagged)
        Webpacker.logger = ::Rails.logger
      else
        Webpacker.logger = ActiveSupport::TaggedLogging.new(::Rails.logger)
      end
    end
  end

  initializer "webpacker.bootstrap" do
    if defined?(Rails::Server) || defined?(Rails::Console)
      Webpacker.bootstrap
      if defined?(Spring)
        require "spring/watcher"
        Spring.after_fork { Webpacker.bootstrap }
        Spring.watch(Webpacker.config.config_path)
      end
    end
  end

  initializer "webpacker.set_source" do |app|
    if Webpacker.config.config_path.exist?
      app.config.javascript_path = Webpacker.config.source_path.relative_path_from(Rails.root.join("app")).to_s
    end
  end

  initializer "webpacker.remove_app_packs_from_the_autoload_paths" do
    Rails.application.config.before_initialize do
      source_path = Webpacker.config.source_path.to_s
      ActiveSupport::Dependencies.autoload_paths.delete(source_path)
    end
  end
end
