package com.openclassroom.devops.orion.microcrm;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;

import org.junit.jupiter.api.Test;

class OrganizationTest {

    @Test
    void addPersonCreatesListWhenNull() {
        Organization organization = new Organization();
        Person person = new Person();

        List<Person> persons = organization.addPerson(person);

        assertNotNull(persons);
        assertEquals(1, persons.size());
        assertTrue(persons.contains(person));
    }

    @Test
    void addPersonAppendsToExistingList() {
        Organization organization = new Organization();
        Person first = new Person();
        Person second = new Person();
        organization.addPerson(first);

        List<Person> persons = organization.addPerson(second);

        assertEquals(2, persons.size());
    }

    @Test
    void removePersonCreatesListWhenNull() {
        Organization organization = new Organization();
        Person person = new Person();

        List<Person> persons = organization.removePerson(person);

        assertNotNull(persons);
        assertTrue(persons.isEmpty());
    }

    @Test
    void removePersonRemovesFromList() {
        Organization organization = new Organization();
        Person person = new Person();
        organization.addPerson(person);

        List<Person> persons = organization.removePerson(person);

        assertTrue(persons.isEmpty());
    }

    @Test
    void nameGetterAndSetterWork() {
        Organization organization = new Organization();
        organization.setName("Orion");

        assertEquals("Orion", organization.getName());
    }

    @Test
    void personsGetterAndSetterWork() {
        Organization organization = new Organization();
        Person person = new Person();
        organization.setPersons(List.of(person));

        assertEquals(1, organization.getPersons().size());
    }
}
