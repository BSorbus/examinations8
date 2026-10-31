# Porządkowanie danych zgłoszeń według ustawień w NETPAR (jednorazowo albo po zmianie ustawień rodzaju):
#   RAILS_ENV=production bin/rails proposals:sync_face_image_required
namespace :proposals do
  desc "Ustawia wymóg zdjęcia (division_face_image_required) we wszystkich zgłoszeniach wg rodzaju w NETPAR"
  task sync_face_image_required: :environment do
    netpar = Netpar::Client.new
    Proposal.where.not(division_id: nil).distinct.order(:division_id).pluck(:division_id).each do |division_id|
      division = netpar.division(division_id)
      next puts("rodzaj #{division_id}: brak w NETPAR – bez zmian") unless division

      required = division["face_image_required"] == true
      changed = Proposal.where(division_id:).where.not(division_face_image_required: required)
                        .update_all(division_face_image_required: required, updated_at: Time.current)
      puts "rodzaj #{division_id} (#{division['category']} #{division['short_name']}): wymagane zdjęcie = #{required ? 'tak' : 'nie'}, zmieniono #{changed}"
    end
    changed = Proposal.where(division_id: nil, division_face_image_required: true).update_all(division_face_image_required: false)
    puts "bez rodzaju: zmieniono #{changed}"
  end
end
