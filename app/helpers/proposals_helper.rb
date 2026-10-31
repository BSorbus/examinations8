module ProposalsHelper
  # Zakładka 1, podpowiedź: co wybrano w innym niedokończonym zgłoszeniu.
  def other_draft_choice(draft)
    return t("proposals.wizard.step1.other_draft_no_category") if draft.category.blank?

    [ draft.category_name, draft.division_short_name.presence || t("proposals.wizard.step1.other_draft_no_division") ].join(" – ")
  end
end
