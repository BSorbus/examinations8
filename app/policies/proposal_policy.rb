class ProposalPolicy < ApplicationPolicy
  def index? = can?("proposal:index") || can?("proposal:index_self")

  def create? = can?("proposal:create_self")

  def show? = own? && can?("proposal:show_self")

  # Kreator: tylko własne, jeszcze niewysłane zgłoszenie.
  def edit? = own? && !record.submitted? && can?("proposal:create_self")

  def destroy? = edit? && can?("proposal:delete_self")

  def annul? = own? && record.can_annul? && can?("proposal:update_self")

  def correction_exam? = own? && record.can_correction_exam? && can?("proposal:create_self")

  def testportal? = own? && record.can_take_tests? && can?("proposal:show_self")

  private
    def own? = record.creator_id == user&.id

  class Scope < Scope
    def resolve
      if can?("proposal:index")
        scope.submitted
      elsif can?("proposal:index_self")
        scope.submitted.where(creator_id: user.id)
      else
        scope.none
      end
    end
  end
end
