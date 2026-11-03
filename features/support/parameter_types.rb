# {credits} matches amounts written the way the UI shows them: 50, 1,000, 1,026
ParameterType(
  name: "credits",
  regexp: /\d{1,3}(?:,\d{3})+|\d+/,
  transformer: ->(amount) { amount.delete(",").to_i }
)

# {signed_credits} matches ledger amounts such as +1,000 or -40
ParameterType(
  name: "signed_credits",
  regexp: /[+-](?:\d{1,3}(?:,\d{3})+|\d+)/,
  transformer: ->(amount) { amount.delete(",").to_i }
)

# {page} names the places a user can navigate to (see NavigationHelpers#path_to)
ParameterType(
  name: "page",
  regexp: /the feed|the sign up page|the sign in page|my wallet|my studio|the new market page|the how it works page/,
  transformer: ->(name) { name }
)
