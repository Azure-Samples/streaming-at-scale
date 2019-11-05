package com.microsoft.samples.spring;

import org.springframework.data.repository.CrudRepository;

import java.util.UUID;

public interface DeviceEventRepository extends CrudRepository<DeviceEvent, UUID> {
}