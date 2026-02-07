using ConferenceHub.Models;

namespace ConferenceHub.Services
{
    public interface IDataService
    {
        Task<List<Session>> GetSessionsAsync();
        Task<Session?> GetSessionByIdAsync(int id);
        Task AddSessionAsync(Session session);
        Task UpdateSessionAsync(Session session);
        Task DeleteSessionAsync(int id);
        Task<List<Registration>> GetRegistrationsAsync();
        Task AddRegistrationAsync(Registration registration);
    }
}
