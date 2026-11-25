require "rails_helper"

RSpec.describe EmailDomain do
  mx = Resolv::DNS::Resource::IN::MX
  a = Resolv::DNS::Resource::IN::A
  aaaa = Resolv::DNS::Resource::IN::AAAA

  # Answers lookups for the domain under test from `records`; the canary domain always has a mail server.
  def resolver_with(dns_up: true, **records)
    canary = dns_up ? [ Resolv::DNS::Resource::IN::MX.new(5, Resolv::DNS::Name.create("gmail-smtp-in.l.google.com.")) ] : []
    instance_double(Resolv::DNS).tap do |resolver|
      allow(resolver).to receive(:getresources) do |name, type|
        name == described_class::CANARY ? canary : records.fetch(type, [])
      end
    end
  end

  describe ".from_address" do
    it "takes the part after the last @ and normalizes it" do
      expect(described_class.from_address("Fan@Mail.Example.COM").name).to eq("mail.example.com")
    end
  end

  describe "#disposable?" do
    it "flags listed throwaway services and their subdomains" do
      expect(described_class.new("mailinator.com")).to be_disposable
      expect(described_class.new("inbox.yopmail.com")).to be_disposable
    end

    it "lets ordinary providers through, even ones that merely end the same way" do
      expect(described_class.new("gmail.com")).not_to be_disposable
      expect(described_class.new("notmailinator.com")).not_to be_disposable
    end
  end

  describe "#receives_mail?" do
    it "is true when the domain lists a mail server" do
      resolver = resolver_with(mx => [ mx.new(10, Resolv::DNS::Name.create("mail.school.edu.")) ])
      expect(described_class.new("school.edu", resolver:).receives_mail?).to be(true)
    end

    it "is false when the domain declares that it takes no mail (null MX)" do
      resolver = resolver_with(mx => [ mx.new(0, Resolv::DNS::Name.create(".")) ])
      expect(described_class.new("example.com", resolver:).receives_mail?).to be(false)
    end

    it "falls back to the domain's own address when there is no mail server record" do
      expect(described_class.new("tiny.org", resolver: resolver_with(a => [ a.new("192.0.2.1") ])).receives_mail?).to be(true)
      expect(described_class.new("six.org", resolver: resolver_with(aaaa => [ aaaa.new("2001:db8::1") ])).receives_mail?).to be(true)
    end

    it "is false for a domain that doesn't exist" do
      expect(described_class.new("gmial-typo.invalid", resolver: resolver_with).receives_mail?).to be(false)
    end

    it "lets the address through when DNS is down and every lookup comes back empty" do
      expect(described_class.new("school.edu", resolver: resolver_with(dns_up: false)).receives_mail?).to be(true)
    end

    it "lets the address through when the lookup itself fails" do
      resolver = instance_double(Resolv::DNS)
      allow(resolver).to receive(:getresources).and_raise(Resolv::ResolvTimeout)
      expect(described_class.new("school.edu", resolver:).receives_mail?).to be(true)
    end

    it "builds a real resolver with a short timeout when none is given" do
      dns = resolver_with
      allow(dns).to receive(:timeouts=)
      allow(Resolv::DNS).to receive(:new).and_return(dns)

      expect(described_class.new("nowhere.invalid").receives_mail?).to be(false)
      expect(dns).to have_received(:timeouts=).with(described_class::LOOKUP_TIMEOUT)
    end
  end
end
