# Data zgłoszenia = created_at wniosku w NETPAR (chwila przyjęcia, zegar NETPAR) – ta sama w obu systemach; nowe
# zgłoszenia ustawia ProposalSubmission (z odpowiedzi NETPAR). Wcześniej pokazywaliśmy created_at, czyli rozpoczęcie
# szkicu w kreatorze – istniejącym wysłanym zgłoszeniom zostawiamy tę datę (jak dotąd). Szkice i przerwane wysyłki
# (required_push_to_netpar) – puste do chwili wysłania. Kolumna tylko dodawana (wspólna baza z poprzednią wersją aplikacji).
class AddSubmittedAtToProposals < ActiveRecord::Migration[8.1]
  def up
    add_column :proposals, :submitted_at, :datetime
    execute "UPDATE proposals SET submitted_at = created_at WHERE status = 'saved_in_netpar'"
  end

  def down
    remove_column :proposals, :submitted_at
  end
end
