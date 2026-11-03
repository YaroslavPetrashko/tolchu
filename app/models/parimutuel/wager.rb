module Parimutuel
  # Plain value object so settlement math never touches ActiveRecord.
  Wager = Data.define(:id, :outcome_id, :stake)
end
