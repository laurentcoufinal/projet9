export interface Person {
  id?: number;
  firstName: string;
  lastName: string;
  email: string;
  phone: string;
  bio: string;
  createdAt: Date;
  updatedAt?: Date;
  organizations: Organization[];
}

export interface Organization {
  id?: number;
  name: string;
  createdAt: Date;
  updatedAt?: Date;
  persons: Person[];
}

export interface HalEmbeddedPersons {
  _embedded: {
    persons: Person[];
  };
}

export interface HalEmbeddedOrganizations {
  _embedded: {
    organizations: Organization[];
  };
}
