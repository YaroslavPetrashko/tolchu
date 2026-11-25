require "resolv"

# Answers two questions about the domain of a sign-up email: is it a throwaway inbox
# service, and can it receive mail at all? It can't tell whether the person owns the
# address; only a confirmation email proves that.
class EmailDomain
  DISPOSABLE = Rails.root.join("config/disposable_email_domains.txt").readlines(chomp: true)
                    .map(&:strip).reject { |line| line.empty? || line.start_with?("#") }.to_set.freeze
  LOOKUP_TIMEOUT = 1 # second per lookup
  CANARY = "gmail.com" # always has mail servers; if it looks empty too, DNS is down, not the domain

  attr_reader :name

  def self.from_address(address)
    new(address.to_s.rpartition("@").last)
  end

  def initialize(name, resolver: nil)
    @name = name.to_s.strip.downcase.chomp(".")
    @resolver = resolver
  end

  # True for a listed domain and any subdomain of one (inbox.mailinator.com).
  def disposable?
    labels = name.split(".")
    (0..labels.size - 2).any? { |index| DISPOSABLE.include?(labels[index..].join(".")) }
  end

  # Follows the mail rules: MX records say where mail goes, a "null MX" says the domain
  # takes none, and with no MX at all mail falls back to the domain's own address.
  # If DNS itself is unreachable we let the address through rather than block sign-ups.
  def receives_mail?
    exchanges = records(name, Resolv::DNS::Resource::IN::MX).map { |record| record.exchange.to_s }
    return exchanges.any? { |exchange| exchange.present? && exchange != "." } if exchanges.any?

    records(name, Resolv::DNS::Resource::IN::A).any? || records(name, Resolv::DNS::Resource::IN::AAAA).any? || dns_down?
  rescue Resolv::ResolvError, Timeout::Error, SystemCallError
    true
  end

  private
    def records(domain, type)
      resolver.getresources(domain, type)
    end

    # A lookup that times out returns nothing, exactly like a domain that doesn't exist.
    # A domain we know exists tells the two apart.
    def dns_down?
      records(CANARY, Resolv::DNS::Resource::IN::MX).empty?
    end

    def resolver
      @resolver ||= Resolv::DNS.new.tap { |dns| dns.timeouts = LOOKUP_TIMEOUT }
    end
end
