namespace ConferenceHub.Models
{
    public class CosmosDbConfig
    {
        public string Endpoint { get; set; } = string.Empty;
        public string Key { get; set; } = string.Empty;
        public string DatabaseName { get; set; } = "conferencehub";
        public string SessionsContainerName { get; set; } = "sessions";
        public string RegistrationsContainerName { get; set; } = "registrations";
    }
}
