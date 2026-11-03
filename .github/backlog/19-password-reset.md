---
title: "Password reset by email"
labels: ["type: feature", "area: auth", "priority: P2 · final demo"]
milestone: "Final demo"
---
## Summary
As a fan who forgot my password, I want to reset it by email so I don't lose my credits and predictions. Today the only fix is a teammate editing the production database, which won't scale to real-user testing.

## Context
- Auth is the Rails 8 generator's session auth ([`authentication.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/controllers/concerns/authentication.rb), [`SessionsController`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/controllers/sessions_controller.rb)). The generated `PasswordsController`, `PasswordsMailer`, views, and `resources :passwords, param: :token` were removed ([`config/routes.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/config/routes.rb)) because no mail server is configured.
- `has_secure_password` in the installed Rails 8.1.4 still defines `user.password_reset_token` (valid 15 minutes, dead once the password changes) and `User.find_by_password_reset_token!` (raises `ActiveSupport::MessageVerifier::InvalidSignature`). No migration is needed.
- [`production.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/config/environments/production.rb) already sets `default_url_options` from `APP_HOST`; `smtp_settings` is commented out. [`ApplicationMailer`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/mailers/application_mailer.rb) still sends from `from@example.com`. Tests use the `:test` delivery method and Active Job's `:test` adapter.

## Suggested implementation
1. Hand-copy the generator's files instead of re-running `bin/rails generate authentication`, which would overwrite `SessionsController` and `User`. Templates live in the railties gem under `rails/generators/rails/authentication/templates/` and `rails/generators/erb/authentication/templates/`. Restore `PasswordsController` (keeping its `rate_limit to: 10, within: 3.minutes, only: :create`), `PasswordsMailer#reset` with both templates, and `passwords/new` + `passwords/edit`, restyled with `.auth-card` / `.stack-form` like [`sessions/new.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/sessions/new.html.erb).
2. Routes: `resources :passwords, param: :token, only: %i[ new create edit update ]`.
3. `create` always redirects to sign-in with the same notice ("If that email has an account, a reset link is on its way."). The lookup already applies the model's email `normalizes`. Keep `deliver_later` so response time reveals nothing either.
4. `update`: on failure, render `:edit` with status 422 and `shared/form_errors` (the generator redirects with "Passwords did not match." for every error, even "too short"); on success, `@user.sessions.destroy_all` and redirect to sign-in.
5. Add a "Forgot password?" link under the password field in `sessions/new.html.erb`.
6. Provider: SendGrid retired its free plan in May 2025, and Mailgun's free Heroku plan, Resend, and Postmark only email arbitrary recipients after you verify a domain you own, which we don't have. Use Gmail SMTP with an app password on a team Gmail account (free, no domain, needs 2-Step Verification). Keep `production.rb` provider-agnostic, so switching later is config only:
   ```ruby
   config.action_mailer.delivery_method = :smtp
   config.action_mailer.smtp_settings = {
     address: ENV.fetch("SMTP_ADDRESS", "smtp.gmail.com"), port: ENV.fetch("SMTP_PORT", "587").to_i,
     user_name: ENV["SMTP_USERNAME"], password: ENV["SMTP_PASSWORD"],
     authentication: :plain, enable_starttls_auto: true
   }
   ```
   Read `default from:` from `ENV["MAIL_FROM"]` in `ApplicationMailer`, and document `SMTP_*`, `MAIL_FROM`, and `APP_HOST` in the README. Production's default in-process `:async` job adapter is fine on one dyno.
7. Cucumber support: `features/support/email.rb` with `Before { ActionMailer::Base.deliveries.clear; ActiveJob::Base.queue_adapter.perform_enqueued_jobs = true }` so `deliver_later` delivers at once. Add a generic `When I fill in {string} with {string}` step (none exists) and "the forgot password page" to `paths.rb` and the `{page}` regexp.

## Acceptance criteria
- [ ] On production, the reset email arrives and its link opens `/passwords/:token/edit` on `APP_HOST`.
- [ ] Unknown emails get the identical response and no email.
- [ ] Links expire after 15 minutes and die after a successful reset, which also signs out every session.
- [ ] RSpec: `spec/mailers/passwords_mailer_spec.rb` (recipient, subject, link); `spec/requests/passwords_spec.rb` (`have_enqueued_mail(PasswordsMailer, :reset)` only for real users, same notice for unknown emails, bad or expired token redirects with an alert, mismatched or short password returns 422, success destroys sessions).
- [ ] Cucumber `features/accounts/reset_password.feature`: request a link, follow it from `ActionMailer::Base.deliveries`, set a new password, and sign in with it; an unknown email gets the same message and no mail; a link used 16 minutes later is refused.
- [ ] `bin/ci` passes

## Notes
- **Depends on:** nothing. Review apps from #1 (Enable Heroku Review Apps for per-PR deployments) don't set `APP_HOST`, so their reset links would point at production; set it per review app or leave SMTP off there.
- **Out of scope:** email verification at sign-up, a settings page for changing email or password, a custom sending domain.
- **Size:** M (1–2 days)
