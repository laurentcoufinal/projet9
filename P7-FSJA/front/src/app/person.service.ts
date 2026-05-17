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

export type { Person, Organization } from './models';

@Injectable({ providedIn: 'root' })
export class PersonService {
  constructor(private client: HttpClient) {}

  async fetchById(id: number): Promise<Person> {
    const person = await firstValueFrom(
      this.client.get<Person>(`${API_BASE_URL}/persons/${id}`)
    );
    const organizations = await this.fetchPersonOrganizations(person.id as number);
    person.organizations = organizations;
    return person;
  }

  async fetchAll(): Promise<Person[]> {
    const result = await firstValueFrom(
      this.client.get<HalEmbeddedPersons>(`${API_BASE_URL}/persons`)
    );
    return result._embedded.persons;
  }

  async fetchPersonOrganizations(id: number): Promise<Organization[]> {
    const result = await firstValueFrom(
      this.client.get<HalEmbeddedOrganizations>(`${API_BASE_URL}/persons/${id}/organizations`)
    );
    return result._embedded.organizations;
  }

  async deleteById(id: number): Promise<void> {
    await firstValueFrom(this.client.delete(`${API_BASE_URL}/persons/${id}`));
  }

  async save(person: Person): Promise<Person> {
    const payload = {
      firstName: person.firstName,
      lastName: person.lastName,
      bio: person.bio,
      phone: person.phone,
      email: person.email,
    };

    const saved = person.id === undefined
      ? await firstValueFrom(this.client.post<Person>(`${API_BASE_URL}/persons`, payload))
      : await firstValueFrom(this.client.put<Person>(`${API_BASE_URL}/persons/${person.id}`, payload));

    saved.organizations = await this.fetchPersonOrganizations(saved.id as number);
    return saved;
  }
}
