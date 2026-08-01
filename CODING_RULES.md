# Flutter Development Rules & Architecture Guidelines

You are working on a production-level Flutter application.

Your priority is NOT only making features work. Your priority is creating a clean, scalable, maintainable codebase that can grow without becoming difficult to manage.

Follow all rules below strictly.

---

# 1. Architecture

The application must follow a feature-based MVVM architecture using:

- Views
- Providers
- Services
- Models

Each feature must be isolated inside its own folder.

Recommended structure:

lib/

core/
- constants
- theme
- utils
- routing
- exceptions

features/
- feature_name/
    - models/
    - providers/
    - services/
    - views/
    - widgets/

shared/
- reusable widgets
- common components

main.dart

Do not create a flat structure where all files are mixed together.

---

# 2. Separation of Responsibilities

Every layer has a specific responsibility.

## Views

Views are responsible ONLY for:

- Displaying UI
- Handling user interactions
- Connecting UI events to providers

Views must NOT contain:

- Business logic
- API calls
- Database operations
- Complex calculations

---

## Providers

Providers handle:

- Application state
- Communication between views and services
- Loading states
- Error states
- User actions

Providers should not directly contain:

- UI code
- Widgets
- Database implementation details

---

## Services

Services handle:

- API communication
- Database operations
- External services
- File handling
- Authentication
- Third-party integrations

Services should be reusable and independent from the UI.

---

## Models

Models represent:

- Data structures
- Entities
- API responses
- Database objects

Models should contain:

- Properties
- Serialization logic
- Validation when necessary

Models should not contain UI logic.

---

# 3. Code Quality Rules

Always write code that is:

- Modular
- Readable
- Testable
- Scalable
- Easy for another developer to understand

Avoid:

- Huge files
- Duplicate code
- God classes
- Mixing responsibilities
- Quick hacks

If a file becomes too large, split it into smaller components.

---

# 4. Before Writing Code

Before implementing a feature:

1. Understand where the feature belongs.
2. Decide which models are needed.
3. Decide what services are required.
4. Decide what provider manages the state.
5. Create the structure before writing UI code.

Do not immediately start writing widgets without planning the architecture.

---

# 5. State Management

Use Provider for state management.

Rules:

- Keep state inside providers.
- Avoid unnecessary StatefulWidgets.
- Prefer Consumer/Selector patterns.
- Avoid passing large amounts of state through widget constructors.

---

# 6. Reusable Components

If a UI component is used more than once:

Create a reusable widget.

Examples:

- Buttons
- Cards
- Input fields
- Dialogs
- Loading indicators

Do not duplicate UI code.

---

# 7. Naming Conventions

Use clear names.

Examples:

Good:

ContactProvider
ContactService
ContactModel
ContactsScreen

Bad:

DataManager
Helper
Stuff
Controller2

Names should describe responsibility.

---

# 8. Error Handling

Never silently ignore errors.

Always:

- Catch errors when needed
- Provide meaningful error messages
- Handle loading states
- Handle empty states

The user should always understand what happened.

---

# 9. Dependencies

Before adding a package:

Consider:

- Is it necessary?
- Is it maintained?
- Can this be implemented simply ourselves?

Avoid unnecessary dependencies.

---

# 10. Documentation

For complex logic:

Add comments explaining WHY something exists.

Do not write comments explaining obvious code.

Bad:

// Increase counter by one
counter++;

Good:

// Prevent duplicate API calls when the user rapidly taps the button.

---

# 11. Security

Never:

- Hardcode API keys
- Store sensitive information in source code
- Trust user input blindly

Use environment variables or secure storage.

---

# 12. Scalability

Always assume this application will grow.

When creating features:

Think about:

- More users
- More data
- More integrations
- Future changes

Choose solutions that make future development easier.

---

# 13. Agent Behavior Rules

When modifying existing code:

1. Understand the current architecture first.
2. Do not rewrite unrelated files.
3. Do not introduce architectural inconsistencies.
4. Preserve existing functionality.
5. Explain important architectural decisions.

When unsure:

Ask before making large structural changes.

---

# 14. Avoid Overengineering

Do not create abstractions, interfaces, repositories, or layers unless they solve a real problem.

Prefer simple solutions first.

A feature should be as simple as possible while still respecting the architecture.

---

The goal is to create a professional Flutter application with a clean architecture that can scale for years.