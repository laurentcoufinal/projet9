import { TestBed } from '@angular/core/testing';
import { HttpClientTestingModule, HttpTestingController } from '@angular/common/http/testing';
import { Person, PersonService } from './person.service';
import { API_BASE_URL } from './config';

describe('PersonService', () => {
  let service: PersonService;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [HttpClientTestingModule],
    });
    service = TestBed.inject(PersonService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpMock.verify();
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });

  it('fetchAll should return persons from HAL payload', async () => {
    const promise = service.fetchAll();
    const req = httpMock.expectOne(`${API_BASE_URL}/persons`);
    expect(req.request.method).toBe('GET');
    req.flush({ _embedded: { persons: [{ id: 1, firstName: 'John' }] } });
    const persons = await promise;
    expect(persons.length).toBe(1);
    expect(persons[0].firstName).toBe('John');
  });

  it('fetchById should load person and organizations', async () => {
    const promise = service.fetchById(1);
    const personReq = httpMock.expectOne(`${API_BASE_URL}/persons/1`);
    personReq.flush({ id: 1, firstName: 'John', lastName: 'Doe', email: 'j@ex.com' });
    const orgReq = httpMock.expectOne(`${API_BASE_URL}/persons/1/organizations`);
    orgReq.flush({ _embedded: { organizations: [{ id: 2, name: 'Orion' }] } });
    const person = await promise;
    expect(person.organizations.length).toBe(1);
  });

  it('save should POST when id is undefined', async () => {
    const person: Person = {
      firstName: 'A',
      lastName: 'B',
      email: 'a@b.com',
      phone: '',
      bio: '',
      createdAt: new Date(),
      organizations: [],
    };
    const promise = service.save(person);
    const postReq = httpMock.expectOne(`${API_BASE_URL}/persons`);
    expect(postReq.request.method).toBe('POST');
    postReq.flush({ id: 5, ...person });
    const orgReq = httpMock.expectOne(`${API_BASE_URL}/persons/5/organizations`);
    orgReq.flush({ _embedded: { organizations: [] } });
    const saved = await promise;
    expect(saved.id).toBe(5);
  });

  it('save should PUT when id is set', async () => {
    const person: Person = {
      id: 3,
      firstName: 'A',
      lastName: 'B',
      email: 'a@b.com',
      phone: '',
      bio: '',
      createdAt: new Date(),
      organizations: [],
    };
    const promise = service.save(person);
    const putReq = httpMock.expectOne(`${API_BASE_URL}/persons/3`);
    expect(putReq.request.method).toBe('PUT');
    putReq.flush(person);
    const orgReq = httpMock.expectOne(`${API_BASE_URL}/persons/3/organizations`);
    orgReq.flush({ _embedded: { organizations: [] } });
    await promise;
  });

  it('deleteById should call DELETE', async () => {
    const promise = service.deleteById(7);
    const req = httpMock.expectOne(`${API_BASE_URL}/persons/7`);
    expect(req.request.method).toBe('DELETE');
    req.flush(null);
    await promise;
  });
});
