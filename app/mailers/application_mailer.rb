class ApplicationMailer < ActionMailer::Base
  default from: -> { Rails.configuration.x.examinations.dig(:smtp, :user_name).presence || "egzaminy@uke.gov.pl" },
          bcc: -> { Rails.configuration.x.examinations.dig(:smtp, :bcc).presence }
  layout "mailer"
  helper :mailer
end
