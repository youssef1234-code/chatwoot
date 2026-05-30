/* global axios */
import ApiClient from '../ApiClient';

class WhatsappBridgeAPI extends ApiClient {
  constructor() {
    super('integrations/whatsapp_bridge', { accountScoped: true });
  }

  getSettings() {
    return axios.get(`${this.url}/get_settings`);
  }

  updateSettings(settings) {
    return axios.patch(`${this.url}/update_settings`, settings);
  }

  getTeamMembers() {
    return axios.get(`${this.url}/team_members`);
  }

  upsertTeamMember({ phoneNumber, role, displayName }) {
    return axios.post(`${this.url}/upsert_team_member`, {
      phone_number: phoneNumber,
      role,
      display_name: displayName,
    });
  }

  deleteTeamMember(phoneNumber) {
    return axios.delete(`${this.url}/delete_team_member`, {
      params: { phone_number: phoneNumber },
    });
  }
}

export default new WhatsappBridgeAPI();
