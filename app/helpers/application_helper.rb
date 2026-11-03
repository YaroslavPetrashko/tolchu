module ApplicationHelper
  PHASE_LABELS = { open: "Live", locked: "Locked", resolved: "Settled", cancelled: "Cancelled" }.freeze

  # 1 credit / 1,250 credits
  def credits(amount)
    "#{amount.to_i.to_fs(:delimited)} #{amount.to_i.abs == 1 ? 'credit' : 'credits'}"
  end

  # +126 / −50 / 0, for wallet activity and bet results
  def signed_credits(amount)
    return "0" if amount.to_i.zero?

    sign = amount.positive? ? "+" : "−"
    "#{sign}#{amount.abs.to_fs(:delimited)}"
  end

  # ×1.90, or an em dash when nobody has backed the outcome yet
  def multiplier(value)
    value ? "×#{format('%.2f', value.to_f)}" : "—"
  end

  def percent(fraction)
    "#{(fraction.to_f * 100).round}%"
  end

  def phase_label(market)
    PHASE_LABELS.fetch(market.phase)
  end

  def phase_badge(market)
    tag.span(phase_label(market), class: [ "badge", "badge--#{market.phase}" ])
  end

  def lock_status_text(market, now: Time.current)
    case market.phase(now)
    when :open then "Locks in #{distance_of_time_in_words(now, market.locks_at)}"
    when :locked then "Betting closed. Waiting for the result"
    when :resolved then "Result is in"
    when :cancelled then "Cancelled. Stakes refunded"
    end
  end

  def bet_status_label(bet)
    case bet.status.to_sym
    when :pending then "Pending"
    when :won then "Won #{signed_credits(bet.net)}"
    when :lost then "Lost #{signed_credits(bet.net)}"
    when :refunded then "Refunded"
    end
  end
end
