# Copilot Instructions for TeaMate

## Project purpose
TeaMate is a Flutter mobile app for tea-field decision support. The product focuses on image-based bud analysis, predicted yield, labour allocation, weather-aware guidance, and harvest round tracking.

## Core product flow
When making changes, keep this flow in mind:
1. Field analysis and image-based measurement
2. Yield readiness estimation
3. Weather-informed harvest guidance
4. Labour allocation and communication

## Architecture guidance
- Keep UI work in the screens and widgets layers under lib/screens and lib/widgets.
- Keep auth, HTTP, storage, permissions, and external integrations in lib/services.
- Keep domain state and domain-specific behavior in lib/models and shared manager-style classes.
- Prefer extending existing services and domain models rather than introducing new abstractions.

## Preferred implementation patterns
- Follow the existing Flutter style based on StatefulWidget and setState unless the task explicitly asks for a new state-management framework.
- Reuse existing UI widgets where possible.
- Keep business logic out of widgets and prefer model/service ownership.
- Preserve the current domain vocabulary: field, measurement, round, worker, weather action, labour plan.

## Domain rules that must be preserved
- Weather is a decision layer for timing and safety, not a direct replacement for yield prediction.
- Harvest guidance should remain practical and field-oriented, such as pluck before noon if safe or wait for supervisor confirmation.
- Labour allocation should stay tied to field readiness and weather context rather than becoming a generic task scheduler.
- Authentication and API access should stay behind the service layer.

## Change boundaries
- Screen changes: update UI only unless the task clearly requires new logic.
- Service changes: use lib/services for API, auth, persistence, weather, permissions, and settings.
- Model changes: update domain objects and shared computations in lib/models.
- New features: prefer small, focused changes that fit the existing architecture.

## Global definitions for agents
- App domain: tea harvest decision support
- Primary journeys: onboarding, authentication, field analysis, weather review, labour allocation, alerts, and settings
- Core entities: Field, FieldMeasurement, AnalysisImageResult, Worker, PluckingSchedule, WeatherForecast, AppNotificationItem
- Key business rule: image analysis estimates readiness; weather guides safe timing; labour allocation follows that guidance

## Safety and quality expectations
- Do not expose secrets or hardcode credentials.
- Do not bypass auth or network handling by placing HTTP logic directly in screens.
- Prefer minimal changes and verify them before claiming completion.
- Follow the repository linting rules from analysis_options.yaml.

## Verification expectations
When a change is made, verify it with the relevant local checks if available, such as:
- flutter analyze
- flutter test
