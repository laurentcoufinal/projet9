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
import { TraceIdService } from './trace-id.service';

export type { Organization, Person } from './models';

@Injectable({ providedIn: 'root' })
export class OrganizationService {
  constructor(
    private client: HttpClient,
    private traceId: TraceIdService
  ) {}

  async fetchById(id: number, requestId: string = crypto.randomUUID()): Promise<Organization> {
    return this.traceId.runWithId(requestId, async () => {
      const org = await firstValueFrom(
        this.client.get<Organization>(`${API_BASE_URL}/organizations/${id}`)
      );
      org.persons = await this.fetchOrganizationPersons(org.id as number, requestId);
      return org;
    });
  }

  async fetchAll(requestId: string = crypto.randomUUID()): Promise<Organization[]> {
    return this.traceId.runWithId(requestId, () =>
      firstValueFrom(
        this.client.get<HalEmbeddedOrganizations>(`${API_BASE_URL}/organizations`)
      ).then((result) => result._embedded.organizations)
    );
  }

  async fetchOrganizationPersons(
    id: number,
    requestId: string = crypto.randomUUID()
  ): Promise<Person[]> {
    return this.traceId.runWithId(requestId, () =>
      firstValueFrom(
        this.client.get<HalEmbeddedPersons>(`${API_BASE_URL}/organizations/${id}/persons`)
      ).then((result) => result._embedded.persons)
    );
  }

  async deleteById(id: number, requestId: string = crypto.randomUUID()): Promise<void> {
    await this.traceId.runWithId(requestId, () =>
      firstValueFrom(this.client.delete(`${API_BASE_URL}/organizations/${id}`))
    );
  }

  async save(org: Organization, requestId: string = crypto.randomUUID()): Promise<Organization> {
    return this.traceId.runWithId(requestId, async () => {
      const payload = { name: org.name };

      const saved =
        org.id === undefined
          ? await firstValueFrom(
              this.client.post<Organization>(`${API_BASE_URL}/organizations`, payload)
            )
          : await firstValueFrom(
              this.client.put<Organization>(
                `${API_BASE_URL}/organizations/${org.id}`,
                payload
              )
            );

      saved.persons = await this.fetchOrganizationPersons(saved.id as number, requestId);
      return saved;
    });
  }

  async addPerson(
    orgId: number,
    personId: number,
    requestId: string = crypto.randomUUID()
  ): Promise<void> {
    await this.traceId.runWithId(requestId, () =>
      firstValueFrom(
        this.client.put(
          `${API_BASE_URL}/organizations/${orgId}/persons`,
          `${API_BASE_URL}/persons/${personId}`,
          { headers: { 'Content-Type': 'text/uri-list' } }
        )
      )
    );
  }

  async removePerson(
    orgId: number,
    personId: number,
    requestId: string = crypto.randomUUID()
  ): Promise<void> {
    await this.traceId.runWithId(requestId, () =>
      firstValueFrom(
        this.client.delete(
          `${API_BASE_URL}/persons/${personId}/organizations/${orgId}`
        )
      )
    );
  }
}
