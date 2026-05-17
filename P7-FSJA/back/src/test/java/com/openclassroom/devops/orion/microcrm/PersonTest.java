package com.openclassroom.devops.orion.microcrm;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

class PersonTest {

    @Test
    void constructorWithFieldsSetsValues() {
        Person person = new Person("John", "Doe", "john@example.com");

        assertEquals("John", person.getFirstName());
        assertEquals("Doe", person.getLastName());
        assertEquals("john@example.com", person.getEmail());
    }

    @Test
    void gettersAndSettersWork() {
        Person person = new Person();
        person.setFirstName("Jane");
        person.setLastName("Smith");
        person.setEmail("jane@example.com");
        person.setPhone("0102030405");
        person.setBio("Developer");

        assertEquals("Jane", person.getFirstName());
        assertEquals("Smith", person.getLastName());
        assertEquals("jane@example.com", person.getEmail());
        assertEquals("0102030405", person.getPhone());
        assertEquals("Developer", person.getBio());
    }

    @Test
    void removeFromOrganizationDoesNothingWhenListIsNull() {
        Person person = new Person();
        ReflectionTestUtils.invokeMethod(person, "removeFromOrganization");
    }

    @Test
    void removeFromOrganizationRemovesPersonFromEachOrganization() {
        Person person = new Person();
        Organization org1 = mock(Organization.class);
        Organization org2 = mock(Organization.class);
        List<Organization> organizations = new ArrayList<>();
        organizations.add(org1);
        organizations.add(org2);
        ReflectionTestUtils.setField(person, "organizations", organizations);

        ReflectionTestUtils.invokeMethod(person, "removeFromOrganization");

        verify(org1).removePerson(person);
        verify(org2).removePerson(person);
    }
}
