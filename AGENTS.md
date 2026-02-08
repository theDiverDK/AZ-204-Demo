# Repository Guidelines

## Project Structure & Module Organization
The application lives in `ConferenceHub/` and is an ASP.NET Core MVC app targeting `.NET 9`.
- `ConferenceHub/Controllers`: HTTP endpoints and request flow.
- `ConferenceHub/Services`: business/data services (`IDataService`, `DataService`).
- `ConferenceHub/Models`: domain and view models.
- `ConferenceHub/Views`: Razor views by feature (`Home`, `Sessions`, `Organizer`, `Admin`).
- `ConferenceHub/wwwroot`: static assets (CSS, JS, vendor libs).
- `ConferenceHub/Data/sessions.json`: seed/session persistence file.

## Build, Test, and Development Commands
Run commands from `ConferenceHub/` unless noted.
- `dotnet restore`: restore NuGet packages.
- `dotnet build -c Release`: compile and validate the app.
- `dotnet run`: run locally (default URLs include `http://localhost:5053`).
- `dotnet publish -c Release -o ./publish`: create deployment output.
- `dotnet test`: run tests when test projects are present.
- `az deployment group create --template-file ConferenceHub/devops/main.bicep ...` (repo root): deploy infra.

## Coding Style & Naming Conventions
Follow the existing C# style in this repo:
- 4-space indentation; braces on new lines (Allman style).
- `PascalCase` for classes, methods, public properties.
- `_camelCase` for private readonly fields.
- Async methods use `Async` suffix (for example `GetSessionsAsync`).
- Keep controllers thin; place data/business logic in `Services`.

## Testing Guidelines
There is currently no dedicated test project in this snapshot.
- Add new tests under a `ConferenceHub.Tests/` project using xUnit.
- Name files `*Tests.cs`; use `MethodName_State_ExpectedResult` for test names.
- Prioritize service-layer tests (capacity limits, registration behavior, JSON loading).

## Commit & Pull Request Guidelines
Git history metadata is not included in this workspace snapshot, so no strict convention is enforced by existing commits.
Use clear, imperative commit messages, for example:
- `feat: add session capacity validation`
- `fix: prevent null attendee email submission`

PRs should include:
- What changed and why.
- Manual verification steps (`dotnet build`, `dotnet run`).
- Screenshots/GIFs for UI changes under `Views`.
- Linked work item/issue when applicable.

## Security & Configuration Tips
- Do not commit secrets in `appsettings*.json`.
- Keep environment-specific settings outside source control.
- Validate Azure pipeline variables before running `ConferenceHub/devops/*.yaml`.
