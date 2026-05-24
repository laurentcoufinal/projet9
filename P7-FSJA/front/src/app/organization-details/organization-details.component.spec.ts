import { ComponentFixture, TestBed } from '@angular/core/testing';
import { OrganizationDetailsComponent } from './organization-details.component';
import { provideHttpClientTesting } from '@angular/common/http/testing';
import { RouterTestingModule } from '@angular/router/testing';
import { ActivatedRoute, Router } from '@angular/router';
import { Organization, OrganizationService } from '../organization.service';
import { PersonService } from '../person.service';
import { provideHttpClient, withInterceptorsFromDi } from '@angular/common/http';

describe('OrganizationDetailsComponent', () => {
  let component: OrganizationDetailsComponent;
  let fixture: ComponentFixture<OrganizationDetailsComponent>;
  let organizationService: jasmine.SpyObj<OrganizationService>;
  let router: Router;

  beforeEach(async () => {
    organizationService = jasmine.createSpyObj('OrganizationService', [
      'fetchById',
      'save',
      'deleteById',
    ]);

    await TestBed.configureTestingModule({
    imports: [OrganizationDetailsComponent, RouterTestingModule],
    providers: [
        { provide: OrganizationService, useValue: organizationService },
        { provide: PersonService, useValue: jasmine.createSpyObj('PersonService', ['fetchById']) },
        {
            provide: ActivatedRoute,
            useValue: {
                snapshot: {
                    paramMap: {
                        get: (key: string) => (key === 'orgId' ? 'new' : null),
                    },
                },
            },
        },
        provideHttpClient(withInterceptorsFromDi()),
        provideHttpClientTesting(),
    ]
}).compileComponents();

    fixture = TestBed.createComponent(OrganizationDetailsComponent);
    component = fixture.componentInstance;
    router = TestBed.inject(Router);
    spyOn(router, 'navigate');
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('ngOnInit should set isNew for new organization route', () => {
    expect(component.isNew).toBeTrue();
  });

  it('saveOrg should navigate when creating', async () => {
    const saved: Organization = {
      id: 8,
      name: 'Orion',
      createdAt: new Date(),
      persons: [],
    };
    organizationService.save.and.resolveTo(saved);

    await component.saveOrg();

    expect(router.navigate).toHaveBeenCalledWith(['organizations', 8]);
  });

  it('deleteOrg should navigate home', async () => {
    component.org.id = 4;
    organizationService.deleteById.and.resolveTo();

    await component.deleteOrg();

    expect(organizationService.deleteById).toHaveBeenCalledWith(4, jasmine.any(String));
    expect(router.navigate).toHaveBeenCalledWith(['']);
  });
});

describe('OrganizationDetailsComponent existing org', () => {
  let component: OrganizationDetailsComponent;
  let organizationService: jasmine.SpyObj<OrganizationService>;

  beforeEach(async () => {
    organizationService = jasmine.createSpyObj('OrganizationService', ['fetchById', 'save', 'deleteById']);
    organizationService.fetchById.and.resolveTo({
      id: 2,
      name: 'Orion',
      createdAt: new Date(),
      persons: [],
    });

    await TestBed.configureTestingModule({
    imports: [OrganizationDetailsComponent, RouterTestingModule],
    providers: [
        { provide: OrganizationService, useValue: organizationService },
        { provide: PersonService, useValue: jasmine.createSpyObj('PersonService', ['fetchById']) },
        {
            provide: ActivatedRoute,
            useValue: {
                snapshot: {
                    paramMap: {
                        get: () => '2',
                    },
                },
            },
        },
        provideHttpClient(withInterceptorsFromDi()),
        provideHttpClientTesting(),
    ]
}).compileComponents();

    const fixture = TestBed.createComponent(OrganizationDetailsComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
    await fixture.whenStable();
  });

  it('should load existing organization', () => {
    expect(organizationService.fetchById).toHaveBeenCalledWith(2, jasmine.any(String));
    expect(component.isNew).toBeFalse();
    expect(component.org.name).toBe('Orion');
  });
});
