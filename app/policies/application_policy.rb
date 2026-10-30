# Uprawnienia na podstawie listy activities z ról użytkownika (Role#activities), jak w poprzedniej wersji.
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  private
    def can?(activity) = user.present? && user.activities.include?(activity)

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    private
      attr_reader :user, :scope

      def can?(activity) = user.present? && user.activities.include?(activity)
  end
end
