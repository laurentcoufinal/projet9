import { Injectable } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { HttpClient } from '@angular/common/http';
import { API_BASE_URL } from './config';
import {
  HalEmbeddedOrganizations,
  HalEmbeddedPersons,
  Organization,
  Person,
} from './models';

export type { Organization, Person } from './models';

@Injectable({ providedIn: 'root' })
export class OrganizationService {
  constructor(private client: HttpClient) {}

  async fetchById(id: number): Promise<Organization> {
    const org = await firstValueFrom(
      this.client.get<Organization>(`${API_BASE_URL}/organizations/${id}`)
    );
    org.persons = await this.fetchOrganizationPersons(org.id as number);
    return org;
  }

  async fetchAll(): Promise<Organization[]> {
    const result = await firstValueFrom(
      this.client.get<HalEmbeddedOrganizations>(`${API_BASE_URL}/organizations`)
    );
    return result._embedded.organizations;
  }

  async fetchOrganizationPersons(id: number): Promise<Person[]> {
    const result = await firstValueFrom(
      this.client.get<HalEmbeddedPersons>(`${API_BASE_URL}/organizations/${id}/persons`)
    );
    return result._embedded.persons;
  }

  async deleteById(id: number): Promise<void> {
    await firstValueFrom(this.client.delete(`${API_BASE_URL}/organizations/${id}`));
  }

  async save(org: Organization): Promise<Organization> {
    const payload = { name: org.name };

    const saved = org.id === undefined
      ? await firstValueFrom(this.client.post<Organization>(`${API_BASE_URL}/organizations`, payload))
      : await firstValueFrom(this.client.put<Organization>(`${API_BASE_URL}/organizations/${org.id}`, payload));

    saved.persons = await this.fetchOrganizationPersons(saved.id as number);
    return saved;
  }

  async addPerson(orgId: number, personId: number): Promise<void> {
    await firstValueFrom(
      this.client.put(
        `${API_BASE_URL}/organizations/${orgId}/persons`,
        `${API_BASE_URL}/persons/${personId}`,
        { headers: { 'Content-Type': 'text/uri-list' } }
      )
    );
  }

  async removePerson(orgId: number, personId: number): Promise<void> {
    await firstValueFrom(
      this.client.delete(`${API_BASE_URL}/persons/${personId}/organizations/${orgId}`)
    );
  }
}
