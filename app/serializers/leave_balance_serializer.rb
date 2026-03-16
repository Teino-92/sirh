# frozen_string_literal: true

class LeaveBalanceSerializer
  def initialize(balance)
    @balance = balance
  end

  def as_json
    {
      id:                @balance.id,
      leave_type:        @balance.leave_type,
      leave_type_name:   LeaveBalance.leave_type_name(@balance.leave_type),
      balance:           @balance.balance,
      used_this_year:    @balance.used_this_year,
      accrued_this_year: @balance.accrued_this_year,
      expires_at:        @balance.expires_at,
      expiring_soon:     @balance.expiring_soon?
    }
  end
end
