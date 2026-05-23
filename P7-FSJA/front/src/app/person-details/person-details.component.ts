import { AsyncPipe, NgFor, NgIf } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { Person, PersonService } from '../person.service';
import { Organization, OrganizationService } from '../organization.service';

@Component({
  selector: 'app-person-details',
  standalone: true,
  imports: [NgIf, FormsModule, AsyncPipe, NgFor, RouterLink],
  templateUrl: './person-details.component.html',
  styleUrl: './person-details.component.css'
})
export class PersonDetailsComponent implements OnInit {
  person: Person = {
    id: undefined as (number | undefined),
    firstName: '',
    lastName: '',
    phone: '',
    email: '',
    bio: '',
    createdAt: new Date(),
    updatedAt: undefined as (Date | undefined),
    organizations: [] as (Organization[])
  };

  organizations: Organization[] = []
  selectedOrganization: Organization | null = null;
  isNew: boolean = false;

  constructor(private route: ActivatedRoute, private personService: PersonService, private organizationService: OrganizationService, private router: Router) {
    this.organizationService.fetchAll(crypto.randomUUID()).then(orgs => this.organizations = orgs)
  }

  ngOnInit(): void {
    const routeParams = this.route.snapshot.paramMap;
    const personIdParam = routeParams.get('personId');

    if (personIdParam === 'new') {
      this.isNew = true
    } else if (typeof personIdParam === 'string') {
      const personId = parseInt(personIdParam)
      this.personService.fetchById(personId, crypto.randomUUID()).then(p => {
        this.person = p
        this.isNew = false
      })
    }
  }

  savePerson() {
    const requestId = crypto.randomUUID();
    this.personService.save({
      ...this.person
    }, requestId).then(p => {
      this.person = p
      if (this.isNew) {
        this.router.navigate(["persons", p.id])
      }
    })
  }

  deletePerson() {
    if (this.person.id === undefined) return
    const requestId = crypto.randomUUID();
    this.personService.deleteById(this.person.id, requestId).then(() => {
      this.router.navigate([""])
    })
  }

  addSelectedOrganization() {
    if (this.selectedOrganization?.id === undefined || this.person.id === undefined) return
    const requestId = crypto.randomUUID();
    this.organizationService.addPerson(this.selectedOrganization.id, this.person.id, requestId)
      .then(() => this.refresh(requestId))
  }

  removeOrganization(org: Organization) {
    if (org?.id === undefined || this.person.id === undefined) return
    const requestId = crypto.randomUUID();
    this.organizationService.removePerson(org.id, this.person.id, requestId)
      .then(() => this.refresh(requestId))
  }

  refresh(requestId: string = crypto.randomUUID()) {
    if (this.person.id === undefined) return
    this.personService.fetchById(this.person.id, requestId).then(p => {
      this.person = p
      this.isNew = false
    })
  }
}
