import { ComponentFixture, TestBed } from '@angular/core/testing';
import { PersonDetailsComponent } from './person-details.component';
import { HttpClientTestingModule } from '@angular/common/http/testing';
import { RouterTestingModule } from '@angular/router/testing';
import { ActivatedRoute, Router } from '@angular/router';
import { Person, PersonService } from '../person.service';
import { Organization, OrganizationService } from '../organization.service';

describe('PersonDetailsComponent', () => {
  let component: PersonDetailsComponent;
  let fixture: ComponentFixture<PersonDetailsComponent>;
  let personService: jasmine.SpyObj<PersonService>;
  let organizationService: jasmine.SpyObj<OrganizationService>;
  let router: Router;

  beforeEach(async () => {
    personService = jasmine.createSpyObj('PersonService', [
      'fetchById',
      'save',
      'deleteById',
    ]);
    organizationService = jasmine.createSpyObj('OrganizationService', [
      'fetchAll',
      'addPerson',
      'removePerson',
    ]);
    organizationService.fetchAll.and.resolveTo([]);

    await TestBed.configureTestingModule({
      imports: [PersonDetailsComponent, HttpClientTestingModule, RouterTestingModule],
      providers: [
        { provide: PersonService, useValue: personService },
        { provide: OrganizationService, useValue: organizationService },
        {
          provide: ActivatedRoute,
          useValue: {
            snapshot: {
              paramMap: {
                get: (key: string) => (key === 'personId' ? 'new' : null),
              },
            },
          },
        },
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(PersonDetailsComponent);
    component = fixture.componentInstance;
    router = TestBed.inject(Router);
    spyOn(router, 'navigate');
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('ngOnInit should set isNew for new person route', () => {
    expect(component.isNew).toBeTrue();
  });

  it('savePerson should navigate when creating', async () => {
    const saved: Person = {
      id: 10,
      firstName: 'A',
      lastName: 'B',
      email: 'a@b.com',
      phone: '',
      bio: '',
      createdAt: new Date(),
      organizations: [],
    };
    personService.save.and.resolveTo(saved);

    await component.savePerson();

    expect(router.navigate).toHaveBeenCalledWith(['persons', 10]);
  });

  it('deletePerson should navigate home', async () => {
    component.person.id = 5;
    personService.deleteById.and.resolveTo();

    await component.deletePerson();

    expect(personService.deleteById).toHaveBeenCalledWith(5);
    expect(router.navigate).toHaveBeenCalledWith(['']);
  });

  it('addSelectedOrganization should call service when ids are set', async () => {
    component.person.id = 1;
    component.selectedOrganization = { id: 2, name: 'Org', createdAt: new Date(), persons: [] };
    personService.fetchById.and.resolveTo({
      ...component.person,
      organizations: [],
    });

    await component.addSelectedOrganization();

    expect(organizationService.addPerson).toHaveBeenCalledWith(2, 1);
  });
});

describe('PersonDetailsComponent existing person', () => {
  let component: PersonDetailsComponent;
  let personService: jasmine.SpyObj<PersonService>;
  let organizationService: jasmine.SpyObj<OrganizationService>;

  beforeEach(async () => {
    personService = jasmine.createSpyObj('PersonService', ['fetchById', 'save', 'deleteById']);
    organizationService = jasmine.createSpyObj('OrganizationService', ['fetchAll', 'addPerson', 'removePerson']);
    organizationService.fetchAll.and.resolveTo([]);
    personService.fetchById.and.resolveTo({
      id: 3,
      firstName: 'John',
      lastName: 'Doe',
      email: 'j@ex.com',
      phone: '',
      bio: '',
      createdAt: new Date(),
      organizations: [],
    });

    await TestBed.configureTestingModule({
      imports: [PersonDetailsComponent, HttpClientTestingModule, RouterTestingModule],
      providers: [
        { provide: PersonService, useValue: personService },
        { provide: OrganizationService, useValue: organizationService },
        {
          provide: ActivatedRoute,
          useValue: {
            snapshot: {
              paramMap: {
                get: () => '3',
              },
            },
          },
        },
      ],
    }).compileComponents();

    const fixture = TestBed.createComponent(PersonDetailsComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
    await fixture.whenStable();
  });

  it('should load existing person', () => {
    expect(personService.fetchById).toHaveBeenCalledWith(3);
    expect(component.isNew).toBeFalse();
    expect(component.person.firstName).toBe('John');
  });
});
