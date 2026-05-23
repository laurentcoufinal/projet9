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

export type { Person, Organization } from './models';

@Injectable({ providedIn: 'root' })
export class PersonService {
  constructor(
    private client: HttpClient,
    private traceId: TraceIdService
  ) {}

  async fetchById(id: number, requestId: string = crypto.randomUUID()): Promise<Person> {
    return this.traceId.runWithId(requestId, async () => {
      const person = await firstValueFrom(
        this.client.get<Person>(`${API_BASE_URL}/persons/${id}`)
      );
      const organizations = await this.fetchPersonOrganizations(person.id as number, requestId);
      person.organizations = organizations;
      return person;
    });
  }

  async fetchAll(requestId: string = crypto.randomUUID()): Promise<Person[]> {
    return this.traceId.runWithId(requestId, () =>
      firstValueFrom(
        this.client.get<HalEmbeddedPersons>(`${API_BASE_URL}/persons`)
      ).then((result) => result._embedded.persons)
    );
  }

  async fetchPersonOrganizations(
    id: number,
    requestId: string = crypto.randomUUID()
  ): Promise<Organization[]> {
    return this.traceId.runWithId(requestId, () =>
      firstValueFrom(
        this.client.get<HalEmbeddedOrganizations>(`${API_BASE_URL}/persons/${id}/organizations`)
      ).then((result) => result._embedded.organizations)
    );
  }

  async deleteById(id: number, requestId: string = crypto.randomUUID()): Promise<void> {
    await this.traceId.runWithId(requestId, () =>
      firstValueFrom(this.client.delete(`${API_BASE_URL}/persons/${id}`))
    );
  }

  async save(person: Person, requestId: string = crypto.randomUUID()): Promise<Person> {
    return this.traceId.runWithId(requestId, async () => {
      const payload = {
        firstName: person.firstName,
        lastName: person.lastName,
        bio: person.bio,
        phone: person.phone,
        email: person.email,
      };

      const saved =
        person.id === undefined
          ? await firstValueFrom(
              this.client.post<Person>(`${API_BASE_URL}/persons`, payload)
            )
          : await firstValueFrom(
              this.client.put<Person>(`${API_BASE_URL}/persons/${person.id}`, payload)
            );

      saved.organizations = await this.fetchPersonOrganizations(saved.id as number, requestId);
      return saved;
    });
  }
}
