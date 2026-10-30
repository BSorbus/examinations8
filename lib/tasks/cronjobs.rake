# Zadania uruchamiane z crona (jak w poprzedniej wersji – config/schedule.rb):
#   0 6 * * *   cd <aplikacja> && RAILS_ENV=production bin/rails cronjobs:proposal_clean_unsaved
#   0 10 * * *  cd <aplikacja> && RAILS_ENV=production bin/rails cronjobs:proposal_send_reminders
namespace :cronjobs do
  desc "Usuwa niedokończone zgłoszenia nieruszane od 30 dni"
  task proposal_clean_unsaved: :environment do
    started = Time.current
    count = Proposal.clean_unsaved
    puts "#{started.strftime('%F %T')} proposal_clean_unsaved: usunięto #{count}"
  end

  desc "Wysyła przypomnienia o egzaminie (3 dni przed)"
  task proposal_send_reminders: :environment do
    started = Time.current
    count = Proposal.send_reminders
    puts "#{started.strftime('%F %T')} proposal_send_reminders: wysłano #{count}"
  end
end
