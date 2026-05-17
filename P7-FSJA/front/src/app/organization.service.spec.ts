import { TestBed } from '@angular/core/testing';
import { HttpClientTestingModule, HttpTestingController } from '@angular/common/http/testing';
import { Organization, OrganizationService } from './organization.service';
import { API_BASE_URL } from './config';

async function tick(): Promise<void> {
  await Promise.resolve();
}

describe('OrganizationService', () => {
  let service: OrganizationService;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [HttpClientTestingModule],
    });
    service = TestBed.inject(OrganizationService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpMock.verify();
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });

  it('fetchAll should return organizations from HAL payload', async () => {
    const promise = service.fetchAll();
    const req = httpMock.expectOne(`${API_BASE_URL}/organizations`);
    req.flush({ _embedded: { organizations: [{ id: 1, name: 'Orion' }] } });
    const orgs = await promise;
    expect(orgs.length).toBe(1);
    expect(orgs[0].name).toBe('Orion');
  });

  it('fetchById should load organization and persons', async () => {
    const promise = service.fetchById(2);
    const orgReq = httpMock.expectOne(`${API_BASE_URL}/organizations/2`);
    orgReq.flush({ id: 2, name: 'Orion' });
    await tick();
    const personsReq = httpMock.expectOne(`${API_BASE_URL}/organizations/2/persons`);
    personsReq.flush({ _embedded: { persons: [{ id: 1, firstName: 'John' }] } });
    const org = await promise;
    expect(org.persons.length).toBe(1);
  });

  it('save should POST when id is undefined', async () => {
    const org: Organization = {
      name: 'New Org',
      createdAt: new Date(),
      persons: [],
    };
    const promise = service.save(org);
    const postReq = httpMock.expectOne(`${API_BASE_URL}/organizations`);
    expect(postReq.request.method).toBe('POST');
    postReq.flush({ id: 4, name: 'New Org' });
    await tick();
    const personsReq = httpMock.expectOne(`${API_BASE_URL}/organizations/4/persons`);
    personsReq.flush({ _embedded: { persons: [] } });
    const saved = await promise;
    expect(saved.id).toBe(4);
  });

  it('save should PUT when id is set', async () => {
    const org: Organization = {
      id: 3,
      name: 'Updated',
      createdAt: new Date(),
      persons: [],
    };
    const promise = service.save(org);
    const putReq = httpMock.expectOne(`${API_BASE_URL}/organizations/3`);
    expect(putReq.request.method).toBe('PUT');
    putReq.flush(org);
    await tick();
    const personsReq = httpMock.expectOne(`${API_BASE_URL}/organizations/3/persons`);
    personsReq.flush({ _embedded: { persons: [] } });
    await promise;
  });

  it('deleteById should call DELETE', async () => {
    const promise = service.deleteById(9);
    const req = httpMock.expectOne(`${API_BASE_URL}/organizations/9`);
    expect(req.request.method).toBe('DELETE');
    req.flush(null);
    await promise;
  });

  it('addPerson should PUT uri-list', async () => {
    const promise = service.addPerson(1, 2);
    const req = httpMock.expectOne(`${API_BASE_URL}/organizations/1/persons`);
    expect(req.request.method).toBe('PUT');
    expect(req.request.headers.get('Content-Type')).toBe('text/uri-list');
    req.flush(null);
    await promise;
  });

  it('removePerson should call DELETE on link', async () => {
    const promise = service.removePerson(1, 2);
    const req = httpMock.expectOne(`${API_BASE_URL}/persons/2/organizations/1`);
    expect(req.request.method).toBe('DELETE');
    req.flush(null);
    await promise;
  });
});
