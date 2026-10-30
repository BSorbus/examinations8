require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module Examinations8
  class Application < Rails::Application
    config.load_defaults 8.1

    config.autoload_lib(ignore: %w[assets tasks])

    config.time_zone = "Warsaw"
    # Jak w poprzedniej wersji – aplikacja tylko po polsku.
    config.i18n.available_locales = %i[pl]
    config.i18n.default_locale = :pl

    # Maile wysyłane w tle w procesie aplikacji (jak w poprzedniej wersji) – bez osobnej kolejki i procesu.
    config.active_job.queue_adapter = :async

    config.x.examinations = config_for(:examinations)

    config.generators.system_tests = nil
  end
end
