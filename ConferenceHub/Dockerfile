# Build stage
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

COPY ConferenceHub/ConferenceHub.csproj ConferenceHub/
RUN dotnet restore ConferenceHub/ConferenceHub.csproj

COPY ConferenceHub/. ConferenceHub/
RUN dotnet publish ConferenceHub/ConferenceHub.csproj -c Release -o /app/publish /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .

ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

ENTRYPOINT ["dotnet", "ConferenceHub.dll"]
