# Wpis historii zgłoszenia (kind + szczegóły w data).
class ProposalEvent < ApplicationRecord
  KINDS = %w[submitted annulled netpar_update mail].freeze

  belongs_to :proposal

  validates :kind, inclusion: { in: KINDS }
end
