# Habit Penguin Product Readiness Plan

The following checklist outlines the key work remaining to turn the current prototype into a production-ready habit tracking app.

## 1. Core user experience
- Replace the static Home tab background with a real dashboard that surfaces today’s tasks, progress, and streaks. Right now `HomeTab` only renders background and decorative images, so there is no actionable content for the user.
- Surface the task list and completion controls on the home screen. Widgets such as `_TaskCard` and `_SpeechBubble` exist but are unused, indicating planned interactions that still need to be wired up.
- Persist daily completion state, streak calculations, and history views so users can review past performance, not just CRUD tasks.
- Add onboarding, empty-state education, and contextual helper copy so new users understand how to use the product.

## 2. Task management depth
- Expand the task model to support schedules (e.g., weekly cadence, time-of-day) instead of the current hard-coded "Daily" label in the form.
- Implement real reminder scheduling (local notifications, optional calendar integration) tied to the `reminderEnabled` toggle, and expose snooze/skip controls.
- Support bulk actions (reordering, archiving, duplication) and guard against accidental destructive operations with undo flows beyond the current simple snackbar.

## 3. Data architecture & persistence
- Extract Hive access into repositories/services instead of calling the database directly from widgets so that business logic is testable and platform-agnostic.
- Define data migration and backup strategies (e.g., schema versioning, cloud sync) to protect user data across updates and devices.
- Introduce app state management (such as Riverpod, Bloc, or ValueNotifier-based controllers) to coordinate between screens and background services.

## 4. Visual polish & branding
- Establish a design system (typography scale, color tokens, spacing) and implement consistent theming. Extend support for dark mode, dynamic color, and larger fonts.
- Create production-quality iconography, splash screens, and promotional assets. Align imagery and mascot animations with the Habit Penguin brand identity.
- Audit responsiveness for tablets and desktop platforms; refine layout breakpoints and hit targets to meet platform guidelines.

## 5. Internationalization & accessibility
- Externalize hard-coded Japanese strings and provide English (and additional) localizations, including right-to-left layout support where applicable.
- Implement accessibility best practices: semantic labels for images, proper contrast ratios, focus order, and screen reader hints for custom controls.
- Add configurable units (e.g., date/time formats) and regional preferences.

## 6. Quality, analytics & compliance
- Replace the scaffolded widget test with meaningful unit, widget, and integration coverage that exercises task creation, editing, persistence, and reminder flows.
- Automate CI/CD pipelines (static analysis, tests, build signing) and set up release channels with crash reporting (e.g., Sentry, Firebase Crashlytics) and analytics instrumentation.
- Document privacy policy, data retention, and GDPR/CCPA compliance; add in-app settings for data export/delete requests.

## 7. Launch readiness
- Prepare app store metadata, localized descriptions, pricing, and screenshots. Implement in-app review prompts and feedback channels.
- Monitor performance (time-to-first-frame, frame stability) and address platform-specific issues (Android background execution limits, iOS notification permissions).
- Set up post-launch support workflows: customer support FAQs, contact options, and feature roadmap prioritization.
