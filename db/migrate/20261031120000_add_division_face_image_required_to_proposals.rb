# Wymóg zdjęcia – z NETPAR (divisions.face_image_required, „Wymagane zdjęcie” na ekranie rodzaju), zapisywany
# przy „Dalej” na zakładce 1 jak division_min_years_old. Wcześniej na sztywno: zdjęcie dla służby M.
# Kolumna tylko dodawana (wspólna baza z poprzednią wersją aplikacji – ona jej nie używa).
class AddDivisionFaceImageRequiredToProposals < ActiveRecord::Migration[8.1]
  def up
    add_column :proposals, :division_face_image_required, :boolean, default: false, null: false
    # Istniejące zgłoszenia – jak dotychczasowa reguła (w NETPAR zdjęcie wymagane dla rodzajów M).
    execute "UPDATE proposals SET division_face_image_required = TRUE WHERE category = 'M'"
  end

  def down
    remove_column :proposals, :division_face_image_required
  end
end
