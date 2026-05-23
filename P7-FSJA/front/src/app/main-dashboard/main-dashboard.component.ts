import { AsyncPipe, DatePipe, NgFor, NgIf } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { RouterLink } from '@angular/router';
import { Person, PersonService } from '../person.service';
import { Organization, OrganizationService } from '../organization.service';

@Component({
  selector: 'app-main-dashboard',
  standalone: true,
  imports: [RouterLink, NgFor, NgIf, AsyncPipe, DatePipe],
  templateUrl: './main-dashboard.component.html',
  styleUrl: './main-dashboard.component.css'
})
export class MainDashboardComponent implements OnInit {
  organizations: Organization[] = [];
  persons: Person[] = [];

  constructor(private personService: PersonService, private organizationService: OrganizationService) { }


  ngOnInit(): void {
    const requestId = crypto.randomUUID();
    this.personService.fetchAll(requestId).then(persons => this.persons = persons);
    this.organizationService.fetchAll(requestId).then(orgs => this.organizations = orgs);
  }
}

