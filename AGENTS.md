# Agent Handoff Guide for TeaMate

## Purpose
This repository is intended to be maintained by AI agents as well as human developers. The instructions here are meant to reduce ambiguity and keep modifications aligned with the app’s domain and architecture.

## What agents should understand first
- This is a Flutter mobile application for tea-field operations.
- The app is not a generic CRUD app; it is a decision-support app with agricultural field workflows.
- The most important workflow is field analysis -> weather-guided harvest action -> labour allocation.

## Required skills for agents
1. Flutter UI work
   - Modify screens and widgets without scattering business logic into presentation code.
2. Service-layer work
   - Handle API calls, auth state, persistence, weather integration, and permissions in lib/services.
3. Domain-model work
   - Extend or adjust models in lib/models when changing business behavior.
4. Weather and harvest logic
   - Preserve the product logic that weather informs timing and safety recommendations.
5. Safe implementation
   - Make small, testable changes and avoid framework churn unless requested.

## Rules for agents
- Keep UI code focused on interaction and presentation.
- Keep network and authentication logic in services.
- Keep domain rules in models or manager-style shared logic.
- Use the existing tea-harvest vocabulary instead of introducing unrelated terminology.
- Avoid introducing new state libraries unless the task clearly requires them.
- When modifying weather logic, preserve the current decision semantics from the README.
- Avoid broad refactors without explicit need.

## Global definitions
- App goal: optimize tea harvest decisions using image analysis and weather guidance.
- Core entities: field, measurement, round, worker, weather forecast, labour plan, notification.
- Primary modules: auth, dashboard, fields, onboarding, settings, alerts.
- Current architecture style: feature folders with service and model layers, using StatefulWidget plus setState.

## Definition of done
A task is considered complete when:
- the change follows the architecture boundaries above,
- the business logic remains consistent with the app’s domain,
- and the change is verified locally with the relevant Flutter checks.
